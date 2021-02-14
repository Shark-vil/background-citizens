if SERVER then
	hook.Add("SlibEntitySuccessInvoked", 'ActorSyncData', function(success, name, ply, ent)
		if not success or name ~= 'bgn_add_actor_from_client' then return end

		local actor = bgNPC:GetActor(ent)
		if actor == nil or not actor:IsAlive() then return end
		
		actor:SyncData(ply)
	end)
	
	hook.Add("SlibPlayerFirstSpawn", "BGN_PlayerFirstInitSpawnerHook", function(ply)
		for _, actor in ipairs(bgNPC:GetAll()) do
			if actor:IsAlive() then
				local type = actor:GetType()
				local npc = actor:GetNPC()

				snet.EntityInvoke('bgn_add_actor_from_client', ply, npc, type)
			end
		end
	end)
end