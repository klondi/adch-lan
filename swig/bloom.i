%module luadchppbloom

%runtime %{

#include <adchpp/adchpp.h>

#include <adchpp/PluginManager.h>
#include <adchpp/Core.h>
#include <adchpp/Signal.h>
#include <adchpp/Entity.h>

using namespace adchpp;

%}

%include "exception.i"
%import "lua.i"

%runtime %{
#include <plugins/Bloom/src/stdinc.h>
#include <plugins/Bloom/src/BloomManager.h>
#include <iostream>
%}

using namespace std;

template<typename T>
struct shared_ptr {
	T* operator->();
};

%{
	static adchpp::Core *getCurrentCore(lua_State *l) {
		lua_getglobal(l, "currentCore");
		void *core = lua_touserdata(l, lua_gettop(l));
		lua_pop(l, 1);
		return reinterpret_cast<Core*>(core);
	}

%}

template<typename F>
struct Signal {
%extend {
	ManagedConnectionPtr connect(std::function<F> f) {
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


%template(SignalE) Signal<void (Entity&)>;
%template(SignalTraitsE) SignalTraits<void (Entity&)>;

class BloomManager {
public:
	bool hasBloom(adchpp::Entity& c);
	int64_t getSearches() const;
	int64_t getTTHSearches() const;
	int64_t getStoppedSearches() const;
	typedef SignalTraits<void (Entity&)> SignalBloomReady;
	SignalBloomReady::Signal& signalBloomReady();
};

%extend BloomManager {
	bool hasTTH(adchpp::Entity& c, std::string tth) {
		return self->hasTTH(c, TTHValue(tth));
	}
}

%template(TBloomManagerPtr) shared_ptr<BloomManager>;

%inline %{

namespace adchpp {
/* Get Bloom Manager */
shared_ptr<BloomManager> getBM(lua_State* l) {
	return dynamic_pointer_cast<BloomManager>(getCurrentCore(l)->getPluginManager().getPlugin("BloomManager"));
}

}

%}
