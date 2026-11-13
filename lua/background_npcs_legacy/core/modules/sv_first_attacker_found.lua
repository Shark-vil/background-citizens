local hook_Run = hook.Run
local type = type
local IsValid = IsValid
local table_remove = table.remove
--
local ASSET = {}
local first_attackers = {}

local function EntityHasValid(ent)
	if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then return true end
	return false
end

hook.Add('EntityTakeDamage', 'BGN_FoundFirstAttacker', function(target, dmginfo)
	local attacker = dmginfo:GetAttacker()
	if not EntityHasValid(attacker) or not EntityHasValid(target) then return end

	if not attacker:IsPlayer() and not target:IsPlayer() then
		local AttackerActor = bgNPC:GetActor(attacker)
		local TargetActor = bgNPC:GetActor(target)
		if AttackerActor and TargetActor and AttackerActor:HasTeam(TargetActor) then return end
	end

	for i = #first_attackers, 1, -1 do
		local data = first_attackers[i]

		if data then
			if data.victim == attacker and data.attacker == target then return end
			if data.attacker == attacker and data.victim == target then return end
		end
	end

	local a, t = hook_Run('BGN_Module_FirstAttackerValidator', attacker, target)

	if a and type(a) == 'Entity' then
		attacker = a
	end

	if t and type(t) == 'Entity' then
		target = t
	end

	first_attackers[#first_attackers + 1] = {
		attacker = attacker,
		victim = target,
	}
end)

function ASSET:IsFirstAttacker(attacker, victim)
	for i = 1, #first_attackers do
		local data = first_attackers[i]
		if data and data.attacker == attacker and data.victim == victim then return true end
	end

	return false
end

function ASSET:ClearDeath()
	for i = #first_attackers, 1, -1 do
		local data = first_attackers[i]

		if data then
			if not IsValid(data.attacker) or data.attacker:Health() <= 0 then
				table_remove(first_attackers, i)
			elseif not IsValid(data.victim) or data.victim:Health() <= 0 then
				table_remove(first_attackers, i)
			end
		end
	end
end

function ASSET:RemoveAttacker(attacker)
	for i = #first_attackers, 1, -1 do
		local data = first_attackers[i]

		if data and data.attacker == attacker then
			table_remove(first_attackers, i)
		end
	end
end

function ASSET:GetData()
	return first_attackers
end

hook.Add('PostCleanupMap', 'BGN_FirstAttackerModule_ClearAttackersList', function()
	first_attackers = {}
end)

hook.Add('PlayerDeath', 'BGN_FirstAttackerModule_ClearAttackersList', function(ply)
	ASSET:RemoveAttacker(ply)
end)

hook.Add('BGN_PlayerArrest', 'BGN_FirstAttackerModule_DeletePlayerItemIfExists', function(ply)
	ASSET:RemoveAttacker(ply)
end)

timer.Create('BGN_ModuleTimer_FirstAttacker', 1, 0, function()
	ASSET:ClearDeath()
end)

list.Set('BGN_Modules', 'first_attacker', ASSET)