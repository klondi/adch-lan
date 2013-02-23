-- This script contains settings and commands related to the bot. If this script is not loaded, the bot will not appear...
-- The main bot managed by this script is stored in the public "opchat_bot" variable.

local base=_G
module("opchat")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local string = base.require('string')
local autil = base.require("autil")

local settings = access.settings
local commands = access.commands
local cm = adchpp.getCM()
local is_op = access.is_op

opchat_bot = nil

access.add_setting('opchat_botcid', {
	alias = { botid = true },

	help = "CID of the opchat bot, restart the hub after the change",

	value = adchpp.CID_generate():toBase32(),

	validate = function(new)
		if adchpp.CID(new.value):toBase32() ~= new.value then
			return "the CID must be a valid 39-byte base32 representation"
		end
	end
})

access.add_setting('opchat_botname', {
	alias = { botnick = true, botni = true },

	change = function()
		if opchat_bot then
			opchat_bot:setField("NI", settings.botname.value)
			cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, opchat_bot:getSID()):addParam("NI", settings.botname.value):getBuffer())
		end
	end,

	help = "name of the opchat bot",

	value = "OpChat",

	validate = access.validate_ni
})

access.add_setting('opchat_botdescription', {
	alias = { botdescr = true, botde = true },

	change = function()
		if opchat_bot then
			opchat_bot:setField("DE", settings.botdescription.value)
			cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, opchat_bot:getSID()):addParam("DE", settings.botdescription.value):getBuffer())
		end
	end,

	help = "description of the opchat bot",

	value = "Operator chat, write here to contact operators",

	validate = access.validate_de
})

access.add_setting('opchat_botemail', {
	alias = { botmail = true, botem = true },

	change = function()
		if opchat_bot then
			opchat_bot:setField("EM", settings.botemail.value)
			cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, opchat_bot:getSID()):addParam("EM", settings.botemail.value):getBuffer())
		end
	end,

	help = "e-mail of the opchat bot",

	value = ""
})

local function doOpSay(c, parameters)
	if not is_op(c) then
		return
	end
	local user, message = parameters:match("^(%S+) (.+)")

	if not user or #user <= 0 or not message or #message <= 0 then
		autil.reply(c, "Usage: nick message")
		return
	end

	local victim = cm:findByNick(user)
	if not victim then
		autil.reply(c, "No user nick-named \"" .. user .. "\"")
		return
	end
	victim = victim:asClient()

	local pm = autil.pm(message, opchat_bot:getSID()+0, victim:getSID()+0)
	victim:send(pm)
	autil.reply(c, 'Your message was sent')
end


local function onMSG(c, cmd)
	if autil.reply_from and autil.reply_from:getSID() == opchat_bot:getSID() then
		local msg = cmd:getParam(0)

		local parameters, _ = msg:match("^%+opsay ?(.*)")
		if parameters then
			access.add_stats('+opsay')
			doOpSay(c, parameters)
			return false
		end

		local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, c:getSID()+0)
		:addParam(msg)
		:addParam("PM", adchpp.AdcCommand_fromSID(opchat_bot:getSID()+0))
		
		local entities = cm:getEntities()
		local size = entities:size()
		if size == 0 then
			return false
		end

		for i = 0, size - 1 do
			local other = entities[i]:asClient()
			if other and is_op(other) then
				mass_cmd:setTo(other:getSID())
				other:send(mass_cmd)
			end
		end

		if not is_op(c) then
			autil.reply(c, 'Your message was sent')
		end
		return false
	end
	return true
end

local function makeBot()
	local bot = cm:createSimpleBot()
	bot:setCID(adchpp.CID(settings.opchat_botcid.value))
	bot:setField("ID", settings.opchat_botcid.value)
	bot:setField("NI", settings.opchat_botname.value)
	bot:setField("DE", settings.opchat_botdescription.value)
	bot:setField("EM", settings.opchat_botemail.value)
	bot:setFlag(adchpp.Entity_FLAG_BOT)
	bot:setFlag(adchpp.Entity_FLAG_OP)
	bot:setFlag(adchpp.Entity_FLAG_SU)
	bot:setFlag(adchpp.Entity_FLAG_OWNER)
	return bot
end

opchat_bot = makeBot()
cm:regBot(opchat_bot)

autil.on_unloaded(_NAME, function()
	opchat_bot:disconnect(adchpp.Util_REASON_PLUGIN)
end)

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG)

commands.opsay = {
	command = doOpSay,

	help = "user message - Send message as the opchat",

	protected = is_op
}
