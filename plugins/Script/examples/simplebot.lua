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
local pm = adchpp.getPM()
local bots = {}

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
	--TODO: callback should pass this object instead of the bot style one
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
	bots[boto.bot:getSID()]=boto
	return boto
end

local function chatRoomCallback (bot, buffer)
	local boto = bots[bot:getSID()]
	cmd = adchpp.AdcCommand(buffer)
	if cmd:getCommand() ~= adchpp.AdcCommand_CMD_MSG or (cmd:getType() ~= adchpp.AdcCommand_TYPE_DIRECT  and cmd:getType() ~= adchpp.AdcCommand_TYPE_ECHO) or cmd:getParam("PM", 1) == "" then
		return false
	end
	local from = cm:getEntity(cmd:getFrom())
	if not from then
		return false
	end
	local msg = cmd:getParam(0)

	if (msg:sub(1,1) == "+") then
		pcmd,pargs=msg:match("\+(%S+)%s*(.*)")
		if pcmd then
			pcmd = pcmd:lower()
		end
		if(boto.cmdcallback[pcmd] and not boto.cmdcallback[pcmd](boto,from,pcmd, pargs)) then
			return
		end
		if (boto.standard_cmds) then
			if (pcmd == "subscribe" or pcmd == "join") then
				boto:maybeSubscribe(from)
			elseif (pcmd == "unsubscribe" or pcmd == "leave") then
				boto:unsubscribe(from)
			end
		end
	end
	
	if boto.msgsubscribe then
		boto:maybeSubscribe(from)
	end

	if( not boto.msgcallback or boto.msgcallback(boto,from,msg)) then
		boto:send(from, msg)
	end
	return false
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
function makeChatRoom (modname, settingsname, msgcallback, cmdcallback, announce_subscriptions, standard_cmds, externalmsgs, cansubscribe, autosubscribe, msgsubscribe, flags, defname, defdescription, defemail, defcid)
	local boto = makeBot (modname, settingsname, chatRoomCallback, flags, defname, defdescription, defemail, defcid)
	if not boto then
		return
	end
	boto.subscribe = (function (boto,entity) 
		if boto.announce_subscriptions then
			boto:send(boto.bot,"User has joined: " .. entity:getField('NI'))
		end
		entity:setPluginData(boto.subscribers,true)
	end)
	boto.isSubscribed = (function (boto,entity)
		return entity:getPluginData(boto.subscribers) == true
	end)
	boto.maySubscribe = (function (boto,entity) 
		return (not boto.cansubscribe or boto.cansubscribe(entity))
	end)
	boto.maybeSubscribe = (function (boto,entity) 
		if entity and not boto:isSubscribed(entity) and boto:maySubscribe(entity) then
			boto:subscribe(entity)
		end
	end)
	boto.unsubscribe = (function (boto,entity)
		if boto.announce_subscriptions and isSubscribed(entity) then
			boto:send(boto.bot,"User has left: " .. c:getField('NI'))
		end
		entity:setPluginData(boto.subscribers,nil)
	end)
	boto.botSay = ( function (boto,msg)
		boto:send(boto.bot, msg)
	end)
	boto.pm = ( function (boto,to,msg)
		local tsid = to:getSID()+0
		local bsid = boto.bot:getSID()+0
		local msg = autil.pm(msg, bsid, tsid)
		to:send(msg)
	end)
	boto.send = ( function (boto,from, msg)
		local fsid = from:getSID()+0
		local bsid = boto.bot:getSID()+0
		if not boto:isSubscribed(from) and not boto.externalmsgs and not (fsid == bsid) then
			return
		end

		local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, fsid)
			:addParam(msg):addParam("PM", adchpp.AdcCommand_fromSID(bsid))
		local entities = adchpp.getCM():getEntities()
		local size = entities:size()
		for i = 0, size - 1 do
			local c = entities[i]:asClient()
			if c then --dynamic cast prevents bots and hub
				if boto:isSubscribed(c) then
					mass_cmd:setTo(c:getSID())
					c:send(mass_cmd)
				end
			end
		end
		if (not boto:isSubscribed(from) and not (fsid == bsid)) then
			boto:pm(from,"Your message was sent")
		end
	end)
	
	if autosubscribe then
		boto.autosubscriber = cm:signalState():connect(function(entity)
			if entity:getState() == adchpp.Entity_STATE_NORMAL then
				local c = entity:asClient()
				if c then
					boto.maybeSubscribe(c)
				end
			end
		end)
	end

	boto.subscribers=pm:registerPluginData()
	boto.msgcallback = msgcallback
	boto.cmdcallback =  cmdcallback
	boto.announce_subscriptions =  announce_subscriptions
	boto.standard_cmds =  standard_cmds
	boto.externalmsgs =  externalmsgs
	boto.cansubscribe =  cansubscribe
	boto.autosubscribe =  autosubscribe
	boto.msgsubscribe =  msgsubscribe
	if autosubscribe then
		boto.subscriber = cm:signalState():connect(function(entity)
			if entity:getState() == adchpp.Entity_STATE_NORMAL then
				local c = entity:asClient()
				if c then
					boto:maybeSubscribe(c)
				end
			end
		end)
	end

	return boto
end


botsDisco = cm:signalDisconnected():connect(function(e, reason, info)
	local boto = bots[e:getSID()]
	if boto and boto.autosubscriber then boto.autosubscriber() end
	bots[e:getSID()]=nil
end)

autil.on_unloaded(_NAME, botsDisco)


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

