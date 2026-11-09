--[[
	Shared enemies: every "bgn_enemy_share_period" seconds an actor that fights someone passes the enemy on to the
	teammates around it that see it and do not know the enemy yet. Without it an officer shoots at a player nobody
	else reacts to (the wanted level is not there yet), and the others keep walking as if nothing happens.
--]]

local RADIUS = 1000
local cvar_period = GetConVar('bgn_enemy_share_period')

-- A scared actor does not spread its panic: the fear would run through the whole crowd.
local function CanShare(actor)
	return actor:IsAlive() and not actor:HasNoEnemies() and not actor:HasState('fear') and not actor:InVehicle()
end

local function Share(source)
	local npc = source:GetNPC()
	local enemies = {}
	for i = 1, source.enemies_count do
		local enemy = source.enemies[i]
		-- only a real fight is worth passing on (an officer's enemy always is)
		if IsValid(enemy) and enemy:Health() > 0 and (source:HasTeam('police') or bgNPC.Combat.IsFighting(enemy)) then
			enemies[#enemies + 1] = enemy
		end
	end
	if #enemies == 0 then return end

	for _, other in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), RADIUS)) do
		if other ~= source and other:IsAlive() and not other:InVehicle() and other:HasTeam(source) then
			local missing
			for _, enemy in ipairs(enemies) do
				if not other:HasEnemy(enemy) and not other:HasTeam(enemy) then
					missing = missing or {}
					missing[#missing + 1] = enemy
				end
			end

			-- the trace only for those who have something to learn
			if missing and bgNPC.Vision.HasLineOfSight(other:GetNPC(), npc) then
				for _, enemy in ipairs(missing) do
					if other:EqualStateGroup('calm') then
						other:RemoveAllTargets()
						other:SetState(other:GetReactionForProtect(enemy))
					end
					other:AddEnemy(enemy)
				end
			end
		end
	end
end

timer.Create('BGN_EnemySharing', 1, 0, function()
	if bgNPC.Modes.IsPeaceful() then return end

	local period = cvar_period:GetFloat()
	if period <= 0 or (bgNPC.enemy_share_next or 0) > CurTime() then return end
	bgNPC.enemy_share_next = CurTime() + period

	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		if CanShare(actor) then Share(actor) end
	end
end)
