-- This script enforces some soft limits

local base=_G
module("access.bans")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local aio = base.require('aio')
local autil = base.require("autil")
local json = base.require("json")
local os = base.require("os")
local string = base.require("string")
local table = base.require("table")

local settings = access.settings
local commands = access.commands
local get_level = access.get_level
local set_level = access.set_level
local is_op = access.is_op

local cm = adchpp.getCM()
local sm = adchpp.getSM()
local lm = adchpp.getLM()

access.add_setting('min_share_lvl1', {
	alias = { },

	help = "Minimum share size to get to level 1",

	value = 0,

	change = relevel
})

access.add_setting('min_files_lvl1', {
	alias = { },

	help = "Minimum number of files shared to get to level 1",

	value = 0,

	change = relevel
})

access.add_setting('range1_begin', {
	alias = { },

	help = "Ip where the local range 1 begins",

	value = "0.0.0.0",

	change = relevel
})

access.add_setting('range1_end', {
	alias = { },

	help = "Ip where the local range 1 ends",

	value = "255.255.255.255",

	change = relevel
})


access.add_setting('range2_begin', {
	alias = { },

	help = "Ip where the local range 2 begins",

	value = "10.0.0.0",

	change = relevel
})

access.add_setting('range2_end', {
	alias = { },

	help = "Ip where the local range 2 ends",

	value = "10.255.255.255",

	change = relevel
})


local min_share_l1 = access.settings.min_share_lvl1.value
local min_files_l1 = access.settings.min_files_lvl1.value

local function ip2int (ip)
	local ret = 0
	for s in string.gmatch(ip, "%d+") do
		ret = ret * 256 + s
	end
	return ret
end

local range1begin = ip2int(access.settings.range1_begin.value)
local range1end   = ip2int(access.settings.range1_end.value)
local range2begin = ip2int(access.settings.range2_begin.value)
local range2end   = ip2int(access.settings.range2_end.value)

local function inrange (ip)
	local nip = ip2int(ip)
	return ((nip >= range1begin and nip <= range1end) or (nip >= range2begin and nip <= range2end))
end

local function relevel ()
	min_share_l1 = access.settings.min_share_lvl1.value
	min_files_l1 = access.settings.min_files_lvl1.value
	range1begin = ip2int(access.settings.range1_begin.value)
	range1end   = ip2int(access.settings.range1_end.value)
	range2begin = ip2int(access.settings.range2_begin.value)
	range2end   = ip2int(access.settings.range2_end.value)
	local entities = cm:getEntities()
	local size = entities:size()
	if size > 0 then
		for i = 0, size - 1 do
			local c = entities[i]:asClient()
			if c then
				local ip = c:getIp()
				local nick = c:getField("NI")
				if (string.find(nick,"^%[EXT%]")) and (inrange(ip)) then
					autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, "You can't prefix your nick with [EXT] if connecting from inside")
				end
				if (not string.find(nick,"^%[EXT%]")) and (not inrange(ip)) then
					autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, "You must prefix your nick with [EXT] if connecting from outside")
				end
				autolevel(c,get_int_field(c,"SS"),get_int_field(c,"SF"))
			end
		end
	end
end

local function autolevel (c, ss, sf)
	local lvl = access.get_level(c)
	if lvl < 2 then
		if ss >= min_share_l1 and sf >= min_files_l1 and inrange(c:getIp()) then
			set_level(c,1)
		else
			set_level(c,0)
		end
	end
	return true
end


local function get_int_field (c,param)
	if c:hasField(param) then
		return base.tonumber(c:getField(param))
	else
		return 0
	end
end

local function get_int_param (c, cmd, param)
	if cmd:hasParam(param,0) then
		local pv = cmd:getParam(param,0)
		if #pv > 0 then
			return base.tonumber(pv)
		else
			return 0
		end
	else
		return get_int_field (c, param)
	end
end

local function get_str_param (c, cmd, param)
	if cmd:hasParam(param,0) then
		local pv = cmd:getParam(param,0)
		if #pv > 0 then
			return pv
		else
			return nil
		end
	else
		if c:hasField(param) then
			return c:getField(param)
		else
			return nil
		end
	end
end

access.register_handler(adchpp.AdcCommand_CMD_INF, (function(entity, cmd)
	local c = entity:asClient()
	if c then
		local ip = c:getIp()
		local nick = get_str_param (c, cmd, "NI")
		if not nick then
			autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, "You need a nickname!")
			return false
		end
		if (string.find(nick,"^%[EXT%]")) and (inrange(ip)) then
			autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, "You can't prefix your nick with [EXT] if connecting from inside")
			return false
		end
		if (not string.find(nick,"^%[EXT%]")) and (not inrange(ip)) then
			autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, "You must prefix your nick with [EXT] if connecting from outside")
			return false
		end
	end
	autolevel(c,get_int_param(c,cmd,"SS"),get_int_param(c,cmd,"SF"))
	return true
end))

--Required because access otherwise keeps 0
autolevel_1 = cm:signalState():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		local c = entity:asClient()
		if c then
			autolevel(c,get_int_field(c,"SS"),get_int_field(c,"SF"))
		end
	end
end)


