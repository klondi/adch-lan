-- Collects several hub parameters and outputs a CSV file for statistical purposes
-- Requires: bloom plugin

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

local folder = "FL_DataBase"
local scriptPath = base.scriptPath .. '/'
local statsPath = scriptPath .. folder .. '/'
local statsPath = string.gsub(statsPath, '\\', '/')
local statsPath = string.gsub(statsPath, '//+', '/')
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

lm:log(_NAME, 'Stats loading')

local function getSocketStats()
	local sstats = sm:getStats()
	local stats = {
		queueCalls = sstats.queueCalls - queueCallsLast,
		sendCalls = sstats.sendCalls,
		recvCalls = sstats.recvCalls,
		queueBytes = sstats.queueBytes,
		sendBytes = sstats.sendBytes,
		recvBytes = sstats.recvBytes,
		
	}
	
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
	return stats
end

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

local function processStats()
	local ustats = getUsersTotals() -- TODO: use properly
	
	local shared = ustats.tss

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
	-- TODO add command stats
	local statLine = (
		   localtime .. "," .. uptime .. "," .. ustats.tss .. "," .. ustats.tsf .. ","
		.. ustats.tus .. "," .. ustats.tpu .. "," .. ustats.taw	 .. "," .. ustats.tea .. ","
		.. ustats.tup .. "," .. ustats.tdo .. "," .. ustats.tsl .. "," .. ustats.tfs .. ","
		.. ustats.thu .. "," .. queueCalls .. "," .. sendCalls .. "," .. recvCalls .. ","
		.. queueBytesVar .. "," .. sendBytesVar .. "," .. recvBytesVar .. "," .. sSearch
		.. "," .. sTTHSearch .. "," .. sStoppedSearch .. "\n"
	)

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
	headerLine = 'localtime,uptime,shared,sharedFiles,users,passiveUsers,awayUsers,extendedAwayUsers,uploadSpeed,downloadSpeed,slots,freeSlots,hubs,queueCalls,sendCalls,recvCalls,queueBytes,sendBytes,recvBytes,sSearch,sTTHSearch,sStoppedSearch\n'
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

