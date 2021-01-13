timer.Create('BGN_Timer_NPCLookAtObject', 0.5, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		if not IsValid(actor:GetNPC()) then continue end

		local npcActor = actor:GetNPC()

		local tr = util.TraceLine({
			start = npcActor:GetShootPos(),
			endpos = npcActor:GetShootPos() + npcActor:EyeAngles():Forward() * 1000,
			filter = function(ent)
				if ent ~= npcActor then return true end
			end
		})

		if tr.Hit and IsValid(tr.Entity) then
			hook.Run('BGN_NPCLookAtObject', actor, tr.Entity)
		end
	end
end)