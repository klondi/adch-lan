%{

#include <adchpp/adchpp.h>
#include <adchpp/common.h>

#include <adchpp/Signal.h>
#include <adchpp/Client.h>
#include <adchpp/ClientManager.h>
#include <adchpp/LogManager.h>
#include <adchpp/SimpleXML.h>
#include <adchpp/Exception.h>
#include <adchpp/PluginManager.h>
#include <adchpp/TigerHash.h>
#include <adchpp/SocketManager.h>

using namespace adchpp;

%}

%include "exception.i"
%include "std_string.i"
%include "std_vector.i"
%include "std_except.i"
%include "std_pair.i"

%include "carrays.i"

%array_functions(size_t, size_t);

%exception {
	try {
		$action
	} catch(const std::exception& e) {
		SWIG_exception(SWIG_UnknownError, e.what());
	}
}

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef signed char int8_t;
typedef signed short int16_t;
typedef signed int int32_t;
typedef signed long long int64_t;
typedef unsigned int time_t;

using namespace std;

%inline%{
void startup() {
	adchpp::startup(0);
}
void shutdown() {
	adchpp::shutdown(0);
}
%}

%nodefaultctor;
%nodefaultdtor Entity;
%nodefaultdtor Client;
%nodefaultdtor ClientManager;
%nodefaultdtor SocketManager;
%nodefaultdtor LogManager;
%nodefaultdtor Util;
%nodefaultdtor PluginManager;

namespace adchpp {
	class Entity;
	typedef std::vector<std::string> StringList;
	typedef std::vector<uint8_t> ByteVector;
	typedef std::vector<Entity*> EntityList;
}

%template(TEntityList) std::vector<adchpp::Entity*>;
%template(TStringList) std::vector<std::string>;
%template(TByteVector) std::vector<uint8_t>;
%template(TServerInfoList) std::vector<boost::intrusive_ptr<adchpp::ServerInfo> >;

%inline%{
	namespace adchpp {
typedef std::vector<adchpp::Entity*> EntityList;
	}
%}
namespace boost {

template<typename T>
class intrusive_ptr {
public:
	T* operator->();
};

}

namespace adchpp {

void initialize(const std::string& configPath);
void cleanup();

struct ManagedConnection {
	void disconnect();
	void release();
};

typedef boost::intrusive_ptr<ManagedConnection> ManagedConnectionPtr;

struct ServerInfo {
	std::string ip;
	unsigned short port;

	%extend {
		static adchpp::ServerInfoPtr create() {
			return adchpp::ServerInfoPtr(new adchpp::ServerInfo);
		}
	}

};

typedef boost::intrusive_ptr<ServerInfo> ServerInfoPtr;

class TLSServerInfo : public ServerInfo {
public:
	std::string cert;
	std::string pkey;
	std::string trustedPath;
	std::string dh;

	%extend {
		static adchpp::TLSServerInfoPtr create() {
			return adchpp::TLSServerInfoPtr(new adchpp::TLSServerInfo);
		}
	}

};

typedef boost::intrusive_ptr<TLSServerInfo> TLSServerInfoPtr;
typedef std::vector<ServerInfoPtr> ServerInfoList;

class SocketManager {
public:
	void setServers(const ServerInfoList& servers_);

};

template<typename F>
struct Signal {
%extend {
	ManagedConnectionPtr connect(std::tr1::function<F> f) {
		return manage(self, f);
	}
}
};

template<typename F>
struct SignalTraits {
	typedef adchpp::Signal<F> Signal;
	//typedef adchpp::ConnectionPtr Connection;
	typedef adchpp::ManagedConnectionPtr ManagedConnection;
};

class Exception : public std::exception
{
public:
	Exception();
	Exception(const std::string& aError) throw();
	virtual ~Exception() throw();
	const std::string& getError() const throw();

	virtual const char* what();
};

struct Stats {
	static size_t queueCalls;
	static int64_t queueBytes;
	static size_t sendCalls;
	static int64_t sendBytes;
	static int64_t recvCalls;
	static int64_t recvBytes;
	static time_t startTime;
};

class Util
{
public:
	enum Reason {
		REASON_BAD_STATE,
		REASON_CID_CHANGE,
		REASON_CID_TAKEN,
		REASON_FLOODING,
		REASON_HUB_FULL,
		REASON_INVALID_COMMAND_TYPE,
		REASON_INVALID_IP,
		REASON_INVALID_SID,
		REASON_LOGIN_TIMEOUT,
		REASON_MAX_COMMAND_SIZE,
		REASON_NICK_INVALID,
		REASON_NICK_TAKEN,
		REASON_NO_BASE_SUPPORT,
		REASON_NO_TIGR_SUPPORT,
		REASON_PID_MISSING,
		REASON_PID_CID_LENGTH,
		REASON_PID_CID_MISMATCH,
		REASON_PID_WITHOUT_CID,
		REASON_PLUGIN,
		REASON_WRITE_OVERFLOW,
		REASON_LAST,
	};

	static size_t reasons[REASON_LAST];

	static std::string emptyString;

	static void initialize(const std::string& configPath);
	static std::string getOsVersion();
	static void decodeUrl(const std::string& aUrl, std::string& aServer, short& aPort, std::string& aFile);
	static std::string formatTime(const std::string& msg, time_t t = time(NULL));

	static const std::string& getCfgPath();
	static void setCfgPath(const std::string& path);

	static std::string getAppPath();
	static std::string getAppName();

	static std::string translateError(int aError);

	static std::string toAcp(const std::wstring& wString);
	static const std::string& toAcp(const std::string& wString);

	static std::wstring toUnicode(const std::string& aString);
	static const std::wstring& toUnicode(const std::wstring& aString);

	static std::string formatBytes(const std::string& aString);

	static std::string getShortTimeString();
	static std::string getTimeString();

	static std::string formatBytes(int64_t aBytes);

	static void tokenize(StringList& lst, const std::string& str, char sep, std::string::size_type j = 0);

	static std::string formatSeconds(int64_t aSec);


	/** Avoid this! Use the one of a connected socket instead... */
	static std::string getLocalIp();

	static uint32_t rand();
	static uint32_t rand(uint32_t high);
	static uint32_t rand(uint32_t low, uint32_t high);
	static double randd();

};

class CID {
public:
	enum { SIZE = 192 / 8 };
	enum { BASE32_SIZE = 39 };

	CID();
	explicit CID(const uint8_t* data);
	explicit CID(const std::string& base32);

	bool operator==(const CID& rhs) const;
	bool operator<(const CID& rhs) const;

	std::string toBase32() const;
	//std::string& toBase32(std::string& tmp) const;

	size_t toHash() const;
	//const uint8_t* data() const;

	%extend {
		std::string data() const { return std::string(reinterpret_cast<const char*>(self->data()), CID::SIZE); }
		std::string __str__() { return self->toBase32(); }
	}

	bool isZero() const;
	static CID generate();

};

class ParseException : public Exception {
public:
	ParseException() throw();
	ParseException(const std::string&) throw();
};

class AdcCommand {
public:
/*	template<uint32_t T>
	struct Type {
		enum { CMD = T };
	};
*/
	enum Error {
		ERROR_GENERIC = 0,
		ERROR_HUB_GENERIC = 10,
		ERROR_HUB_FULL = 11,
		ERROR_HUB_DISABLED = 12,
		ERROR_LOGIN_GENERIC = 20,
		ERROR_NICK_INVALID = 21,
		ERROR_NICK_TAKEN = 22,
		ERROR_BAD_PASSWORD = 23,
		ERROR_CID_TAKEN = 24,
		ERROR_COMMAND_ACCESS = 25,
		ERROR_REGGED_ONLY = 26,
		ERROR_INVALID_PID = 27,
		ERROR_BANNED_GENERIC = 30,
		ERROR_PERM_BANNED = 31,
		ERROR_TEMP_BANNED = 32,
		ERROR_PROTOCOL_GENERIC = 40,
		ERROR_PROTOCOL_UNSUPPORTED = 41,
		ERROR_INF_MISSING = 42,
		ERROR_BAD_STATE = 43,
		ERROR_FEATURE_MISSING = 44,
		ERROR_BAD_IP = 45,
		ERROR_TRANSFER_GENERIC = 50,
		ERROR_FILE_NOT_AVAILABLE = 51,
		ERROR_FILE_PART_NOT_AVAILABLE = 52,
		ERROR_SLOTS_FULL = 53
	};

	enum Severity {
		SEV_SUCCESS = 0,
		SEV_RECOVERABLE = 1,
		SEV_FATAL = 2
	};

	static const char TYPE_BROADCAST = 'B';
	static const char TYPE_CLIENT = 'C';
	static const char TYPE_DIRECT = 'D';
	static const char TYPE_ECHO = 'E';
	static const char TYPE_FEATURE = 'F';
	static const char TYPE_INFO = 'I';
	static const char TYPE_HUB = 'H';
	static const char TYPE_UDP = 'U';

	// Known commands...
#define C(n, a, b, c) static const unsigned int CMD_##n = (((uint32_t)a) | (((uint32_t)b)<<8) | (((uint32_t)c)<<16));
	// Base commands
	C(SUP, 'S','U','P');
	C(STA, 'S','T','A');
	C(INF, 'I','N','F');
	C(MSG, 'M','S','G');
	C(SCH, 'S','C','H');
	C(RES, 'R','E','S');
	C(CTM, 'C','T','M');
	C(RCM, 'R','C','M');
	C(GPA, 'G','P','A');
	C(PAS, 'P','A','S');
	C(QUI, 'Q','U','I');
	C(GET, 'G','E','T');
	C(GFI, 'G','F','I');
	C(SND, 'S','N','D');
	C(SID, 'S','I','D');
	// Extensions
	C(CMD, 'C','M','D');
#undef C

	enum { HUB_SID = 0xffffffff };

	AdcCommand();
	explicit AdcCommand(Severity sev, Error err, const std::string& desc, char aType);
	explicit AdcCommand(uint32_t cmd, char aType, uint32_t aFrom);
	explicit AdcCommand(const std::string& aLine) throw(ParseException);
	AdcCommand(const AdcCommand& rhs);

	static uint32_t toSID(const std::string& aSID);
	static std::string fromSID(const uint32_t aSID);
	static void appendSID(std::string& str, uint32_t aSID);

	static uint32_t toCMD(uint8_t a, uint8_t b, uint8_t c);
	//static uint32_t toCMD(const char* str);

	static uint16_t toField(const char* x);
	static std::string fromField(const uint16_t aField);

	static uint32_t toFourCC(const char* x);
	static std::string fromFourCC(uint32_t x);

	void parse(const std::string& aLine) throw(ParseException);
	uint32_t getCommand() const;
	char getType() const;

	StringList& getParameters();
	//const StringList& getParameters() const;

	std::string toString() const;
	void resetBuffer();

	AdcCommand& addParam(const std::string& name, const std::string& value);
	AdcCommand& addParam(const std::string& str);
	const std::string& getParam(size_t n) const;

	const std::string& getFeatures() const;

#ifndef SWIGLUA
	bool getParam(const char* name, size_t start, std::string& OUTPUT) const;
#endif
	bool delParam(const char* name, size_t start);

	bool hasFlag(const char* name, size_t start) const;

	bool operator==(uint32_t aCmd) const;

	static void escape(const std::string& s, std::string& out);

	uint32_t getTo() const;
	void setTo(uint32_t aTo);
	uint32_t getFrom() const;
	void setFrom(uint32_t aFrom);

%extend {
	std::string getCommandString() {
		int cmd = self->getCommand();
		return std::string(reinterpret_cast<const char*>(&cmd), 3);
	}
	static uint32_t toCMD(const std::string& cmd) {
		if(cmd.length() != 3) {
			return 0;
		}
		return (((uint32_t)cmd[0]) | (((uint32_t)cmd[1])<<8) | (((uint32_t)cmd[2])<<16));
	}
}

};

class Entity {
public:
	Entity(uint32_t sid_) : sid(sid_) {

	}

	void send(const AdcCommand& cmd) { send(cmd.getBuffer()); }
	virtual void send(const BufferPtr& cmd) = 0;

	const std::string& getField(const char* name) const;
	bool hasField(const char* name) const;
	void setField(const char* name, const std::string& value);

	/** Add any flags that have been updated to the AdcCommand (type etc is not set) */
	bool getAllFields(AdcCommand& cmd) const throw();
	const BufferPtr& getINF() const;

	bool addSupports(uint32_t feature);
	StringList getSupportList() const;
	bool hasSupport(uint32_t feature) const;
	bool removeSupports(uint32_t feature);

	const BufferPtr& getSUP() const;

	uint32_t getSID() const;

	bool isFiltered(const std::string& features) const;

	void updateFields(const AdcCommand& cmd);
	void updateSupports(const AdcCommand& cmd) throw();



};

/**
 * The client represents one connection to a user.
 */
class Client : public Entity {
public:
	enum State {
		/** Initial protocol negotiation (wait for SUP) */
		STATE_PROTOCOL,
		/** Identify the connecting client (wait for INF) */
		STATE_IDENTIFY,
		/** Verify the client (wait for PAS) */
		STATE_VERIFY,
		/** Normal operation */
		STATE_NORMAL,
		/** Binary data transfer */
		STATE_DATA
	};

	enum {
		FLAG_BOT = 0x01,
		FLAG_REGISTERED = 0x02,
		FLAG_OP = 0x04,
		FLAG_SU = 0x08,
		FLAG_OWNER = 0x10,
		FLAG_HUB = 0x20,
		MASK_CLIENT_TYPE = FLAG_BOT | FLAG_REGISTERED | FLAG_OP | FLAG_SU | FLAG_OWNER | FLAG_HUB,
		FLAG_PASSWORD = 0x100,
		FLAG_HIDDEN = 0x101,
		/** Extended away, no need to send msg */
		FLAG_EXT_AWAY = 0x102,
		/** Plugins can use these flags to disable various checks */
		/** Bypass ip check */
		FLAG_OK_IP = 0x104
	};

	// static Client* create(const ManagedSocketPtr& ms_, uint32_t sid_) throw();

	virtual void send(const BufferPtr& command) throw() { socket->write(command); }

	size_t getQueuedBytes() throw() { return socket->getQueuedBytes(); }

	/** @param reason The statistic to update */
	void disconnect(Util::Reason reason) throw();
	const ManagedSocketPtr& getSocket() throw() { return socket; }
	const ManagedSocketPtr& getSocket() const throw() { return socket; }
	const std::string& getIp() const throw() { dcassert(socket != NULL); return getSocket()->getIp(); }

	/**
	 * Set data mode for aBytes bytes.
	 * May only be called from on(ClientListener::Command...).
	 */
	typedef std::tr1::function<void (Client&, const uint8_t*, size_t)> DataFunction;
	void setDataMode(const DataFunction& handler, int64_t aBytes) { dataHandler = handler; dataBytes = aBytes; }

	bool isUdpActive() const;
	bool isTcpActive() const;

	bool isFlooding(time_t addSeconds);

	bool isSet(size_t aFlag) const { return flags.isSet(aFlag); }
	bool isAnySet(size_t aFlag) const { return flags.isAnySet(aFlag); }
	//void setFlag(size_t aFlag);
	//void unsetFlag(size_t aFlag);

	const CID& getCID() const { return cid; }
	void setCID(const CID& cid_) { cid = cid_; }
	State getState() const { return state; }
	void setState(State state_) { state = state_; }

};

class LogManager
{
public:
	void log(const std::string& area, const std::string& msg) throw();
};

%template(SignalC) Signal<void (Entity&)>;
%template(SignalTraitsC) SignalTraits<void (Entity&)>;
%template(SignalCA) Signal<void (Entity&, AdcCommand&)>;
%template(SignalTraitsCA) SignalTraits<void (Entity&, AdcCommand&)>;
%template(SignalCAI) Signal<void (Entity&, AdcCommand&, bool&)>;
%template(SignalTraitsCAI) SignalTraits<void (Entity&, AdcCommand&, bool&)>;
%template(SignalCI) Signal<void (Entity&, int)>;
%template(SignalTraitsCI) SignalTraits<void (Entity&, int)>;
%template(SignalCS) Signal<void (Entity&, const std::string&)>;
%template(SignalTraitsCS) SignalTraits<void (Entity&, const std::string&)>;
%template(SignalS) Signal<void (const SimpleXML&)>;
%template(SignalTraitsS) SignalTraits<void (const SimpleXML&)>;

class ClientManager
{
public:
	typedef std::tr1::unordered_map<uint32_t, Entity*> EntityMap;
	typedef EntityMap::iterator EntityIter;

	uint32_t getSID(const std::string& nick) const throw();
	uint32_t getSID(const CID& cid) const throw();

	Entity* getEntity(uint32_t aSid) throw();

	// EntityMap& getEntities() throw() { return entities; }

	%extend{
	EntityList getEntities() throw() {
		EntityList ret;
		for(ClientManager::EntityMap::iterator i = self->getEntities().begin(); i != self->getEntities().end(); ++i) {
			ret.push_back(i->second);
		}
		return ret;
	}

	Entity* findByNick(const std::string& nick) {
		uint32_t sid = self->getSID(nick);
		if(sid != 0) {
			return self->getEntity(sid);
		}

		return 0;
	}
	}

	void send(const AdcCommand& cmd) throw();
	void sendToAll(const BufferPtr& buffer) throw();
	void sendTo(const BufferPtr& buffer, uint32_t to);

	bool checkFlooding(Client& c, const AdcCommand&) throw();

	void enterIdentify(Client& c, bool sendData) throw();

	ByteVector enterVerify(Client& c, bool sendData) throw();
	bool enterNormal(Client& c, bool sendData, bool sendOwnInf) throw();
	bool verifySUP(Client& c, AdcCommand& cmd) throw();
	bool verifyINF(Client& c, AdcCommand& cmd) throw();
	bool verifyNick(Client& c, const AdcCommand& cmd) throw();
	bool verifyPassword(Client& c, const std::string& password, const ByteVector& salt, const std::string& suppliedHash);
	bool verifyIp(Client& c, AdcCommand& cmd) throw();
	bool verifyCID(Client& c, AdcCommand& cmd) throw();
	void setState(Client& c, Client::State newState) throw();
	size_t getQueuedBytes() throw();

	typedef SignalTraits<void (Entity&)> SignalConnected;
	typedef SignalTraits<void (Entity&, AdcCommand&, bool&)> SignalReceive;
	typedef SignalTraits<void (Entity&, const std::string&)> SignalBadLine;
	typedef SignalTraits<void (Entity&, const AdcCommand&, bool&)> SignalSend;
	typedef SignalTraits<void (Entity&, int)> SignalState;
	typedef SignalTraits<void (Entity&)> SignalDisconnected;

	SignalConnected::Signal& signalConnected() { return signalConnected_; }
	SignalReceive::Signal& signalReceive() { return signalReceive_; }
	SignalBadLine::Signal& signalBadLine() { return signalBadLine_; }
	SignalSend::Signal& signalSend() { return signalSend_; }
	SignalState::Signal& signalState() { return signalState_; }
	SignalDisconnected::Signal& signalDisconnected() { return signalDisconnected_; }

	//virtual ~ClientManager() throw() { }
};

class SimpleXML
{
public:
	SimpleXML(int numAttribs = 0);
	~SimpleXML();

	void addTag(const std::string& aName, const std::string& aData = Util::emptyString) throw(SimpleXMLException);
	void addAttrib(const std::string& aName, const std::string& aData) throw(SimpleXMLException);
	void addChildAttrib(const std::string& aName, const std::string& aData) throw(SimpleXMLException);

	const std::string& getData() const;
	void stepIn() const throw(SimpleXMLException);
	void stepOut() const throw(SimpleXMLException);

	void resetCurrentChild() const throw();
	bool findChild(const std::string& aName) const throw();

	const std::string& getChildData() const throw(SimpleXMLException);

	const std::string& getChildAttrib(const std::string& aName, const std::string& aDefault = Util::emptyString) const throw(SimpleXMLException);

	int getIntChildAttrib(const std::string& aName) throw(SimpleXMLException);
	int64_t getLongLongChildAttrib(const std::string& aName) throw(SimpleXMLException);
	bool getBoolChildAttrib(const std::string& aName) throw(SimpleXMLException);
	void fromXML(const std::string& aXML) throw(SimpleXMLException);
	std::string toXML();

	static void escape(std::string& aString, bool aAttrib, bool aLoading = false);
	/**
	 * This is a heurestic for whether escape needs to be called or not. The results are
 	 * only guaranteed for false, i e sometimes true might be returned even though escape
	 * was not needed...
	 */
	static bool needsEscape(const std::string& aString, bool aAttrib, bool aLoading = false);
};

class TigerHash {
public:
	/** Hash size in bytes */
	enum { BITS = 192, BYTES = BITS / 8 }; // Keep old name for a while

	TigerHash();

	%extend {
		void update(const std::string& data) {
			self->update(data.data(), data.size());
		}
		std::string finalize() {
			return std::string(reinterpret_cast<const char*>(self->finalize()), TigerHash::BYTES);
		}
	}
};

class Encoder
{
public:
	%extend {
		static std::string toBase32(const std::string& src) {
			return Encoder::toBase32(reinterpret_cast<const uint8_t*>(src.data()), src.size());
		}
		static std::string fromBase32(const std::string& src) {
			std::string result((src.length()*5)/8, 0);
			Encoder::fromBase32(src.data(), reinterpret_cast<uint8_t*>(&result[0]), result.size());
			return result;
		}
	}
};

class PluginManager
{
public:
	void attention(const std::tr1::function<void()>& f);

	//typedef HASH_MAP<std::string, Plugin*> Registry;
	//typedef Registry::iterator RegistryIter;

	const StringList& getPluginList() const;
	const std::string& getPluginPath() const;
	//int getPluginId() { return pluginIds++; }

	//bool registerPlugin(const std::string& name, Plugin* ptr);
	//bool unregisterPlugin(const std::string& name);
	//Plugin* getPlugin(const std::string& name);
	//const Registry& getPlugins();
	//void load();
	//void shutdown();
//	typedef std::tr1::function<void (Client&, const StringList&, int& override)> CommandSlot;
	%extend {
		ManagedConnectionPtr onCommand(const std::string& commandName, std::tr1::function<void (Entity&, const StringList&, bool& override)> f) {
			return ManagedConnectionPtr(new ManagedConnection(self->onCommand(commandName, f)));
		}
	}

};

%template (ServerInfoPtr) boost::intrusive_ptr<ServerInfo>;
%template (ManagedConnectrionPtr) boost::intrusive_ptr<ManagedConnection>;
%template(TLSServerInfoPtr) boost::intrusive_ptr<TLSServerInfo>;

}

%inline%{
namespace adchpp {
	ClientManager* getCM() { return ClientManager::getInstance(); }
	LogManager* getLM() { return LogManager::getInstance(); }
	PluginManager* getPM() { return PluginManager::getInstance(); }
	SocketManager* getSM() { return SocketManager::getInstance(); }
}
%}
