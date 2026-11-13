local _error_color = Color(255, 115, 115, 200)
local _warning_color = Color(250, 205, 81, 200)
local _log_color = Color(219, 241, 245, 200)
local _debug_traceback = debug.traceback
local _ErrorNoHalt = ErrorNoHalt
local _table_insert = table.insert
local _string_Explode = string.Explode
local _tostring = tostring
local _MsgC = MsgC
local error_stack_list = {}

local function _ConsoleMessage(prefix, message_type, ...)
	local tags = _string_Explode('.', prefix)
	local stylized_prefix = ''
	local message_args = { ... }
	local message = ''

	if #tags == 0 or tags[1] == '.' then
		stylized_prefix = '[' .. prefix .. ']'
	else
		for i = 1, #tags do
			stylized_prefix = stylized_prefix .. '[' .. tags[i] .. ']'
		end
	end

	for i = 1, #message_args do
		message = message .. _tostring(message_args[i])
	end

	local print_message = stylized_prefix .. ' ' .. _debug_traceback(message, 3) .. '\n'

	if message_type == 'error' then
		_MsgC(_error_color, print_message)
		_table_insert(error_stack_list, print_message)
	elseif message_type == 'warning' then
		_MsgC(_warning_color, print_message)
	else
		_MsgC(_log_color, stylized_prefix .. ' ' .. message .. '\n')
	end
end

function slib.Log(...)
	_ConsoleMessage('LOG', 'log', ...)
end

function slib.Warning(...)
	_ConsoleMessage('WARNING', 'warning', ...)
end

function slib.Error(...)
	_ConsoleMessage('ERROR', 'error', ...)
end

function slib.DebugLog(...)
	if not slib.CvarCheckValue('slib_debug', 1) then return end
	_ConsoleMessage('DEBUG LOG', 'log', ...)
end

function slib.DebugWarning(...)
	if not slib.CvarCheckValue('slib_debug', 1) then return end
	_ConsoleMessage('DEBUG WARNING', 'warning', ...)
end

function slib.DebugError(...)
	if not slib.CvarCheckValue('slib_debug', 1) then return end
	_ConsoleMessage('DEBUG ERROR', 'error', ...)
end

-- Обработка ошибок вынесена в таймер
-- чтобы избежать ебучего стека вызова
timer.Create('CheckPrintNewError', .01, 0, function()
	local count = #error_stack_list
	if count == 0 then return end
	for index = 1, count do
		_ErrorNoHalt(error_stack_list[index] .. '\nThe text below is not an error:')
	end
	error_stack_list = {}
end)