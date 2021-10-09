timer.Create('BGN_ZombieModeAutoEnableDefense', 1, 0, function()
	local WantedModule = bgNPC:GetModule('wanted')
	local zombies = bgNPC:GetAll()
	local enemies = table.Merge(player.GetAll(), bgNPC:GetAllNPCs())

	for i = 1, #zombies do
		local zombie = zombies[i]

		if zombie and zombie:IsAlive() and zombie:GetData().zombie_mode then
			local npc = zombie:GetNPC()

			for k = 1, #enemies do
				local enemy = enemies[k]

				if zombie:HasEnemy(enemy) or ( not enemy:IsPlayer() and not enemy:IsNPC() ) then
					continue
				end

				local actor = bgNPC:GetActor(enemy)

				if actor then
					if actor:HasTeam(zombie) then
						continue
					end

					if not actor:HasEnemy(npc) then
						actor:AddEnemy(npc)
					end

					if actor:EqualStateGroup('calm') then
						local reaction = actor:GetReactionForDamage()

						if reaction and actor:HasStateGroup(reaction, 'danger') then
							actor:SetState(reaction)
						else
							actor:SetState('fear')
						end
					end
				end

				if enemy:IsNPC() and enemy:Disposition(npc) ~= D_HT then
					enemy:AddEntityRelationship(npc, D_HT, 99)
				end

				zombie:AddEnemy(enemy)
			end

			if not WantedModule:HasWanted(npc) then
				WantedModule:AddWanted(npc)
				WantedModule:GetWanted(npc):SetLevel(3)
			end

			if #zombie.enemies > 0 and not zombie:HasState('zombie') then
				zombie:SetState('zombie')
			end
		end
	end
end)