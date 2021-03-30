timer.Create('BGN_Timer_ActorLookAtObject', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		if actor:IsAlive() then
			local npc = actor:GetNPC()
			local npc_pos = npc:GetPos()

			for _, ent in ipairs(ents.FindInSphere(npc_pos, 1000)) do
				local ent_pos = ent:GetPos()
				if bgNPC:NPCIsViewVector(npc, ent_pos, 70) then
					hook.Run('BGN_ActorLookAtObject', actor, ent, npc_pos:Distance(ent_pos))
				end
			end
		end
	end
end)