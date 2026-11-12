--[[
	Self-tests for pure logic. Run "bgn_selftest" (server console or admin)
	and "bgn_selftest_cl" (client console). Tests live in tests/ (sh_/sv_/cl_ by realm)
	and are included only when they run. Register tests there with:
		bgNPC.Test.Add('name', function(check) check(1 + 1 == 2, 'math works') end)
--]]
local Test = bgNPC.Test or {}
bgNPC.Test = Test
local tests = Test.list or {}
Test.list = tests
local DIR = 'background_npcs_core/tests/'
function Test.Add(name, func)
  tests[name] = func
end

-- Includes the test files of this realm again, so edited tests run without a map change.
function Test.Load()
  local files = file.Find(DIR .. '*.lua', 'LUA')
  table.sort(files)
  for _, name in ipairs(files) do
    local prefix = name:sub(1, 3)
    if prefix == 'sh_' or prefix == (SERVER and 'sv_' or 'cl_') then
      local ok, err = pcall(include, DIR .. name)
      tests['load ' .. name] = not ok and function() error(err) end or nil
    end
  end
end

function Test.Run()
  Test.Load()
  local passed, failed = 0, 0
  for name, func in SortedPairs(tests) do
    local errors = {}
    local ok, err = pcall(func, function(condition, message) if not condition then errors[#errors + 1] = message or 'check failed' end end)
    if not ok then errors[#errors + 1] = 'error: ' .. tostring(err) end
    if #errors == 0 then
      passed = passed + 1
    else
      failed = failed + 1
      MsgC(Color(255, 80, 80), '[BGN TEST] FAIL ' .. name .. ': ' .. table.concat(errors, '; ') .. '\n')
    end
  end

  MsgC(failed == 0 and Color(80, 255, 80) or Color(255, 80, 80), '[BGN TEST] ' .. passed .. ' passed, ' .. failed .. ' failed (' .. (SERVER and 'server' or 'client') .. ')\n')
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
