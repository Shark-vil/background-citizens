local table_HasValueBySeq = bgNPC.Table.HasValue
local cvar_bgn_shot_sound_mode = GetConVar('bgn_shot_sound_mode')
--

hook.Add('EntityEmitSound', 'BGN_WeaponShotSoundReaction', function(t)
	if not cvar_bgn_shot_sound_mode:GetBool() then return end
	local sound_name = t.SoundName
	local attacker = t.Entity
	if not attacker:IsPlayer() then return end
	local wep = attacker:GetActiveWeapon()
	if not IsValid(wep) then return end
	if table_HasValueBySeq(bgNPC.cfg.shotsound.whitelist_weapons, wep:GetClass()) then return end
	local IsFound = false
	local sounds_name_found = bgNPC.cfg.shotsound.sound_name_found

	for i = 1, #sounds_name_found do
		local name = sounds_name_found[i]

		if string.find(sound_name, name) then
			IsFound = true
			break
		end
	end

	if not IsFound then return end
	local actors = bgNPC.Actors.GetInRadius(attacker:GetPos(), 2500)

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if npc == attacker or not bgNPC.Vision.HasLineOfSight(npc, attacker) then continue end

		local reaction = actor:GetReactionForProtect(attacker)
		actor:SetReaction(reaction)
		if hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, npc, reaction) then continue end

		if actor:EqualStateGroup('calm') then
			actor:SetState(actor:GetLastReaction())
		end

		hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, npc, reaction)
	end
end)