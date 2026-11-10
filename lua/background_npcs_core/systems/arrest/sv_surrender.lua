--[[
	A second chance to give up: a player the police shoot at who now carries only safe weapons
	(bgn_arrest_safe_weapons, or nothing) and has not hurt anyone for bgn_arrest_surrender_delay seconds
	is offered an arrest again, even after a rampage or while wanted. Refusing (bgn_arrest_time_limit)
	or attacking again ends it like any arrest: the police open fire. The next chance comes after another delay.
--]]

local ArrestModule = bgNPC.Modules.Get('player_arrest')
local cvar_mode = GetConVar('bgn_arrest_mode')
local cvar_delay = GetConVar('bgn_arrest_surrender_delay')
local cvar_safe = GetConVar('bgn_arrest_safe_weapons')
local cvar_time_limit = GetConVar('bgn_arrest_time_limit')

local function SafeSet(list)
	local safe = {}
	for class in list:gmatch('[^,%s]+') do safe[class] = true end
	return safe
end

bgNPC.Test.Add('arrest.safe_weapons', function(check)
	local safe = SafeSet('weapon_fists, gmod_tool,weapon_physgun')
	check(safe.weapon_fists and safe.gmod_tool and safe.weapon_physgun and not safe[''], 'comma list, spaces ignored')
end)

local function IsDisarmed(ply)
	local safe = SafeSet(cvar_safe:GetString())
	for _, weapon in ipairs(ply:GetWeapons()) do
		if not safe[weapon:GetClass()] then return false end
	end
	return true
end

hook.Add('EntityTakeDamage', 'BGN_Surrender_LastAttack', function(target, dmginfo)
	local attacker = bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker())
	if IsValid(attacker) and attacker ~= target and dmginfo:GetDamage() > 0
		and (attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot())
		and (target:IsPlayer() or target:IsNPC() or target:IsNextBot()) then
		attacker.bgn_last_attack = CurTime()
	end
end)

-- An actor on foot the police hit while it holds no weapon and is not fighting gives up with this chance
local UNARMED_SURRENDER_CHANCE = 30
local COMBAT_STATES = { defense = true, killer = true, zombie = true, take_cover = true, pick_up_weapon = true, brawl = true }

hook.Add('EntityTakeDamage', 'BGN_Surrender_Unarmed', function(target, dmginfo)
	if not cvar_mode:GetBool() or dmginfo:GetDamage() <= 0 or dmginfo:GetDamage() >= target:Health() then return end
	local suspect = bgNPC.Actors.Get(target)
	local police = bgNPC.Actors.Get(bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker()))
	if not suspect or not police or not police:HasTeam('police') or suspect:HasTeam('police')
		or not suspect:IsAlive() or suspect:InVehicle() or IsValid(suspect:GetActiveWeapon())
		or COMBAT_STATES[suspect:GetState()] or not bgNPC.Util.Chance(UNARMED_SURRENDER_CHANCE) then return end
	ArrestModule:Surrender(suspect, police)
end)

timer.Create('BGN_Surrender', 1, 0, function()
	local delay = cvar_delay:GetFloat()
	if delay <= 0 or not cvar_mode:GetBool() then return end

	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() or (ply.bgn_surrender_next or 0) > now or now - (ply.bgn_last_attack or 0) < delay then continue end
		if ArrestModule:CanArrest(ply) then continue end -- already being arrested

		local police = {}
		for _, actor in ipairs(bgNPC.Actors.GetByTeam('police')) do
			if actor:IsAlive() and actor:HasEnemy(ply) then police[#police + 1] = actor end
		end
		if #police == 0 or not IsDisarmed(ply) then continue end

		ArrestModule:RemoveTarget(ply)
		ArrestModule:AddTarget(ply, police[1])
		ArrestModule:GetTarget(ply).surrender = now
		ply.bgn_surrender_next = now + cvar_time_limit:GetFloat() + delay

		for _, actor in ipairs(police) do
			if actor:InVehicle() then actor:ExitVehicle() end
			actor:RemoveEnemy(ply)
			actor:AddTarget(ply)
			actor:SetState('arrest', nil, true)
		end
		police[1]:Voice('police_surrender')
		hook.Run('BGN_PlayerSurrenderChance', ply, police[1])
	end
end)
