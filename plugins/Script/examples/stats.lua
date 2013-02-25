-- Collects several hub parameters and outputs a CSV file for statistical purposes
-- Requires: bloom plugin, and a sub-folder created on the script folder called 'Stats' with write permissions for adchppd

local base = _G

module('stats')
base.require('luadchpp')
local adchpp = base.luadchpp
base.require('luadchppbloom')
local badchpp = base.luadchppbloom

-- Load required modules
local string = base.require('string')
local io = base.require('io')
local os = base.require('os')

local cm = adchpp.getCM() -- Client manager
local lm = adchpp.getLM() -- Log manager
local sm = adchpp.getSM() -- Socket manager
local bm = badchpp.getBM() -- Bloom manager

local folder = "Stats"
local scriptPath = base.scriptPath .. '/'
local statsPath = scriptPath .. folder .. '/'
local statsPath = string.gsub(statsPath, '\\', '/')
local statsPath = string.gsub(statsPath, '//+', '/')
local file = statsPath .. "stats.txt"
lm:log(_NAME, file)
local processStats, append_file

local freqMilliseconds = 60*1000 -- Save frequency

sendBytesLast = 0
queueBytesLast = 0
recvBytesLast = 0

lm:log(_NAME, 'Stats loading')

local function getTotalShared()
	local entities = adchpp.getCM():getEntities()
	local size = entities:size()
	local tss = 0;
	if size > 0 then
		for i = 0, size - 1 do
			local c = entities[i]:asClient()
			if c then
				local info = adchpp.AdcCommand(c:getINF())
				local ss = base.tonumber(info:getParam("SS", 0)) or base.tonumber(c:getField("SS")) or 0
				tss = tss + ss
			end
		end
	end
	return tss
end

local function processStats()
	local timestamp = os.time()
	local entities = cm:getEntities()
	local size = entities:size()
	local shared = getTotalShared()

	local sstats = sm:getStats()
	local sSearch = bm:getSearches()
	local sTTHSearch = bm:getTTHSearches()
	local sStoppedSearch = bm:getStoppedSearches()

	local queueCalls = sstats.queueCalls
	local queueBytes = sstats.queueBytes
	local sendCalls = sstats.sendCalls 
	local sendBytes = sstats.sendBytes
	local recvCalls = sstats.recvCalls
	local recvBytes = sstats.recvBytes

	local sendBytesVar = sendBytes - sendBytesLast
	local queueBytesVar = queueBytes - queueBytesLast
	local recvBytesVar = recvBytes - recvBytesLast

	sendBytesLast = sendBytes
	queueBytesLast = queueBytes
	recvBytesLast = recvBytes

	local uptime = cm:getUpTime()
	local localtime = os.time()

	local statLine = localtime .. "," .. uptime .. "," .. size .. "," .. shared .. "," .. queueCalls .. "," .. sendCalls .. "," .. recvCalls .. "," .. queueBytesVar .. "," .. sendBytesVar .. "," .. recvBytesVar .. "," .. sSearch .. "," .. sTTHSearch .. "," .. sStoppedSearch .. "\n"

	f, err = io.open(file,'a+')
	if not f then
	  lm:log(_NAME, 'Stats process: ' .. err)
	  return
    end
    f:write(statLine)
    f:close()

	--os.execute("echo '"..statLine.."' >> "..file)

	return statLine
end

local function prepareFile()
	headerLine = 'localtime,uptime,users,shared,queueCalls,sendCalls,recvCalls,queueBytes,sendBytes,recvBytes,sSearch,sTTHSearch,sStoppedSearch\n'
	testFile = io.open(file,'r')
	if not testFile then
		statsFile = io.open(file,'a+')
		statsFile:write(headerLine)
		statsFile:close()
	else 
		testFile:close()
	end
end

lm:log(_NAME, 'Registering stats timer ('.. freqMilliseconds ..'ms)')
sm:addTimedJob(freqMilliseconds,processStats)
prepareFile()
processStats()

