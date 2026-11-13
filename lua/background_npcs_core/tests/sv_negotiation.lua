-- Engine-free world: only the shield rule, the timeout and the block are checked.
local function World()
  local w = setmetatable({now = 100, said = {}}, {__index = _G})
  local actors, tick = {}, nil
  w.CurTime = function() return w.now end
  w.IsValid = function(ent) return istable(ent) and ent.valid == true end
  w.hook = {Add = function() end}
  w.timer = {Create = function(_, _, _, fn) tick = fn end}
  w.bit = {band = function() return 0 end}
  w.bgNPC = {Actors = {GetAll = function() return actors end, GetInRadius = function() return actors end},
    Combat = {ResolveVehicleAttacker = function(ent) return ent end}}
  local function Actor(x, police, state)
    local a = {valid = true, pos = Vector(x, 0, 0), police = police, state = state, enemy = NULL}
    function a:GetPos() return self.pos end
    function a:IsAlive() return true end
    function a:HasTeam() return self.police end
    function a:HasState(list) return table.HasValue(list, self.state) end
    function a:GetEnemy() return self.enemy end
    function a:GetNPC() return NULL end
    function a:Voice(id) w.said[#w.said + 1] = id end
    actors[#actors + 1] = a
    return a
  end
  w.Actor = Actor
  w.Tick = function() tick() end
  setfenv(assert(CompileFile('background_npcs_core/systems/sv_negotiation.lua')), w)()
  return w
end

bgNPC.Test.Add('negotiation.shield_and_timeout', function(check)
  local w = World()
  local target = {valid = true, pos = Vector(500, 0, 0)}
  function target:GetPos() return self.pos end
  function target:IsPlayer() return true end
  function target:Alive() return true end
  local officer, hostage = w.Actor(0, true, 'defense'), w.Actor(400, false, 'fear')
  officer.enemy = target
  check(w.bgNPC.Negotiation.Hostage(officer, target) == hostage, 'a frightened actor in front of the target is a hostage')
  hostage.pos = Vector(600, 0, 0)
  check(w.bgNPC.Negotiation.Hostage(officer, target) == nil, 'a hostage behind the target does not stop the officer')
  hostage.pos = Vector(400, 0, 0)
  w.Tick()
  check(officer.hold_fire and w.said[1] == 'police_negotiate_offer', 'the officer holds fire and offers to talk')
  w.now = 116
  w.Tick()
  check(w.said[2] == 'police_negotiate_warning', 'a last warning comes before the deadline')
  w.now = 121
  w.Tick()
  check(w.said[3] == 'police_negotiate_failed', 'the talks fail at the deadline')
  w.Tick()
  check(not officer.hold_fire, 'a failed negotiation releases the officers')
  w.now = 130
  w.Tick()
  check(not officer.hold_fire and #w.said == 3, 'a failed negotiation is not offered again before the block ends')
  w.now = 250
  w.Tick()
  check(officer.hold_fire, 'the block ends by itself')
end)
