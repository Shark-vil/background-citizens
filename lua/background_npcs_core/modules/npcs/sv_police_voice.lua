local replics = {
	'npc/metropolice/vo/sociocide.wav',
	'npc/overwatch/radiovoice/illegalinoperation63s.wav',
	'npc/metropolice/vo/readytojudge.wav',
	'npc/metropolice/vo/ptgoagain.wav',
	'npc/metropolice/vo/prosecute.wav',
	'npc/metropolice/vo/officerneedshelp.wav',
	'npc/metropolice/vo/officerneedsassistance.wav',
	'npc/metropolice/vo/level3civilprivacyviolator.wav'
}

hook.Add('BGN_SetNPCState', 'BGN_PoliceVoiceOnDefenseState', function(actor, state)
	if state == 'defense' and actor:HasTeam('police') and math.random(0, 100) < 50 then
		actor:GetNPC():EmitSound( table.RandomBySeq(replics) )
	end
end)

hook.Add('BGN_PostReactionTakeDamage', 'BGN_PoliceVoiceOnDefenseState', function(_, target, reaction)
	if reaction == 'defense' then
		local actor = bgNPC:GetActor(target)
		if not actor or not actor:HasTeam('police') or math.random(0, 100) > 50 then return end
		target:EmitSound( table.RandomBySeq(replics) )
	end
end)