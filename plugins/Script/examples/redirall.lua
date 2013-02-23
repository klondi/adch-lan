-- Redirect all the users to another hub 

local base=_G
module("redirall")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local string = base.require("string")

local commands = access.commands
local settings = access.settings
local get_level = access.get_level
local is_adm = access.is_adm

local cm = adchpp.getCM()

commands.redirectall = {
	alias = { forwardall = true },

	command = function(c, parameters)
		local level = get_level(c)
		if not is_adm(c) then
			return
		end

		local address = parameters:match("^(%S+)")
		if not address then
			autil.reply(c, "You need to supply an address")
			return
		end
		local entities = cm:getEntities()
		local size = entities:size()
		if size > 0 then
			for i = 0, size - 1 do
				local c = entities[i]:asClient()
				if c then
					autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd) cmd:addParam("RD" .. address) end)
				end
			end
		end
	end,

	help = "address - redirect users to said address",

	protected = is_adm
}
