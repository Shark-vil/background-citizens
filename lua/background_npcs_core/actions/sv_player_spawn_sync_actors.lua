local hook = hook
local bgNPC = bgNPC
local timer = timer
local IsValid = IsValid
--

hook.Add('slib.FirstPlayerSpawn', 'BGN_PlayerFirstInitSpawnerHook', function(ply)
	local delay = 0
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		if actor:IsAlive() then
			local npc_type = actor:GetType()
			local npc = actor:GetNPC()

			npc:AddEntityRelationship(ply, D_NU, 99)

			timer.Simple(delay, function()
				if not IsValid(ply) or not IsValid(npc) then return end
				snet.Request('bgn_add_actor_from_client', npc, npc_type, actor.uid, actor.info).Invoke(ply)
			end)

			delay = delay + 0.1
		end
	end
end)