/*
 * Copyright (C) 2006-2007 Jacek Sieka, arnetheduck on gmail point com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include "adchpp.h"

#include "ClientManager.h"

#include "File.h"
#include "Client.h"
#include "LogManager.h"
#include "TimerManager.h"
#include "SocketManager.h"
#include "TigerHash.h"
#include "Encoder.h"
#include "version.h"
#include "SettingsManager.h"

namespace adchpp {

using namespace std;

ClientManager* ClientManager::instance = 0;
const string ClientManager::className = "ClientManager";

ClientManager::ClientManager() throw() {
	hub.addSupports(AdcCommand::toFourCC("BASE"));
	hub.addSupports(AdcCommand::toFourCC("TIGR"));

	SocketManager::getInstance()->setIncomingHandler(std::tr1::bind(&ClientManager::handleIncoming, this, std::tr1::placeholders::_1));
}

ClientManager::~ClientManager() throw() {

}

void ClientManager::send(const AdcCommand& cmd) throw() {
	if(cmd.getPriority() == AdcCommand::PRIORITY_IGNORE) {
		return;
	}

	bool all = false;
	switch(cmd.getType()) {
	case AdcCommand::TYPE_BROADCAST:
		all = true; // Fallthrough
	case AdcCommand::TYPE_FEATURE: {
		for(EntityIter i = entities.begin(); i != entities.end(); ++i) {
			if(all || !i->second->isFiltered(cmd.getFeatures())) {
			}
		}
	}
		break;
	case AdcCommand::TYPE_DIRECT: // Fallthrough
	case AdcCommand::TYPE_ECHO: {
		EntityIter i = entities.find(cmd.getTo());
		if(i != entities.end()) {
			maybeSend(*i->second, cmd);

			if(cmd.getType() == AdcCommand::TYPE_ECHO) {
				i = entities.find(cmd.getFrom());
				if(i != entities.end()) {
					maybeSend(*i->second, cmd);
				}
			}
		}
	}
		break;
	}
}

void ClientManager::maybeSend(Entity& c, const AdcCommand& cmd) {
	bool ok = true;
	signalSend_(c, cmd, ok);
	if(ok) {
		c.send(cmd);
	}
}

void ClientManager::sendToAll(const BufferPtr& buf) throw() {
	for(EntityIter i = entities.begin(); i != entities.end(); ++i) {
		i->second->send(buf);
	}
}

size_t ClientManager::getQueuedBytes() throw() {
	size_t total = 0;

	for(EntityIter i = entities.begin(); i != entities.end(); ++i) {
		//total += i->second->getQueuedBytes();
	}

	return total;
}

void ClientManager::sendTo(const BufferPtr& buffer, uint32_t to) {
	EntityIter i = entities.find(to);
	if(i != entities.end()) {
		i->second->send(buffer);
	}
}

bool ClientManager::checkFlooding(Client& c, const AdcCommand& cmd) throw() {
	time_t add = ((cmd.getType() == AdcCommand::TYPE_BROADCAST || cmd.getType() == AdcCommand::TYPE_FEATURE) ? 1 : 0)
		* SETTING(FLOOD_ADD);
	if(c.isFlooding(add)) {
		c.disconnect(Util::REASON_FLOODING);
		return true;
	}

	return false;
}

void ClientManager::handleIncoming(const ManagedSocketPtr& socket) throw() {
	Client::create(socket, makeSID());
}

uint32_t ClientManager::makeSID() {
	while(true) {
		union {
			uint32_t sid;
			char chars[4];
		} sid;
		sid.chars[0] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		sid.chars[1] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		sid.chars[2] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		sid.chars[3] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		if(sid.sid != 0 && entities.find(sid.sid) == entities.end()) {
			return sid.sid;
		}
	}
}

void ClientManager::onConnected(Client& c) throw() {
	// First let's check if any clients have passed the login timeout...
	time_t timeout = GET_TIME() - SETTING(LOGIN_TIMEOUT);
	while(!logins.empty() && (timeout > logins.front().second)) {
		Client* cc = logins.front().first;

		dcdebug("ClientManager: Login timeout in state %d\n", cc->getState());
		cc->disconnect(Util::REASON_LOGIN_TIMEOUT);
		logins.pop_front();
	}

	logins.push_back(make_pair(&c, GET_TIME()));

	signalConnected_(c);
}

void ClientManager::onReceive(Client& c, AdcCommand& cmd) throw() {
	if(!(cmd.getType() == AdcCommand::TYPE_BROADCAST || cmd.getType() == AdcCommand::TYPE_DIRECT || cmd.getType()
		== AdcCommand::TYPE_ECHO || cmd.getType() == AdcCommand::TYPE_FEATURE || cmd.getType() == AdcCommand::TYPE_HUB)) {
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Invalid command type"));
		c.disconnect(Util::REASON_INVALID_COMMAND_TYPE);
		return;
	}

	if(checkFlooding(c, cmd)) {
		return;
	}

	bool ok = true;
	signalReceive_(c, cmd, ok);

	if(ok) {
		if(!dispatch(c, cmd)) {
			return;
		}
	}

	send(cmd);
}

void ClientManager::onBadLine(Client& c, const string& aLine) throw() {
	signalBadLine_(c, aLine);
}

void ClientManager::badState(Client& c, const AdcCommand& cmd) throw() {
	c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_BAD_STATE, "Invalid state for command").addParam("FC",
		cmd.getFourCC()));
	c.disconnect(Util::REASON_BAD_STATE);
}

bool ClientManager::handleDefault(Client& c, AdcCommand& cmd) throw() {
	if(c.getState() != Client::STATE_NORMAL) {
		badState(c, cmd);
		return false;
	}
	return true;
}

bool ClientManager::handle(AdcCommand::SUP, Client& c, AdcCommand& cmd) throw() {
	if(!verifySUP(c, cmd)) {
		return false;
	}

	if(c.getState() == Client::STATE_PROTOCOL) {
		enterIdentify(c, true);
	} else if(c.getState() != Client::STATE_NORMAL) {
		badState(c, cmd);
		return false;
	}
	return true;
}

bool ClientManager::verifySUP(Client& c, AdcCommand& cmd) throw() {
	c.updateSupports(cmd);

	if(!c.hasSupport(AdcCommand::toFourCC("BASE"))) {
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC,
			"This hub requires BASE support"));
		c.disconnect(Util::REASON_NO_BASE_SUPPORT);
		return false;
	}

	if(!c.hasSupport(AdcCommand::toFourCC("TIGR"))) {
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC,
			"This hub requires TIGR support"));
		c.disconnect(Util::REASON_NO_TIGR_SUPPORT);
		return false;
	}

	return true;
}

bool ClientManager::verifyINF(Client& c, AdcCommand& cmd) throw() {
	if(!verifyIp(c, cmd))
		return false;

	if(!verifyCID(c, cmd))
		return false;

	if(!verifyNick(c, cmd))
		return false;

	c.updateFields(cmd);
	return true;
}

bool ClientManager::verifyPassword(Client& c, const string& password, const ByteVector& salt,
	const string& suppliedHash) {
	TigerHash tiger;
	tiger.update(&password[0], password.size());
	tiger.update(&salt[0], salt.size());
	uint8_t tmp[TigerHash::BYTES];
	Encoder::fromBase32(suppliedHash.c_str(), tmp, TigerHash::BYTES);
	if(memcmp(tiger.finalize(), tmp, TigerHash::BYTES) == 0) {
		return true;
	}

	return false;
}

bool ClientManager::handle(AdcCommand::INF, Client& c, AdcCommand& cmd) throw() {
	if(c.getState() != Client::STATE_IDENTIFY && c.getState() != Client::STATE_NORMAL) {
		badState(c, cmd);
		return false;
	}

	if(!verifyINF(c, cmd))
		return false;

	if(c.getState() == Client::STATE_IDENTIFY) {
		enterNormal(c, true, true);
	}

	return true;
}

bool ClientManager::verifyIp(Client& c, AdcCommand& cmd) throw() {
	if(c.isSet(Client::FLAG_OK_IP))
		return true;

	for(StringIter j = cmd.getParameters().begin(); j != cmd.getParameters().end(); ++j) {
		if(j->compare(0, 2, "I4") == 0) {
			dcdebug("%s verifying ip\n", AdcCommand::fromSID(c.getSID()).c_str());
			if(j->size() == 2) {
				// Clearing is ok
			} else if(j->compare(2, j->size() - 2, "0.0.0.0") == 0) {
				c.setField("I4", c.getIp());
				*j = "I4" + c.getIp();
				cmd.resetBuffer();
			} else if(j->size() - 2 != c.getIp().size() || j->compare(2, j->size() - 2, c.getIp()) != 0) {
				c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_BAD_IP, "Your ip is " + c.getIp()).addParam(
					"IP", c.getIp()));
				c.disconnect(Util::REASON_INVALID_IP);
				return false;
			}
		}
	}
	return true;
}

bool ClientManager::verifyCID(Client& c, AdcCommand& cmd) throw() {
	if(cmd.getParam("ID", 0, strtmp)) {
		dcdebug("%s verifying CID\n", AdcCommand::fromSID(c.getSID()).c_str());
		if(c.getState() != Client::STATE_IDENTIFY) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "CID changes not allowed"));
			c.disconnect(Util::REASON_CID_CHANGE);
			return false;
		}

		string spid;
		if(!cmd.getParam("PD", 0, spid)) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_INF_MISSING, "PID missing").addParam("FLPD"));
			c.disconnect(Util::REASON_PID_MISSING);
			return false;
		}

		if(strtmp.size() != CID::BASE32_SIZE || spid.size() != CID::BASE32_SIZE) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Invalid CID/PID length"));
			c.disconnect(Util::REASON_PID_CID_LENGTH);
			return false;
		}

		CID cid(strtmp);
		CID pid(spid);

		TigerHash th;
		th.update(pid.data(), CID::SIZE);
		if(!(CID(th.finalize()) == cid)) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_INVALID_PID, "PID does not correspond to CID"));
			c.disconnect(Util::REASON_PID_CID_MISMATCH);
			return false;
		}
		CIDMap::iterator i = cids.find(cid);
		if(i != cids.end()) {
			EntityIter j = entities.find(i->second);
			if(j != entities.end()) {
				j->second->send(BufferPtr(new Buffer("\n", 1)));
			}

			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_CID_TAKEN, "CID taken, please try again later"));
			c.disconnect(Util::REASON_CID_TAKEN);
			return false;
		}

		c.setCID(cid);
		cids.insert(make_pair(c.getCID(), c.getSID()));
		cmd.delParam("PD", 0);
	}

	if(cmd.getParam("PD", 0, strtmp)) {
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "CID required when sending PID"));
		c.disconnect(Util::REASON_PID_WITHOUT_CID);
		return false;
	}
	return true;
}

bool ClientManager::verifyNick(Client& c, const AdcCommand& cmd) throw() {
	if(cmd.getParam("NI", 0, strtmp)) {
		dcdebug("%s verifying nick\n", AdcCommand::fromSID(c.getSID()).c_str());
		for(string::size_type i = 0; i < strtmp.length(); ++i) {
			if((uint8_t) strtmp[i] < 33) {
				c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_NICK_INVALID, "Invalid character in nick"));
				c.disconnect(Util::REASON_NICK_INVALID);
				return false;
			}
		}

		const string& oldNick = c.getField("NI");
		if(!oldNick.empty())
			nicks.erase(oldNick);

		if(nicks.find(strtmp) != nicks.end()) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_NICK_TAKEN,
				"Nick taken, please pick another one"));
			c.disconnect(Util::REASON_NICK_TAKEN);
			return false;
		}

		nicks.insert(make_pair(strtmp, c.getSID()));
	}

	return true;
}

void ClientManager::setState(Client& c, Client::State newState) throw() {
	Client::State oldState = c.getState();
	c.setState(newState);
	signalState_(c, oldState);
}

void ClientManager::enterIdentify(Client& c, bool sendData) throw() {
	dcassert(c.getState() == Client::STATE_PROTOCOL);
	dcdebug("%s entering IDENTIFY\n", AdcCommand::fromSID(c.getSID()).c_str());
	if(sendData) {
		c.send(hub.getSUP());
		c.send(AdcCommand(AdcCommand::CMD_SID).addParam(AdcCommand::fromSID(c.getSID())));
		c.send(hub.getINF());
	}

	setState(c, Client::STATE_IDENTIFY);
}

ByteVector ClientManager::enterVerify(Client& c, bool sendData) throw() {
	dcassert(c.getState() == Client::STATE_IDENTIFY);
	dcdebug("%s entering VERIFY\n", AdcCommand::fromSID(c.getSID()).c_str());

	ByteVector challenge;
	challenge.reserve(32);
	for(int i = 0; i < 32 / 4; ++i) {
		uint32_t r = Util::rand();
		challenge.insert(challenge.end(), (uint8_t*) &r, 4 + (uint8_t*) &r);
	}

	if(sendData) {
		c.send(AdcCommand(AdcCommand::CMD_GPA).addParam(Encoder::toBase32(&challenge[0], challenge.size())));
	}

	setState(c, Client::STATE_VERIFY);
	return challenge;
}

bool ClientManager::enterNormal(Client& c, bool sendData, bool sendOwnInf) throw() {
	dcassert(c.getState() == Client::STATE_IDENTIFY || c.getState() == Client::STATE_VERIFY);
	dcdebug("%s entering NORMAL\n", AdcCommand::fromSID(c.getSID()).c_str());

	if(sendData) {
		for(EntityIter i = entities.begin(); i != entities.end(); ++i) {
			c.send(i->second->getINF());
		}

		if(sendOwnInf) {
			sendToAll(c.getINF());
			c.send(c.getINF());
		}
	}

	removeLogins(c);
	setState(c, Client::STATE_NORMAL);

	entities.insert(make_pair(c.getSID(), &c));

	return true;
}

void ClientManager::removeLogins(Client& c) throw() {
	deque<pair<Client*, time_t> >::iterator i = find_if(logins.begin(), logins.end(),
		CompareFirst<Client*, time_t> (&c));
	if(i != logins.end()) {
		logins.erase(i);
	}
}

void ClientManager::removeClient(Client& c) throw() {
	signalDisconnected_(c);
	dcdebug("Removing %s\n", AdcCommand::fromSID(c.getSID()).c_str());
	if(c.getState() == Client::STATE_NORMAL) {
		entities.erase(c.getSID());
		sendToAll(AdcCommand(AdcCommand::CMD_QUI).addParam(AdcCommand::fromSID(c.getSID())).getBuffer());
	} else {
		removeLogins(c);
	}

	nicks.erase(c.getField("NI"));
	cids.erase(c.getCID());
}

Entity* ClientManager::getEntity(uint32_t aSid) throw() {
	EntityIter i = entities.find(aSid);
	return (i == entities.end()) ? 0 : i->second;
}

uint32_t ClientManager::getSID(const string& aNick) const throw() {
	NickMap::const_iterator i = nicks.find(aNick);
	return (i == nicks.end()) ? 0 : i->second;
}

uint32_t ClientManager::getSID(const CID& cid) const throw() {
	CIDMap::const_iterator i = cids.find(cid);
	return (i == cids.end()) ? 0 : i->second;
}

void ClientManager::onFailed(Client& c) throw() {
	removeClient(c);
}

}
