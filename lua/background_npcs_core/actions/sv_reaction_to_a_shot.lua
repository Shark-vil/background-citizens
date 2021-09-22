local hook = hook
local GetConVar = GetConVar
local table = table
local tobool = tobool
local string = string
local bgNPC = bgNPC
local IsValid = IsValid
--

hook.Add('EntityEmitSound', 'BGN_WeaponShotSoundReaction', function(t)
	if not GetConVar('bgn_shot_sound_mode'):GetBool() then return end
	local sound_name = t.SoundName
	local attacker = t.Entity
	if not attacker:IsPlayer() then return end
	local wep = attacker:GetActiveWeapon()
	if not IsValid(wep) then return end
	if table.HasValueBySeq(bgNPC.cfg.shotsound.whitelist_weapons, wep:GetClass()) then return end
	local IsFound = false
	local sounds_name_found = bgNPC.cfg.shotsound.sound_name_found

	for i = 1, #sounds_name_found do
		local name = sounds_name_found[i]

		if tobool(string.find(sound_name, name)) then
			IsFound = true
			break
		end
	end

	if not IsFound then return end
	local actors = bgNPC:GetAllByRadius(attacker:GetPos(), 2500)

	for i = 1, #actors do
		local actor = actors[i]
		local reaction = actor:GetReactionForProtect()
		actor:SetReaction(reaction)
		local npc = actor:GetNPC()

		if npc == attacker or not bgNPC:IsTargetRay(npc, attacker)
			or hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, npc, reaction)
		then
			continue
		end

		local state = actor:GetState()

		if state == 'idle' or state == 'walk' or state == 'arrest' then
			actor:SetState(actor:GetLastReaction())
		end

		hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, npc, reaction)
	end
end)