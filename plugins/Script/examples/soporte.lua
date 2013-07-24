-- This script contains settings and commands related to the bot. If this script is not loaded, the bot will not appear...
-- The main bot managed by this script is stored in the public "supchat_bot" variable.

local base=_G
module("supchat")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local simplebot = base.require("simplebot")

local commands = access.commands
local cm = adchpp.getCM()

supchat_bot = simplebot.makeBot (_NAME, 'supchat_', nil, {adchpp.Entity_FLAG_OP,adchpp.Entity_FLAG_SU,adchpp.Entity_FLAG_OWNER},
			"Soporte", "Chat de Soporte").bot

local function onMSG(c, cmd)
	if autil.reply_from and autil.reply_from:getSID() == supchat_bot:getSID() then
		local msg = cmd:getParam(0)

		local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, c:getSID()+0)
		:addParam(msg)
		:addParam("PM", adchpp.AdcCommand_fromSID(supchat_bot:getSID()+0))
		
		local entities = cm:getEntities()
		local size = entities:size()
		if size == 0 then
			return false
		end

		for i = 0, size - 1 do
			local other = entities[i]:asClient()
			if other then
				mass_cmd:setTo(other:getSID())
				other:send(mass_cmd)
			end
		end

		return false
	end
	return true
end

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG)
