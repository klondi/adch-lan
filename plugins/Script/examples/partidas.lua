-- This script contains settings and commands related to the bot. If this script is not loaded, the bot will not appear...
-- The main bot managed by this script is stored in the public "gamchat_bot" variable.

local base=_G
module("gamchat")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local simplebot = base.require("simplebot")

local commands = access.commands
local cm = adchpp.getCM()

gamchat_bot = simplebot.makeBot (_NAME, 'gamchat_', nil, {adchpp.Entity_FLAG_OP,adchpp.Entity_FLAG_SU,adchpp.Entity_FLAG_OWNER},
			"Partidas", "Chat de Partidas").bot

local function onMSG(c, cmd)
	if autil.reply_from and autil.reply_from:getSID() == gamchat_bot:getSID() then
		local msg = cmd:getParam(0)

		local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, c:getSID()+0)
		:addParam(msg)
		:addParam("PM", adchpp.AdcCommand_fromSID(comchat_bot:getSID()+0))
		
		local entities = cm:getEntities()
		local size = entities:size()
		if size == 0 then
			return false
		end

		for i = 0, size - 1 do
			local other = entities[i]:asClient()
			if other and not other == c then
				mass_cmd:setTo(other:getSID())
				other:send(mass_cmd)
			end
		end

		return false
	end
	return true
end

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG)
