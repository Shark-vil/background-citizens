local table_RandomBySeq = bgNPC.Table.Random
local REPOSITION_PERIOD = 3
local SLOT_REACHED_SQR = 50 ^ 2
local SLOT_MOVED_SQR = 64 ^ 2
--

-- Squad member (systems/sv_tactical_groups.lua): the body goes straight to the formation slot.
-- The actor walk would stop 150 units short (MOVEMENT_FINISHED_DIST), wider than the formation spacing.
local function MoveToSlot(actor, data, slot)
	local body = actor:GetBody()
	if actor:WalkDestinationExists() then actor:StopWalk() end

	if actor:GetPos():DistToSqr(slot) <= SLOT_REACHED_SQR then
		if data.slot then body:StopMoving() end
		data.slot = nil
		return
	end

	if data.slot and data.slot:DistToSqr(slot) < SLOT_MOVED_SQR and body:IsMoving() then return end
	data.slot = slot
	body:MoveTo(slot, true)
end

bgNPC.States.Register('defense', 'danger', {
	pre_start = function(actor)
		if not actor.weapon then
			-- Self-heal: an always-armed actor (no getting_weapon_chance) may have lost its weapon class.
			-- Actors with a chance lost the roll on spawn; arming them here armed every citizen that
			-- fear sent back to defense.
			local data = actor:GetData()
			local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. actor:GetType())

			if data.weapons and not data.getting_weapon_chance and (not cvar_disable_weapon or not cvar_disable_weapon:GetBool()) then
				actor.weapon = table_RandomBySeq(data.weapons)
			end
		end

		if not actor.weapon then return 'fear' end
	end,
	start = function(actor)
		-- an actor that came from fear still has its enemies as D_FR: an NPC won't shoot, a NextBot isn't in combat
		local body = actor:GetBody()
		for _, enemy in ipairs(actor.enemies) do
			if IsValid(enemy) then body:SetDisposition(enemy, D_HT) end
		end
		body:SetAlertLevel('combat')

		if actor:HasTeam('police') then
			local enemy = actor:GetNearEnemy()
			local npc = actor:GetNPC()
			if IsValid(enemy) and enemy:GetPos():DistToSqr(npc:GetPos()) < 250000 then
				npc:EmitSound('npc/metropolice/vo/defender.wav', 300, 100, 1, CHAN_AUTO)
			end
		end
	end,
	update = function(actor)
		local squad = actor.squad
		local enemy = squad and squad.enemy

		if not IsValid(enemy) then enemy = actor:GetNearEnemy() end
		if not IsValid(enemy) then
			if actor:HasNoEnemies() then actor:RandomState() end
			return
		end

		-- the weapon comes out right away; only the repositioning below is throttled
		local data = actor:GetStateData()
		if not data.disableWeapon then actor:PrepareWeapon() end

		if squad then
			MoveToSlot(actor, data, squad.slot)
			return
		end
		data.slot = nil

		local now = CurTime()
		if (data.next_move or 0) > now then return end
		data.next_move = now + REPOSITION_PERIOD

		local npc = actor:GetNPC()
		local npc_pos = npc:GetPos()
		local enemy_pos = enemy:GetPos()
		local current_distance = npc_pos:DistToSqr(enemy_pos)
		local is_player_in_vehicle = enemy:IsPlayer() and enemy:InVehicle()

		if is_player_in_vehicle and bgNPC.Util.Chance(20) then
			actor:SetState('go_to_police_car')
		elseif current_distance > 490000 then
			if is_player_in_vehicle then
				actor:WalkToTarget(enemy:GetVehicle(), 'run')
			else
				actor:WalkToTarget(enemy, 'run')
			end
		else
			-- Don't yank the NPC into a reposition/retreat schedule while it's
			-- already mid-attack (SCHED_RANGE_ATTACK1/RELOAD/etc.) - doing so was
			-- constantly cancelling shots before they landed.
			if actor:IsExecutingCombatSchedule() then return end

			local node
			local is_melee_weapon = actor:IsMeleeWeapon()

			if not is_melee_weapon and current_distance < 250000 and bgNPC.Vision.HasLineOfSight(npc, enemy) then
				node = bgNPC.Points.GetDistantInRadius(npc_pos + npc:GetForward() * -500, 500)
				actor:WalkToTarget()

				if node then
					actor:WalkToPos(node:GetPos(), 'run')
				else
					local fallback_enemy_position = enemy_pos + enemy:GetForward() * -200
					local fallback_position = npc_pos + npc:GetForward() * -200

					fallback_enemy_position = fallback_enemy_position + Vector(math.random(0, 200), math.random(0, 200), 0)
					fallback_position = fallback_position + Vector(math.random(0, 200), math.random(0, 200), 0)

					if enemy_pos:DistToSqr(fallback_enemy_position) > enemy_pos:DistToSqr(fallback_position) then
						actor:WalkToPos(fallback_enemy_position, 'run')
					else
						actor:WalkToPos(fallback_position, 'run')
					end
				end
			end

			if #actor.walkPath == 0 and not is_melee_weapon then
				actor:GetBody():MoveAwayFromEnemy()
			end
		end
	end
})