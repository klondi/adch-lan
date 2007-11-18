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

#ifndef ADCHPP_SETTINGSMANAGER_H
#define ADCHPP_SETTINGSMANAGER_H

#include "Util.h"
#include "Signal.h"
#include "Singleton.h"

namespace adchpp {

class SimpleXML;

class SettingsManager : public Singleton<SettingsManager>
{
public:
	enum Types {
		TYPE_STRING,
		TYPE_INT,
		TYPE_INT64
	};

	enum StrSetting { STR_FIRST,
		HUB_NAME = STR_FIRST, SERVER_IP, LOG_FILE, DESCRIPTION,
		LANGUAGE_FILE, 
		STR_LAST };

	enum IntSetting { INT_FIRST = STR_LAST + 1,
		SERVER_PORT = INT_FIRST, LOG, KEEP_SLOW_USERS, 
		MAX_SEND_SIZE, MAX_BUFFER_SIZE, BUFFER_SIZE, MAX_COMMAND_SIZE, 
		OVERFLOW_TIMEOUT, DISCONNECT_TIMEOUT, FLOOD_ADD, FLOOD_THRESHOLD, 
		LOGIN_TIMEOUT,
		INT_LAST, SETTINGS_LAST = INT_LAST };

	/**
	 * Get the type of setting based on its name. By using the type info you can
	 * convert the n to the proper enum type and get the setting.
	 * @param name The name as seen in the settings file
	 * @param n Setting number
	 * @param type Type of setting (use this to actually get the setting later on
	 * @return True if the setting was found, false otherwise.
	 */
	ADCHPP_DLL bool getType(const char* name, int& n, int& type);
	/**
	 * Get the XML name of a setting
	 * @param n Setting identifier
	 */
	const std::string& getName(int n) { dcassert(n < SETTINGS_LAST); return settingTags[n]; }

	const std::string& get(StrSetting key) const {
		return strSettings[key - STR_FIRST];
	}

	int get(IntSetting key) const {
		return intSettings[key - INT_FIRST];
	}

	bool getBool(IntSetting key) const {
		return (get(key) > 0);
	}

	void set(StrSetting key, const std::string& value) {
		strSettings[key - STR_FIRST] = value;
	}

	void set(IntSetting key, int value) {
		intSettings[key - INT_FIRST] = value;
	}

	template<typename T> void set(IntSetting key, const T& value) {
		intSettings[key - INT_FIRST] = Util::toInt(value);
	}

	void set(IntSetting key, bool value) { set(key, (int)value); }

	void load() {
		load(Util::getCfgPath() + _T("adchpp.xml"));
	}

	void load(const std::string& aFileName);

	typedef SignalTraits<void (const SimpleXML&)> SignalLoad;
	SignalLoad::Signal& signalLoad() { return signalLoad_; }
private:
	friend class Singleton<SettingsManager>;
	ADCHPP_DLL static SettingsManager* instance;
	
	SettingsManager() throw();
	virtual ~SettingsManager() throw() { }

	ADCHPP_DLL static const std::string settingTags[SETTINGS_LAST+1];

	static const std::string className;

	std::string strSettings[STR_LAST - STR_FIRST];
	int intSettings[INT_LAST - INT_FIRST];
	int64_t int64Settings[/*INT64_LAST - INT64_FIRST*/1];
	
	SignalLoad::Signal signalLoad_;
};


// Shorthand accessor macros
#define SETTING(k) (SettingsManager::getInstance()->get(SettingsManager::k))
#define BOOLSETTING(k) (SettingsManager::getInstance()->getBool(SettingsManager::k))

}

#endif // SETTINGSMANAGER_H
