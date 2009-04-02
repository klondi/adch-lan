/*
 * Copyright (C) 2006-2009 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef BLOOM_MANAGER_H
#define BLOOM_MANAGER_H

#include <tuple>
#include <adchpp/Exception.h>
#include <adchpp/Singleton.h>
#include <adchpp/ClientManager.h>

#include "HashBloom.h"

#ifdef _WIN32
# ifdef BLOOM_EXPORT
#  define BLOOM_DLL __declspec(dllexport)
# else
#  define BLOOM_DLL __declspec(dllimport)
# endif
#else
# define BLOOM_DLL
#endif

STANDARD_EXCEPTION(BloomException);
class Engine;

namespace adchpp {
class SimpleXML;
class Client;
class AdcCommand;
}

class BloomManager : public Singleton<BloomManager> {
public:
	BloomManager();
	virtual ~BloomManager();

	virtual int getVersion() { return 0; }

	static const std::string className;
private:
	friend class Singleton<BloomManager>;
	static BloomManager* instance;

	typedef std::tr1::unordered_map<uint32_t, HashBloom> BloomMap;
	BloomMap blooms;

	// bytes, m, k
	typedef std::tr1::tuple<ByteVector, size_t, size_t> PendingItem;
	typedef std::tr1::unordered_map<uint32_t, PendingItem> PendingMap;
	PendingMap pending;

	int64_t searches;
	int64_t tthSearches;
	int64_t stopped;

	ClientManager::SignalReceive::ManagedConnection receiveConn;
	ClientManager::SignalDisconnected::ManagedConnection disconnectConn;
	ClientManager::SignalSend::ManagedConnection sendConn;

	int64_t getBytes() const;
	void onReceive(Entity& c, AdcCommand& cmd, bool&);
	void onSend(Entity& c, const AdcCommand& cmd, bool&);
	void onData(Entity& c, const uint8_t* data, size_t len);
	void onDisconnected(Entity& c);

};

#endif //ACCESSMANAGER_H
