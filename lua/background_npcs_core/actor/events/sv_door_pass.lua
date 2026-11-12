--[[
	Doorways: actors close to a door stop colliding with each other (COLLISION_GROUP_NPC_SCRIPTED ignores itself),
	so actors going through it the opposite ways pass instead of jamming the doorway. Players and props still
	collide with them. Only the usual groups are switched: sitting or riding actors keep theirs.
--]]
local RADIUS = 90
local PERIOD = 0.3
local SWITCHABLE = {
  [COLLISION_GROUP_NONE] = true,
  [COLLISION_GROUP_NPC] = true
}

local function NearDoor(pos)
  for _, ent in ipairs(ents.FindInSphere(pos, RADIUS)) do
    if bgNPC.Util.IsDoor(ent) then return true end
  end
  return false
end

bgNPC.Tasks.Add('BGN_DoorPass', function(yield, wait)
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    local npc = actor:GetNPC()
    if IsValid(npc) and actor:IsAlive() then
      local group = npc:GetCollisionGroup()
      if not actor.door_pass_group then
        if SWITCHABLE[group] and NearDoor(npc:GetPos()) then
          actor.door_pass_group = group
          npc:SetCollisionGroup(COLLISION_GROUP_NPC_SCRIPTED)
        end
      elseif group ~= COLLISION_GROUP_NPC_SCRIPTED then
        actor.door_pass_group = nil -- something else (a chair, a car) took over the group
      elseif not NearDoor(npc:GetPos()) then
        npc:SetCollisionGroup(actor.door_pass_group)
        actor.door_pass_group = nil
      end
    end

    yield()
  end

  wait(PERIOD)
end)
