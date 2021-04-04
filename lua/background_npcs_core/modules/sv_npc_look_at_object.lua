timer.Create('BGN_Timer_ActorLookAtObject', 0.5, 0, function()
	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if actor:IsAlive() then
			local npc = actor:GetNPC()
			local npc_pos = npc:GetPos()
			local entities = ents.FindInSphere(npc_pos, 1000)

			for k = 1, #entities do
				local ent = entities[k]
				local ent_pos = ent:GetPos()
				if bgNPC:NPCIsViewVector(npc, ent_pos, 70) then
					local diff = (ent_pos - npc_pos):Angle().y - npc:GetAngles().y
					
					if diff < -180 then
						diff = diff + 360
					end

					if diff > 180 then
						diff = diff - 360
					end

					diff = math.abs(diff)
					local dist = npc_pos:Distance(ent_pos)

					hook.Run('BGN_ActorVisibleAtObject', actor, ent, dist, diff)

					if npc:IsNPC() then
						local tr = util.TraceLine({
							start = npc:GetShootPos(),
							endpos = npc:GetShootPos() + npc:GetForward() * 1000,
							filter = function(ent)
								if ent ~= npc then return true end
							end
						})

						if tr.Hit then
							hook.Run('BGN_ActorLookAtObject', actor, ent, dist, diff)
						end
					end
				end
			end
		end
	end
end)