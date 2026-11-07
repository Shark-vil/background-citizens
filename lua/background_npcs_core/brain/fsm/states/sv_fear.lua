--

local function update_state(actor)
	if not actor or not actor:IsAlive() then return end

	local enemy = actor:GetNearEnemy()
	if not IsValid(enemy) or enemy:Health() <= 0 then return end

	local npc = actor:GetNPC()
	local data = actor:GetStateData()
	data.call_for_help = data.call_for_help or CurTime() + math.random(25, 40)

	local dist = npc:GetPos():DistToSqr(enemy:GetPos())
	if dist < 40000 and bgNPC.Util.IsInView(enemy, npc:GetPos()) then -- 200 ^ 2
		if data.call_for_help < CurTime() and math.random(0, 100) <= 2 then
			actor:CallForHelp(enemy)
			data.call_for_help = CurTime() + math.random(25, 40)
		end
	elseif bgNPC.Util.Chance(25) then
		actor:StopStaticSequence()
		actor:SetState('run_from_danger', {
			dyspnea_delay = CurTime() + math.random(10, 20)
		})
	end
end

local function update_animation(actor)
	if not actor or not actor:IsAlive() then return end

	local data = actor:GetStateData()
	data.animation_type = data.animation_type or 0
	data.update_animation = data.update_animation or 0

	if data.update_animation < CurTime() then
		data.update_animation = CurTime() + 2
		data.animation_type = math.random(0, 100)
	else
		return
	end

	local animation_twitching = math.random(0, 100)

	if data.animation_type > 30 then
		if animation_twitching >= 10 then
			actor:PlayStaticSequence('Fear_Reaction_Idle', true)
		else
			actor:PlayStaticSequence('Fear_Reaction', true)
		end
	else
		if animation_twitching >= 10 then
			actor:PlayStaticSequence('cower_Idle', true)
		else
			actor:PlayStaticSequence('cower', true)
		end
	end
end

bgNPC.States.Register('fear', 'danger', {
	start = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then return end

		local npc = actor:GetNPC()

		-- A planning brain (GOAP) already weighs the weapon in hand, the redirect is for the FSM only.
		local active_weapon = not actor.brain.PickReaction and not actor:IsStayingOut() and actor:GetBody():GetActiveWeapon()
		if IsValid(active_weapon) then
			-- spawned unarmed: the engine AI picked this weapon up
			if not actor.weapon then
				actor.novice_shooter = true
				bgNPC.Combat.ApplyWeaponSkill(actor)
			end
			actor.weapon = active_weapon:GetClass()
			actor:SetState('defense', nil, true)
			return
		end

		local dist = enemy:GetPos():DistToSqr(npc:GetPos())
		if dist <= 490000 and math.random(0, 10) > 5 then
			actor:FearScream()
			actor:Fear()
		end

		actor:WalkToPos(nil)
	end,
	stop = function(actor)
		actor:StopStaticSequence()
	end,
	-- not_stop = function(actor)
	-- 	return not actor:HasNoEnemies()
	-- end,
	update = function(actor)
		if not actor:HasNoEnemies() then
			-- Armed actors (police/civil_defense/special_forces) can end up here only
			-- because they had no weapon at the moment they entered "defense". Keep
			-- retrying to get them back into the fight instead of leaving them stuck
			-- fleeing/screaming for the whole wanted chase.
			-- A planning brain (GOAP) decides itself when to fight, and an actor without a weapon has nothing to retry.
			local data = actor:GetStateData()
			data.rearm_retry = data.rearm_retry or CurTime() + 3

			if not actor.brain.PickReaction and actor.weapon and not actor:IsStayingOut() and data.rearm_retry < CurTime() then
				data.rearm_retry = CurTime() + 3
				actor:SetState('defense', nil, true)
				if not actor:HasState('fear') then return end
			end

			update_animation(actor)
			update_state(actor)
		else
			actor:RandomState()
		end
	end
})