if SERVER then
	hook.Add("Slib_EntitySuccessInvoked", 'BGM_StartActorSyncData', function(name, ply, ent)
		if name ~= 'bgn_add_actor_from_client' then return end

		local actor = bgNPC:GetActor(ent)
		if not actor or not actor:IsAlive() then return end

		actor:SyncData(ply)
	end)

	hook.Add("SlibPlayerFirstSpawn", "BGN_PlayerFirstInitSpawnerHook", function(ply)
		local delay = 0
		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]
			if actor:IsAlive() then
				local type = actor:GetType()
				local npc = actor:GetNPC()

				npc:AddEntityRelationship(ply, D_NU, 99)

				timer.Simple(delay, function()
					if not IsValid(ply) or not IsValid(npc) then return end
					print('Add - ', actor.uid)
					snet.Create('bgn_add_actor_from_client', npc, type, actor.uid).Invoke(ply)
				end)

				delay = delay + 0.1
			end
		end
	end)
end