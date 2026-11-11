--[[
	Shared enemies: every "bgn_enemy_share_period" seconds an actor that fights someone passes the enemy on to the
	teammates around it that see it and do not know the enemy yet. Without it an officer shoots at a player nobody
	else reacts to (the wanted level is not there yet), and the others keep walking as if nothing happens.
--]]

local RADIUS = 1000
local cvar_period = GetConVar('bgn_enemy_share_period')

-- A scared actor does not spread its panic: the fear would run through the whole crowd.
local function CanShare(actor)
	return actor:IsAlive() and not actor:HasNoEnemies() and not actor:HasState('fear')
		and (actor.data.gang or not actor:InVehicle())
end

local function Share(source)
	local npc = source:GetNPC()
	local gang = source.data.gang
	local enemies = {}
	for i = 1, source.enemies_count do
		local enemy = source.enemies[i]
		-- Police and gangs share known threats even before the enemy attacks again.
		if IsValid(enemy) and enemy:Health() > 0 and (gang or source:HasTeam('police') or bgNPC.Combat.IsFighting(enemy)) then
			enemies[#enemies + 1] = enemy
		end
	end
	if #enemies == 0 then return end

	local nearby = gang and bgNPC.Actors.GetAll() or bgNPC.Actors.GetInRadius(npc:GetPos(), RADIUS)
	for _, other in ipairs(nearby) do
		-- an officer in a car takes the enemy too: it steps out or fires from the car (modules/dv/sv_move_to_target.lua)
		if other ~= source and other:IsAlive() and (gang or not other:InVehicle() or other:HasTeam('police')) and other:HasTeam(source) then
			local missing
			for _, enemy in ipairs(enemies) do
				if (not other:HasEnemy(enemy) or (gang and other:EqualStateGroup('calm'))) and not other:HasTeam(enemy) then
					missing = missing or {}
					missing[#missing + 1] = enemy
				end
			end

			-- the trace only for those who have something to learn
			if missing and bgNPC.Vision.HasLineOfSight(other:GetNPC(), npc) then
				for _, enemy in ipairs(missing) do
					if gang then
						other:AddEnemy(enemy)
						-- AddEnemy may refuse an enemy protected by an arrest or another gameplay hook.
						if other:HasEnemy(enemy) and other:EqualStateGroup('calm') then
							other:RemoveAllTargets()
							other:SetState(other:IsWanted() and 'retreat' or 'defense')
						end
					else
						-- the blocked flag is only fresh for an actor asked just now (a calm one)
						local asked = other:EqualStateGroup('calm')
						if asked then
							other:RemoveAllTargets()
							other:SetState(other:GetReactionForProtect(enemy))
						end
						if not (asked and other.protect_blocked_enemy == enemy) then other:AddEnemy(enemy) end
					end
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
