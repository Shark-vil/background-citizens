local WantedModule = bgNPC.Modules.Get('wanted')
-- Spawn menu "Ignore players" (ai_ignoreplayers) works like build mode: actors don't target any player
local cvar_ignore_players = GetConVar('ai_ignoreplayers')

timer.Create('BGN_PlayersHasBuildMode', 1, 0, function()
	for _, v in ipairs(player.GetAll()) do
		if IsValid(v) and v:Alive() then
			v.BGN_HasBuildMode = v.BGN_HasBuildMode or false

			local hasBuildMode = v:GetNWBool('BuildEnabled', false) or cvar_ignore_players:GetBool()

			if not v.BGN_HasBuildMode and hasBuildMode then
				if WantedModule:HasWanted(v) then
					WantedModule:RemoveWanted(v)
				end

				for _, actor in ipairs(bgNPC.Actors.GetAll()) do
					if actor and actor:IsAlive() then
						actor:RemoveEnemy(v)
						actor:RemoveTarget(v)
					end
				end

				v.BGN_HasBuildMode = true
			elseif v.BGN_HasBuildMode and not hasBuildMode then
				v.BGN_HasBuildMode = false
			end
		end
	end
end)