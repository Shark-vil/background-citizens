--

hook.Add('BGN_PlayerReady', 'BGN_PlayerFirstInitSpawnerHook', function(ply)
	local delay = 0
	local actors = bgNPC.Actors.GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		if actor:IsAlive() then
			local npc_type = actor:GetType()
			local npc = actor:GetNPC()

			npc:AddEntityRelationship(ply, D_NU, 99)

			timer.Simple(delay, function()
				if not IsValid(ply) or not IsValid(npc) then return end
				bgNPC.Net.Send('bgn_add_actor_from_client', ply, npc, npc_type, actor.uid, actor.info)
			end)

			delay = delay + 0.1
		end
	end
end)