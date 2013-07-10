-- Collects several hub parameters and outputs a CSV file for statistical purposes
-- Requires: bloom plugin

local base = _G

module('stats')
base.require('luadchpp')
local adchpp = base.luadchpp
bloom = false
local badchpp
local bm

if bloom then
	base.require('luadchppbloom')
	badchpp = base.luadchppbloom
	bm = badchpp.getBM() -- Bloom manager
end

-- Load required modules
local string = base.require('string')
local io = base.require('io')
local os = base.require('os')

local cm = adchpp.getCM() -- Client manager
local lm = adchpp.getLM() -- Log manager
local sm = adchpp.getSM() -- Socket manager

local folder = "FL_DataBase"
local scriptPath = base.scriptPath .. '/'
local statsPath = scriptPath .. folder .. '/'
statsPath = string.gsub(statsPath, '\\', '/')
statsPath = string.gsub(statsPath, '//+', '/')
local file = statsPath .. "stats.txt"
lm:log(_NAME, file)
local processStats, append_file

local freqMilliseconds = 60*1000 -- Save frequency

local sendBytesLast = 0
local queueBytesLast = 0
local recvBytesLast = 0
local sendCallsLast = 0
local queueCallsLast = 0
local recvCallsLast = 0


local cmdStats 
local function resetcmdstats ()
	cmdStats = {
		sch = 0, -- Searchs
		tth = 0, -- TTH searchs
		asch = 0, -- Active searchs
		psch = 0, -- Passive searchs
		msgs = 0, -- Chat messages
		pms = 0, -- Private messages
		bpms = 0, -- private messages to/from bots
		bsnd = 0, -- bloom filters received
		inf = 0, -- User information updates (without the initial)
		res = 0, -- Passive search results received
		ctm = 0, -- Connection requests
		rcm = 0, -- Passive connection requests
		nat = 0,  -- Passive passive connection requests: active connection requests = (ctm-(rcm-nat))
		conn = 0 -- Connection requests
	}
end
resetcmdstats ()

lm:log(_NAME, 'Stats loading')

--These two are not safe you are expected to initialize first
local function sumstat(table, stat, count)
	table[stat] = table[stat] + (base.tonumber(count) or 0)
end

local function countsubt(table, stat, key)
	table[stat][key] = (base.tonumber(table[stat][key]) or 0) + 1
end

-- Try to fetch some interesting grand totals, namely shared files, 
local function getUsersTotals()
	local entities = adchpp.getCM():getEntities()
	local size = entities:size()

	local stats = {
		tss = 0,  --Total share size SS
		tsf = 0,  --Total shared files SF
		tus = 0,  --Total users (entity count)
		tpu = 0,  --Total passive users (count with U4) -- TODO: check I4/I6
		taw = 0,  --Total away users AW1
		tea = 0,  --Total extended away users AW2
		tup = 0,  --Total upload speed US
		tdo = 0,  --Total download speed DS
		tsl = 0,  --Total slot count SL
		tfs = 0,  --Total free slot count (if not available all busy is assumed) FS
		thu = 0,  --Total hubs (Discarding current one) HN + HR + HO - 1
		tap = {}, --Total by application (counts users by client (AP or filtered VE)) 
		tve = {}, --Total by version (counts users by client if AP is (AP VE) otherwise is VE
		tsu = {}, --Total by features (counts users by the features announced) on SU
		tfe = {}, --Total by features (counts users by the features announced) on SUP command
		trf = {}  --Total by referer RF
	}
	for i = 0, size - 1 do
		local c = entities[i]:asClient()
		if c then --dynamic cast prevents bots and hub
			local inf = adchpp.AdcCommand(c:getINF())
			local sup = adchpp.AdcCommand(c:getSUP())
			sumstat(stats,"tss",inf:getParam("SS", 0))
			sumstat(stats,"tsf",inf:getParam("SF", 0))
			sumstat(stats,"tus",1)
			sumstat(stats,"tpu",(inf:getParam("U4", 0) or inf:getParam("U6", 0)) and 0 or 1)
			local aw =base.tonumber(inf:getParam("AW", 0))
			sumstat(stats,"taw",(aw == 1 or aw == 2) and 1 or 0)
			sumstat(stats,"tea",(aw == 2) and 1 or 0)			
			sumstat(stats,"tup",inf:getParam("US", 0))
			sumstat(stats,"tdo",inf:getParam("DO", 0))
			sumstat(stats,"tsl",inf:getParam("SL", 0))
			sumstat(stats,"tfs",inf:getParam("FS", 0))
			sumstat(stats,"thu",inf:getParam("HN", 0))
			sumstat(stats,"thu",inf:getParam("HR", 0))
			sumstat(stats,"thu",inf:getParam("HO", 0))
			sumstat(stats,"thu",-1)
			local ap, ve
			if inf:hasParam("AP", 0) then
				ap = inf:getParam("AP", 0)
				ve = ap..' '..inf:getParam("VE", 0)
			else
				ve = inf:getParam("VE", 0)
				ap , _ = string.gsub(ve," *[0-9.]*$","")
			end
			countsubt(stats,"tap",ap)
			countsubt(stats,"tve",ve)
			for v in string.gmatch(inf:getParam("SU", 0),"[^,]+") do
				countsubt(stats,"tsu",v)
			end
			local params = sup:getParameters()
			local paramsize =  params:size()
			for i = 0, paramsize - 1 do
				countsubt(stats,"tfe",params[i])
			end
			countsubt(stats,"trf",inf:getParam("RF", 0))
		end
	end
	return stats
end

local function dumpSubt(fname, keyname, valuename, table)
	f, err = io.open(fname,'w')
	if not f then
		lm:log(_NAME, 'Subtable '..fname..' process: ' .. err)
		return
	end
	f:write(keyname..","..valuename.."\n")
	for k,v in base.pairs(table) do
		f:write(k..","..v.."\n")
	end
	f:close()
end

local function processStats()
	local ustats = getUsersTotals()
	
	local shared = ustats.tss

	local sstats = sm:getStats()
	local sSearch = -1
	local sTTHSearch = -1
	local sStoppedSearch = -1
	if bloom then
		local sSearch = bm:getSearches()
		local sTTHSearch = bm:getTTHSearches()
		local sStoppedSearch = bm:getStoppedSearches()
	end

	local queueCalls = sstats.queueCalls
	local queueBytes = sstats.queueBytes
	local sendCalls = sstats.sendCalls 
	local sendBytes = sstats.sendBytes
	local recvCalls = sstats.recvCalls
	local recvBytes = sstats.recvBytes

	local sendBytesVar = sendBytes - sendBytesLast
	local queueBytesVar = queueBytes - queueBytesLast
	local recvBytesVar = recvBytes - recvBytesLast
	local sendCallsVar = sendCalls - sendCallsLast
	local queueCallsVar = queueCalls - queueCallsLast
	local recvCallsVar = recvCalls - recvCallsLast

	sendBytesLast = sendBytes
	queueBytesLast = queueBytes
	recvBytesLast = recvBytes
	sendCallsLast = sendCalls
	queueCallsLast = queueCalls
	recvCallsLast = recvCalls

	local uptime = cm:getUpTime()
	local localtime = os.time()
	-- TODO add command stats
	local statLine = string.format("%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f,%.f\n"
		   localtime .. "," .. uptime .. "," .. ustats.tss .. "," .. ustats.tsf .. ","
		.. ustats.tus .. "," .. ustats.tpu .. "," .. ustats.taw	 .. "," .. ustats.tea .. ","
		.. ustats.tup .. "," .. ustats.tdo .. "," .. ustats.tsl .. "," .. ustats.tfs .. ","
		.. ustats.thu .. "," .. queueCallsVar .. "," .. sendCallsVar .. "," .. recvCallsVar .. ","
		.. queueBytesVar .. "," .. sendBytesVar .. "," .. recvBytesVar .. "," .. sSearch
		.. "," .. sTTHSearch .. "," .. sStoppedSearch .. "," .. cmdStats.sch .. "," .. cmdStats.tth
		.. "," .. cmdStats.asch .. "," .. cmdStats.psch .. "," .. cmdStats.msgs
		.. "," .. cmdStats.pms .. "," .. cmdStats.bpms .. "," .. cmdStats.bsnd
		.. "," .. cmdStats.inf .. "," .. cmdStats.res .. "," .. cmdStats.ctm - (cmdStats.rcm - cmdStats.nat)
		.. "," .. cmdStats.rcm .. "," .. cmdStats.nat .. "," .. cmdStats.conn .. "\n"
	)
	resetcmdstats ()

	f, err = io.open(file,'a+')
	if not f then
		lm:log(_NAME, 'Stats process: ' .. err)
		return
	end
	f:write(statLine)
	f:close()
	--Dump the stats subtables
	dumpSubt(statsPath .. localtime .. "_tap.txt", "aplication", "usercount", ustats.tap)
	dumpSubt(statsPath .. localtime .. "_tve.txt", "aplication", "usercount", ustats.tve)
	dumpSubt(statsPath .. localtime .. "_tsu.txt", "aplication", "usercount", ustats.tsu)
	dumpSubt(statsPath .. localtime .. "_tfe.txt", "aplication", "usercount", ustats.tfe)
	dumpSubt(statsPath .. localtime .. "_trf.txt", "aplication", "usercount", ustats.trf)

	return statLine
end

local function prepareFile()
	
	headerLine = 'localtime,uptime,shared,sharedFiles,users,passiveUsers,awayUsers,extendedAwayUsers,uploadSpeed,downloadSpeed,slots,freeSlots,hubs,queueCalls,sendCalls,recvCalls,queueBytes,sendBytes,recvBytes,sSearch,sTTHSearch,sStoppedSearch,searchs,tthSearchs,activeSearchs,passiveSearchs,chatMessages,privateMessages,botPrivateMessages,bloomReceived,infoUpdates,passiveResults,activeConnectionRequests,passiveConnectionRequests,passiveNatRequests,incomingConnections\n'
	testFile = io.open(file,'r')
	if not testFile then
		statsFile = io.open(file,'a+')
		statsFile:write(headerLine)
		statsFile:close()
	else 
		testFile:close()
	end
end

function receiveparse (cmd) 
	if cmd:getCommand() == adchpp.AdcCommand_CMD_SCH and cmd:getType() == adchpp.AdcCommand_TYPE_BROADCAST then
		local from = cm:getEntity(cmd:getFrom())
		if not from then
			return
		end

		sumstat(cmdStats, "sch", 1)
		if (from:getField("U4") == "") and  (from:getField("U6") == "") then
			sumstat(cmdStats, "psch", 1)
		else
			sumstat(cmdStats, "asch", 1)
		end
		if cmd:getParam("TR", 0) ~= "" then
			sumstat(cmdStats, "tth", 1)
		end
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_MSG then
		if cmd:getParam("PM", 1) == "" then
			if cmd:getType() ~= adchpp.AdcCommand_TYPE_BROADCAST then
				return
			end
			sumstat(cmdStats, "msgs", 1)
		else
			if cmd:getType() ~= adchpp.AdcCommand_TYPE_DIRECT then
				return
			end
			local from = cm:getEntity(cmd:getFrom())
			if not from then
				return
			end
			local to = cm:getEntity(cmd:getto())
			if not to then
				return
			end
			local pm = cm:getEntity(base.tonumber(cmd:getParam("PM", 0)) or 0)
			if not pm then
				return
			end
			if from:asBot() or to:asBot() or pm:asBot() then
				sumstat(cmdStats, "pms", 1)
			else
				sumstat(cmdStats, "bpms", 1)
			end
		end

	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_SND and cmd:getType() == adchpp.AdcCommand_TYPE_HUB then
		sumstat(cmdStats, "bsnd", 1)
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_INF and cmd:getType() == adchpp.AdcCommand_TYPE_BROADCAST then
		local from = cm:getEntity(cmd:getFrom())
		if not from then
			return
		end
		if from:getState() == adchpp.Entity_STATE_NORMAL then
			sumstat(cmdStats, "inf", 1)
		end
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_RES and cmd:getType() == adchpp.AdcCommand_TYPE_DIRECT then
		sumstat(cmdStats, "res", 1)
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_CTM and cmd:getType() == adchpp.AdcCommand_TYPE_DIRECT then
		sumstat(cmdStats, "ctm", 1)
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_RCM and cmd:getType() == adchpp.AdcCommand_TYPE_DIRECT then
		sumstat(cmdStats, "rcm", 1)
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_NAT and cmd:getType() == adchpp.AdcCommand_TYPE_DIRECT then
		sumstat(cmdStats, "nat", 1)
	end
end

stats_1 = cm:signalConnected():connect(function(entity)
	sumstat(cmdStats, "conn", 1)
end)

stats_2 = cm:signalReceive():connect(function(entity, cmd, ok)
	if not ok then
		return ok
	end

	receiveparse (cmd) 

	return true
end)

lm:log(_NAME, 'Registering stats timer ('.. freqMilliseconds ..'ms)')
sm:addTimedJob(freqMilliseconds,processStats)
prepareFile()
processStats()
