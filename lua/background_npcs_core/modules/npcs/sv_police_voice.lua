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

local function RandomPlay(actor)
	if not actor or not actor:IsAlive() or not actor:HasTeam('police') or math.random(0, 100) > 50  then return end
	actor:GetNPC():EmitSound( table.RandomBySeq(replics) )
end

hook.Add('BGN_SetState', 'BGN_PoliceVoiceOnDefenseState', function(actor, state)
	if state ~= 'defense' then return end
	RandomPlay(actor)
end)

hook.Add('BGN_PostReactionTakeDamage', 'BGN_PoliceVoiceOnDefenseState', function(_, target, reaction)
	if reaction ~= 'defense' then return end
	RandomPlay( bgNPC:GetActor(target) )
end)

hook.Add('BGN_StartReplic', 'BGN_PoliceVoice', function(actor)
	if not actor:EqualStateGroup('danger') then return end
	RandomPlay(actor)
end)