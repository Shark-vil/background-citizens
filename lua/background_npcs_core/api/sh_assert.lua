--[[
	Argument validation helpers.

	Every check is a plain function call that formats its error message only
	on failure, so they are cheap enough to use on hot paths.

	Type specs are strings such as 'string', 'number|nil' or 'entity|actor'.
	Supported types: any, nil, string, number, boolean, table, function,
	entity, vector, angle, actor, node.

	Example:
		local Assert = bgNPC.Assert
		function bgNPC:Foo(actor, radius)
			Assert.Arg(1, actor, 'actor', 'bgNPC:Foo')
			Assert.Arg(2, radius, 'number|nil', 'bgNPC:Foo')
		end
--]]

--

local Assert = {}

local CHECKERS = {
	['any'] = function() return true end,
	['nil'] = function(v) return v == nil end,
	['string'] = isstring,
	['number'] = isnumber,
	['boolean'] = isbool,
	['table'] = istable,
	['function'] = isfunction,
	['entity'] = isentity,
	['vector'] = isvector,
	['angle'] = isangle,
	['actor'] = function(v) return istable(v) and v.isBgnClass == true end,
	['node'] = function(v) return istable(v) and v.isNode == true end,
}

-- Parsed type specs, so 'string|nil' is split only once.
local spec_cache = {}

local function ParseSpec(spec)
	local parsed = spec_cache[spec]
	if parsed then return parsed end

	parsed = {}
	for _, type_name in ipairs(string.Explode('|', spec)) do
		local checker = CHECKERS[type_name]
		if not checker then
			error(string.format('bgNPC.Assert: unknown type "%s" in spec "%s"', type_name, spec), 3)
		end
		parsed[#parsed + 1] = checker
	end

	spec_cache[spec] = parsed
	return parsed
end

local function Matches(value, spec)
	local checkers = ParseSpec(spec)
	for i = 1, #checkers do
		if checkers[i](value) then return true end
	end
	return false
end

local function DescribeType(value)
	if istable(value) then
		if value.isBgnClass then return 'actor' end
		if value.isNode then return 'node' end
	end
	return type(value)
end

-- Checks a function argument against a type spec.
-- @param index number argument position, used in the error message
-- @param value any argument value
-- @param spec string type spec, e.g. 'string|nil'
-- @param func_name string|nil name of the checked function
function Assert.Arg(index, value, spec, func_name)
	if Matches(value, spec) then return value end

	error(string.format('bad argument #%d to \'%s\' (%s expected, got %s)',
		index, func_name or '?', spec, DescribeType(value)), 3)
end

-- Checks a named field (for example in a settings table) against a type spec.
function Assert.Field(owner_name, field_name, value, spec)
	if Matches(value, spec) then return value end

	error(string.format('bad field \'%s.%s\' (%s expected, got %s)',
		owner_name, field_name, spec, DescribeType(value)), 3)
end

-- Generic condition check. Extra arguments are only formatted on failure.
function Assert.True(condition, message, ...)
	if condition then return condition end

	if select('#', ...) ~= 0 then
		message = string.format(message, ...)
	end

	error(tostring(message or 'assertion failed'), 3)
end

-- Checks that a value is a non-empty string.
function Assert.NonEmptyString(index, value, func_name)
	if isstring(value) and #value ~= 0 then return value end

	error(string.format('bad argument #%d to \'%s\' (non-empty string expected, got %s)',
		index, func_name or '?', isstring(value) and 'empty string' or DescribeType(value)), 3)
end

-- Returns true if the value matches the spec, without raising an error.
function Assert.Is(value, spec)
	return Matches(value, spec)
end

-- Registers a custom type for use in specs.
function Assert.RegisterType(type_name, checker)
	if not isstring(type_name) or not isfunction(checker) then
		error('bgNPC.Assert.RegisterType: expected (string, function)', 2)
	end

	CHECKERS[type_name] = checker
	spec_cache = {}
end

bgNPC.Assert = Assert
