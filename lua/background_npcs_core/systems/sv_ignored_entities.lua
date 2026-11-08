--[[
	Ignored entities (bgNPC.Combat.IsIgnored: build mode, bgNPCIgnore, players under ai_ignoreplayers):
	the damage and witness reaction chains stop here, so later hooks never see them.
	The entry points check it too (sv_self_damage, sv_reaction_to_a_shot, AddEnemy, AddTarget).
--]]

local IsIgnored = bgNPC.Combat.IsIgnored

-- false: no reaction, the damage itself still goes through (true would block it)
hook.Add('BGN_PreReactionTakeDamage', 'BGN_IgnoredEntities', function(attacker)
	if IsIgnored(attacker) then return false end
end)

-- witnesses: skip the fight when either side is ignored
hook.Add('BGN_PreDamageToAnotherActor', 'BGN_IgnoredEntities', function(_, attacker, target)
	if IsIgnored(attacker) or IsIgnored(target) then return true end
end)
