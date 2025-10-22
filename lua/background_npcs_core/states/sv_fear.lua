local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
--

local function update_state(actor)
	if not actor or not actor:IsAlive() then return end

	local enemy = actor:GetNearEnemy()
	if not IsValid(enemy) or enemy:Health() <= 0 then return end

	local npc = actor:GetNPC()
	local data = actor:GetStateData()
	data.call_for_help = data.call_for_help or CurTime() + math_random(25, 40)

	local dist = npc:GetPos():DistToSqr(enemy:GetPos())
	if dist < 40000 and enemy:slibIsViewVector(npc:GetPos()) then -- 200 ^ 2
		if data.call_for_help < CurTime() and math_random(0, 100) <= 2 then
			actor:CallForHelp(enemy)
			data.call_for_help = CurTime() + math_random(25, 40)
		end
	elseif slib.chance(25) then
		actor:StopStaticSequence()
		actor:SetState('run_from_danger', {
			dyspnea_delay = CurTime() + math_random(10, 20)
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
		data.animation_type = math_random(0, 100)
	else
		return
	end

	local animation_twitching = math_random(0, 100)

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

bgNPC:SetStateAction('fear', 'danger', {
	start = function(actor)
		local enemy = actor:GetNearEnemy()
		if not IsValid(enemy) then return end

		local npc = actor:GetNPC()

		if npc.GetActiveWeapon then
			local active_weapon = npc:GetActiveWeapon()
			if IsValid(active_weapon) then
				actor.weapon = active_weapon:GetClass()
				actor:SetState('defense', nil, true)
				return
			end
		end

		local dist = enemy:GetPos():DistToSqr(npc:GetPos())
		if dist <= 490000 and math_random(0, 10) > 5 then
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
			update_animation(actor)
			update_state(actor)
		else
			actor:RandomState()
		end
	end
})