-- Simple history script that displays the last n history items
-- History is persisted across restarts

local base = _G

module("history")
base.require('luadchpp')
local adchpp = base.luadchpp

base.assert(base['access'], 'access.lua must be loaded and running before history.lua')
local access = base.access

-- Where to read/write history file - set to nil to disable persistent history
local history_file = adchpp.Util_getCfgPath() .. "history.txt"
local history_txt_file = adchpp.Util_getCfgPath() .. "history_txt.txt"
local history_txt_f
local history_sch_file = adchpp.Util_getCfgPath() .. "history_sch.txt"
local history_sch_f
local history_tth_file = adchpp.Util_getCfgPath() .. "history_tth.txt"
local history_tth_f

local os = base.require('os')
local json = base.require('json')
local string = base.require('string')
local aio = base.require('aio')
local io = base.require('io')
local autil = base.require('autil')
local table = base.require('table')
local simplebot = base.require("simplebot")

local cm = adchpp.getCM()
local sm = adchpp.getSM()
local lm = adchpp.getLM()

local pos = 1
local messages_saved = true

local messages = {}

access.add_setting('history_max', {
	help = "number of messages to keep for +history",

	value = 500
})

access.add_setting('history_default', {
	help = "number of messages to display in +history if the user doesn't select anything else",

	value = 50
})

access.add_setting('history_connect', {
	help = "number of messages to display to the users on connect",
	
	value = 10
})

access.add_setting('history_method', {
	help = "strategy used by the +history script to record messages, restart the hub after the change, 1 = use a hidden bot, 0 = direct ADCH++ interface",

	value = 1
})

access.add_setting('history_prefix', {
	help = "prefix to put before each message in +history",

	value = "[%Y-%m-%d %H:%M:%S] "
})

local function log(message)
	lm:log(_NAME, message)
end

local function get_items(c)
	local items = 1
	local user = access.get_user_c(c)
	local from = user.lastofftime
	if from then
		for hist, data in base.pairs(messages) do
			if data.htime > from then
				items = items + 1
			end
		end
	end
	return items
end

local function get_lines(num)
	if num > access.settings.history_max.value then
		num = access.settings.history_max.value + 1
	end

	local s = 1

	if table.getn(messages) > access.settings.history_max.value then
		s = pos - access.settings.history_max.value + 1
	end

	if num < pos then
		s = pos - num + 1
	end

	local e = pos

	local lines = "Displaying the last " .. (e - s) .. " messages"

	while s <= e and messages[s] do
		lines = lines .. "\r\n" .. messages[s].message
		s = s + 1
	end
	
	return lines
end

access.commands.history = {
	alias = { hist = true },

	command = function(c, parameters)
		local items
		if #parameters > 0 then
			items = base.tonumber(parameters) + 1
			if not items then
				return
			end
		else
			if access.get_level(c) > 0 then
				items = get_items(c)
			end
		end
		if not items then
			items = access.settings.history_default.value + 1
		end
		
		autil.reply(c, get_lines(items))
	end,

	help = "[lines] - display main chat messages logged by the hub (no lines=default / since last logoff)",

	user_command = {
		name = "Chat history",
		params = { autil.ucmd_line("Number of msg's to display (empty=default / since last logoff)") }
		}
}

local function save_messages()
	if not history_file then
		return
	end

	local s = 1
	local e = pos
	if table.getn(messages) >= access.settings.history_max.value then
		s = pos - access.settings.history_max.value
		e = table.getn(messages)
	end

	local list = {}
	while s <= e and messages[s] do
		table.insert(list, messages[s])
		s = s + 1
	end
	messages = list
	pos = table.getn(messages) + 1

	local err = aio.save_file(history_file, json.encode(list))
	if err then
		log('History not saved: ' .. err)
	else
		messages_saved = true
	end
end

local function load_messages()
	if not history_file then
		return
	end

	local ok, list, err = aio.load_file(history_file, aio.json_loader)

	if err then
		log('History loading: ' .. err)
	end
	if not ok then
		return
	end

	for k, v in base.pairs(list) do
		messages[k] = v
		pos = pos + 1
	end
end

local function maybe_save_messages()
	if not messages_saved then
		save_messages()
	end
end

local function parse(cmd)
	if cmd:getCommand() ~= adchpp.AdcCommand_CMD_MSG or cmd:getType() ~= adchpp.AdcCommand_TYPE_BROADCAST then
		return
	end

	local from = cm:getEntity(cmd:getFrom())
	if not from then
		return
	end

	local nick = from:getField("NI")
	if #nick < 1 then
		return
	end

	local now = os.date(access.settings.history_prefix.value)
	local message
	
	if cmd:getParam("ME", 1) == "1" then
		message = now .. '* ' .. nick .. ' ' .. cmd:getParam(0)
	else
		message = now .. '<' .. nick .. '> ' .. cmd:getParam(0)
	end

	messages[pos] = { message = message, htime = os.time() }
	pos = pos + 1

	local fmessage = message
	fmessage = string.gsub(fmessage,'\\','\\\\')
	fmessage = string.gsub(fmessage,'\n','\\n')
	fmessage = fmessage.."\n"
	history_txt_f:write(fmessage)
	messages_saved = false
end

history_1 = cm:signalState():connect(function(entity)
	if access.settings.history_connect.value > 0 and entity:getState() == adchpp.Entity_STATE_NORMAL then
		autil.reply(entity, get_lines(access.settings.history_connect.value + 1))
	end
end)

load_messages()

if access.settings.history_method.value == 0 then
	history_1 = cm:signalReceive():connect(function(entity, cmd, ok)
		if not ok then
			return ok
		end

		parse(cmd)

		return true
	end)

else
	local callback = function(bot, buffer) parse(adchpp.AdcCommand(buffer)) end
	hidden_bot = simplebot.makeBot (_NAME, nil, callback, {adchpp.Entity_FLAG_HIDDEN},
			_NAME .. '-hidden_bot', 'Hidden bot used by the ' .. _NAME .. ' script').bot
end

save_messages_timer = sm:addTimedJob(900000, maybe_save_messages)
autil.on_unloading(_NAME, save_messages_timer)

autil.on_unloading(_NAME, maybe_save_messages)

history_txt_f = io.open(history_txt_file,"a")
history_sch_f = io.open(history_sch_file,"a")
history_tth_f = io.open(history_tth_file,"a")
autil.on_unloading(_NAME, function ()
	history_txt_f:close()
	history_sch_f:close()
	history_tth_f:close()
end)
flush_messages_timer = sm:addTimedJob(1000, function ()
	history_txt_f:flush()
	history_sch_f:flush()
	history_tth_f:flush()
end)

history_2 = cm:signalReceive():connect(function(entity, cmd, ok)
	if not ok then
		return ok
	end

	if cmd:getCommand() ~= adchpp.AdcCommand_CMD_SCH or cmd:getType() ~= adchpp.AdcCommand_TYPE_BROADCAST then
		return true
	end

	local now = os.date(access.settings.history_prefix.value)
	
	
	if cmd:getParam("TR", 1) == "" then
		local params = cmd:getParameters()
		local paramsize =  params:size()
		local message = now
		for i = 0, paramsize - 1 do
			local npar = params[i]
			if string.sub(npar,1,2) ~= "TO" then
				npar = string.gsub(npar,'\\','\\\\')
				npar = string.gsub(npar,'\n','\\n')
				npar = string.gsub(npar,' ','\\s')
				message = message .. ' ' .. npar
			end
		end
		history_sch_f:write(message..'\n')
	else
		local message = now .. ' ' .. cmd:getParam("TR", 1) .. '\n'
		history_tth_f:write(message)
	end

	return true
end)

