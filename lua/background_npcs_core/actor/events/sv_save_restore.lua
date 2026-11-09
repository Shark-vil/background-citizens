-- GMod saves use the duplicator: store actor identity, never the cyclic runtime body/brain/scene tables.
local Actors = bgNPC.Actors

local function EnableSaving(actor)
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	local original = npc.OnEntityCopyTableFinish
	if original and original == npc.bgn_copy_handler then return end
	npc.OnEntityCopyTableFinish = function(ent, data)
		if original then original(ent, data) end
		data.BGN_ACTOR_OBJECT = nil
		data.isBgnActor = nil
		data.EntityMods = table.Copy(data.EntityMods or {})
		local current = Actors.Get(ent)
		if current then
			data.EntityMods.bgn_actor = { type = current:GetType(), name = current:GetName(), gender = current:GetGender() }
		end
	end
	npc.bgn_copy_handler = npc.OnEntityCopyTableFinish
end

duplicator.RegisterEntityModifier('bgn_actor', function(_, npc, data)
	if not IsValid(npc) or not istable(data) or not isstring(data.type) then return end
	if not bgNPC.Config.GetActor(data.type) then return end
	local actor = Actors.Get(npc) or bgNPC.Actor.Create(npc, data.type)
	if not actor then return end
	if isstring(data.name) then actor:SetName(data.name) end
	if isstring(data.gender) then actor:SetGender(data.gender) end
	-- Actor initialization sends this identity to clients on the next tick.
end)

hook.Add('BGN_InitActor', 'BGN_SaveRestore', EnableSaving)
for _, actor in ipairs(Actors.GetAll()) do EnableSaving(actor) end
