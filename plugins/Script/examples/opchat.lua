-- This script contains settings and commands related to the bot. If this script is not loaded, the bot will not appear...
-- The main bot managed by this script is stored in the public "opchat_bot" variable.

local base=_G
module("opchat")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local simplebot = base.require("simplebot")

local commands = access.commands
local cm = adchpp.getCM()
local is_op = access.is_op
local is_org = access.is_org

opchat_bot = simplebot.makeBot (_NAME, 'opchat_', nil, {adchpp.Entity_FLAG_OP,adchpp.Entity_FLAG_SU,adchpp.Entity_FLAG_OWNER},
			"OpChat", "Operator chat, write here to contact operators").bot

local function doOpSay(c, parameters)
	if not is_op(c) then
		return
	end
	local nick = c:getField("NI")
	if #nick < 1 then
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
	local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, opchat_bot:getSID()+0)
	:addParam('Said on behalf of '..nick..' to '..user..' the message '..message)
	:addParam("PM", adchpp.AdcCommand_fromSID(opchat_bot:getSID()+0))
		
	local entities = cm:getEntities()
	local size = entities:size()
	for i = 0, size - 1 do
		local other = entities[i]:asClient()
		if other and is_org(other) then
			mass_cmd:setTo(other:getSID())
			other:send(mass_cmd)
		end
	end
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
			if other and is_org(other) then
				mass_cmd:setTo(other:getSID())
				other:send(mass_cmd)
			end
		end

		if not is_org(c) then
			autil.reply(c, 'Your message was sent')
		end
		return false
	end
	return true
end

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG)

commands.opsay = {
	command = doOpSay,

	help = "user message - Send message as the opchat",

	protected = is_op
}
