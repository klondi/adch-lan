local base = _G

-- Notifies a user he may have empty files in his share according to his BLOOM
-- Requires that the Bloom plugin is loaded

module("checkbloomdb")
bloom=false

base.require('luadchpp')
local adchpp = base.luadchpp
base.require('luadchppbloom')
if bloom then
	local badchpp = base.luadchppbloom
	local bm = badchpp.getBM()
end
local access = base.require("access")

local string = base.require('string')
local io = base.require('io')
local math = base.require('math')
local table = base.require('table')
local autil = base.require('autil')
local simplebot = base.require("simplebot")

local cm = adchpp.getCM()

-- Where to read unwanted TTH list
local file = adchpp.Util_getCfgPath() .. "unwanted.txt"


local is_op = access.is_op
local search_bot = simplebot.makeBot (_NAME, nil, nil, {}, "Juanda","","","NTC7NGIO3NN5EKM7E24X63AJE4MAEENZOVRILPI").bot

local unwanted

local function load_unwanted()
	local tth, reason, f, err
	unwanted = {}
	f, err = io.open(file)
	if not f then
		adchpp.getLM():log(_NAME, 'Unwanted TTH loading: ' .. err)
		return
	end
	for line in f:lines() do
		if line ~= "" then -- Filter empty lines
			tth,reason = line:match("(%w+)%s*(.*)")
			if not tth then
				adchpp.getLM():log(_NAME, 'Unwanted TTH loading: Invalid database')
				unwanted = {}
				return
			end
			if reason == "" then
				reason = "No reason given"
			end
			unwanted[tth] = reason
		end
	end
	f:close()
end

load_unwanted()

local function onRES(c, cmd)
	local tth = cmd:getParam("TR",0)
	if unwanted[tth] then
		local path = cmd:getParam("FN",0) or "unknown path"
		local size = cmd:getParam("SI",0) or "unknown"
		local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, c:getSID()+0)
		:addParam('I have an unwanted file: '..tth..' at "'..path..'" size is '..size..' reason is '..unwanted[tth])
		:addParam("PM", adchpp.AdcCommand_fromSID(search_bot:getSID()+0))
		
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
		return false
	end
	return true
end

access.register_handler(adchpp.AdcCommand_CMD_RES, onRES)

checkdb_1 = adchpp.getCM():signalState():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		if bloom and bm:hasBloom(entity) then
			for tth, reason in base.pairs(unwanted) do
				if bm:hasTTH(entity, tth) then
					-- TODO: do actions
					local cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_SCH, adchpp.AdcCommand_TYPE_BROADCAST, search_bot:getSID())
					cmd:addParam("TR",tth)
					entity:send(cmd)
				end
			end
		end
	end
end)

