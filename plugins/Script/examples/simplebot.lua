-- This script contains a library for easy bot handling

local base=_G
module("simplebot")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local string = base.require('string')
local autil = base.require("autil")

local settings = access.settings
local commands = access.commands
local cm = adchpp.getCM()

local function makesettings (boto)
	access.add_setting(boto.settingsname..'cid', {
		alias = { [boto.settingsname.."id"] = true },

		help = "CID of the bot "..boto.settingsname..", restart the hub after the change",

		value = boto.cid,

		validate = validatecid
	})

	access.add_setting(boto.settingsname..'name', {
		alias = { [boto.settingsname.."nick"] = true, [boto.settingsname.."ni"] = true },

		change = function() boto:changename(settings[boto.settingsname..'name'].value) end,

		help = "name of the bot "..boto.settingsname,

		value = boto.name,

		validate = access.validate_ni
	})

	access.add_setting(boto.settingsname..'description', {
		alias = { [boto.settingsname.."descr"] = true, [boto.settingsname.."de"] = true },

		change = function() boto:changedescription(settings[boto.settingsname..'description'].value) end,

		help = "description of the bot" .. boto.settingsname,

		value = boto.description,

		validate = access.validate_de
	})

	access.add_setting(boto.settingsname..'email', {
		alias = { [boto.settingsname.."mail"] = true, [boto.settingsname.."em"] = true },

		change = function() boto:changeemail(settings[boto.settingsname..'email'].value) end,

		help = "e-mail of the "..boto.settingsname.." bot",

		value = boto.email
	})
	boto.cid = settings[boto.settingsname..'cid'].value
	boto.name = settings[boto.settingsname..'name'].value
	boto.description = settings[boto.settingsname..'description'].value
	boto.email = settings[boto.settingsname..'email'].value
end

local function notifychange(boto, param, longparam, value)
	boto[longparam] = value
	if boto.bot then
		boto.bot:setField(param, value)
		cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, boto.bot:getSID()):addParam(param, value):getBuffer())
	end
end

local function makethebot(boto)
	local bot
	if (boto.callback) then
		bot = cm:createBot(boto.callback)
	else
		bot = cm:createSimpleBot()
	end
	bot:setCID(adchpp.CID(boto.cid))
	bot:setField("ID", boto.cid)
	bot:setField("NI", boto.name)
	bot:setField("DE", boto.description)
	bot:setField("EM", boto.email)
	for _,v in base.pairs(boto.flags) do
		bot:setFlag(v)
	end
	boto.bot = bot
end

local function addunloadcallback(modname, boto)
	autil.on_unloaded(modname, function() boto.bot:disconnect(adchpp.Util_REASON_PLUGIN) end)
end

-- Usage: makeBot (_NAME, botname, callback=nil, flags={}, withsettings=true, defname=botname, defdescription="", defemail="", defcid=adchpp.CID_generate():toBase32())
-- for example makeBot (_NAME, nil)
-- makeBot (_NAME, 'mybot', action, {adchpp.Entity_FLAG_HIDDEN}, true, 'My Cool Bot', 'This is a cool bot', 'botty@bot.bot', 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
-- The parameters are:
-- _NAME = name of the module, used for the unload callback
-- settingsname = name of the bot used for settings generation, leave to nil if you don't wantsettings
-- callback = function to call when receiving values, comes in the form function (bot, cmd) where bot is the bot object and cmd the command received
-- flags = flags to ser from adchpp.Entity_FLAG_ the bot flag is setted automatically
-- defname = default name shown for the bot (or the actual one if no settings)
-- defdescription = default description shown for the bot (or the actual one if no settings)
-- defemail = default email shown for the bot (or the actual one if no settings)
-- defcid = default cid shown for the bot (or the actual one if no settings)
-- Returns a lua bot object, to get the actual bot object use .bot
function makeBot (modname, settingsname, callback, flags, defname, defdescription, defemail, defcid)
	--Set the default values
	local boto = {}
	boto.changename = function (bot,value) notifychange(bot, "NI", "name", value) end
	boto.changedescription = function (bot,value) notifychange(bot, "DE", "description", value) end
	boto.changeemail = function (bot,value) notifychange(bot, "EM", "email", value) end
	boto.settingsname = settingsname
	boto.callback = callback
	boto.flags = flags or {}
	boto.cid = defcid or adchpp.CID_generate():toBase32()
	boto.name = defname or settingsname or "Bot"
	boto.description = defdescription or ""
	boto.email = defemail or ""
	if boto.settingsname then
		makesettings(boto)
	end
	makethebot(boto)
	cm:regBot(boto.bot)
	addunloadcallback(modname, boto)
	return boto
end

-- Returns nil when valid
function validatecid (new)
	if adchpp.CID(new.value):toBase32() ~= new.value then
		return "the CID must be a valid 39-byte base32 representation"
	end
end

validatenick = access.validate_ni
validatedescription = access.validate_de
function validateemail (new)
	return nil
end

