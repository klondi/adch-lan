-- This script contains settings and commands related to the bot. If this script is not loaded, the bot will not appear...
-- The main bot managed by this script is stored in the public "main_bot" variable.

local base=_G
module("access.bot")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local simplebot = base.require("simplebot")

main_bot = simplebot.makeBot (_NAME, "bot", nil, {adchpp.Entity_FLAG_OP,adchpp.Entity_FLAG_SU,adchpp.Entity_FLAG_OWNER}, "Bot").bot

local function onMSG(c, cmd)
	if autil.reply_from and autil.reply_from:getSID() == main_bot:getSID() then

		local msg = cmd:getParam(0)
		if access.handle_plus_command(c, msg) then
			return false
		end

		autil.reply(c, 'Invalid command, send "+help" for a list of available commands')
		return false
	end

	return true
end
access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG)
