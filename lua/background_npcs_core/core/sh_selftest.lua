--[[
	Self-tests for pure logic. Run "bgn_selftest" (server console or admin)
	and "bgn_selftest_cl" (client console). Register tests with:
		bgNPC.Test.Add('name', function(check) check(1 + 1 == 2, 'math works') end)
--]]

local Test = bgNPC.Test or {}
bgNPC.Test = Test

local tests = Test.list or {}
Test.list = tests

function Test.Add(name, func)
	tests[name] = func
end

function Test.Run()
	local passed, failed = 0, 0

	for name, func in SortedPairs(tests) do
		local errors = {}
		local ok, err = pcall(func, function(condition, message)
			if not condition then errors[#errors + 1] = message or 'check failed' end
		end)
		if not ok then errors[#errors + 1] = 'error: ' .. tostring(err) end

		if #errors == 0 then
			passed = passed + 1
		else
			failed = failed + 1
			MsgC(Color(255, 80, 80), '[BGN TEST] FAIL ' .. name .. ': ' .. table.concat(errors, '; ') .. '\n')
		end
	end

	MsgC(failed == 0 and Color(80, 255, 80) or Color(255, 80, 80),
		'[BGN TEST] ' .. passed .. ' passed, ' .. failed .. ' failed (' .. (SERVER and 'server' or 'client') .. ')\n')
	return failed == 0
end

if SERVER then
	concommand.Add('bgn_selftest', function(ply)
		if IsValid(ply) and not ply:IsSuperAdmin() then return end
		Test.Run()
	end)
else
	concommand.Add('bgn_selftest_cl', Test.Run)
end

-- ---------------------------------------------------------------------------
-- Core tests
-- ---------------------------------------------------------------------------

Test.Add('core.class', function(check)
	local A = bgNPC.Class('TestA')
	function A:Init(v) self.v = v end
	function A:Get() return self.v end
	local B = bgNPC.Class('TestB', A)
	function B:Init(v) A.Init(self, v * 2) end

	local b = B(3)
	check(b:Get() == 6, 'inherited method + super init')
	check(bgNPC.IsInstanceOf(b, A) and bgNPC.IsInstanceOf(b, B), 'IsInstanceOf chain')
	check(not bgNPC.IsInstanceOf(A(1), B), 'base is not subclass')
	check(getmetatable(A.New(1)) == A, 'A.New builds A')
end)

Test.Add('core.net.serializer', function(check)
	local Net = bgNPC.Net
	local nested = { 1, 'two', { x = Vector(1, 2.5, -3) }, flag = true, [10] = false, color = Color(1, 2, 3, 4) }
	local values, count = Net.Deserialize(Net.Serialize(nil, 42, -0.125, 'a:b;c{}', nested, Angle(1, 2, 3), nil))

	check(count == 7, 'argument count incl. nils')
	check(values[1] == nil and values[7] == nil, 'nil arguments')
	check(values[2] == 42 and values[3] == -0.125, 'numbers')
	check(values[4] == 'a:b;c{}', 'string with separators')
	check(values[5][2] == 'two' and values[5][3].x == Vector(1, 2.5, -3), 'nested table + vector')
	check(values[5].flag == true and values[5][10] == false, 'bool values and sparse keys')
	check(IsColor(values[5].color) and values[5].color.a == 4, 'color')
	check(values[6] == Angle(1, 2, 3), 'angle')

	local cyclic = {}
	cyclic.self = cyclic
	local ok = pcall(Net.Serialize, cyclic)
	check(ok, 'cyclic table does not overflow')

	local big = string.rep('x', 100000)
	check(Net.Deserialize(Net.Serialize(big))[1] == big, 'large string')
	check(Net.Deserialize(Net.Serialize(1 / 3))[1] == 1 / 3, 'float precision')
end)

Test.Add('core.spatial_grid', function(check)
	local grid = bgNPC.SpatialGrid(1000)
	check(grid:Key(Vector(10, 10, 10)) == grid:Key(Vector(999, 0, 500)), 'same cell')
	check(grid:Key(Vector(-1, 0, 0)) ~= grid:Key(Vector(1, 0, 0)), 'negative side differs')
	check(grid:Key(Vector(0, 1000, 0)) ~= grid:Key(Vector(0, 0, 1000)), 'axes do not collide')
	local cell = grid:GetCell(Vector(-1500, 2500, 10))
	check(Vector(-1500, 2500, 10):WithinAABox(cell.start_pos, cell.end_pos), 'cell bounds contain the point')
	check(grid:GetCell(Vector(-1500, 2500, 10)) == cell and grid:CellsCount() == 1, 'cells are cached')
end)

Test.Add('core.table', function(check)
	local T = bgNPC.Table
	local list = { 1, 2, 3 }
	local shuffled = T.Shuffle(list)
	check(#shuffled == 3 and list[1] == 1 and list[3] == 3, 'shuffle returns a copy')
	check(T.InsertUnique(list, 2) == false and T.InsertUnique(list, 4) and #list == 4, 'insert unique')
	check(T.RemoveValue(list, 2) and not T.HasValue(list, 2), 'remove value')
	check(T.IsArray(list) and not T.IsArray({ a = 1 }) and not T.IsArray({}), 'is array')
	check(#T.Append({ 1 }, { 2, 3 }, { 4 }) == 4, 'append')
end)
