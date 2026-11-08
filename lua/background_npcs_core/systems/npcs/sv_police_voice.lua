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

-- voice_id nil: the old sound only for players with voices off (the phrase itself is voiced)
local function RandomPlay(actor, voice_id)
	if not actor or not actor:IsAlive() or not actor:HasTeam('police') then return end
	-- police_combat waits out its cooldown in Actor:Voice; the voiceless fallback (voice_id nil) shares it
	if (actor.combat_voice_next or 0) > CurTime() or math.random(0, 100) > 50 then return end
	if not voice_id then actor.combat_voice_next = CurTime() + 20 end
	actor:Voice(voice_id, bgNPC.Table.Random(replics))
end

hook.Add('BGN_SetState', 'BGN_PoliceVoiceOnDefenseState', function(actor, state)
	if state ~= 'defense' then return end
	RandomPlay(actor, 'police_combat')
end)

hook.Add('BGN_PostReactionTakeDamage', 'BGN_PoliceVoiceOnDefenseState', function(_, target, reaction)
	if reaction ~= 'defense' then return end
	RandomPlay(bgNPC.Actors.Get(target), 'police_combat')
end)

hook.Add('BGN_StartReplic', 'BGN_PoliceVoice', function(actor)
	if not actor:EqualStateGroup('danger') then return end
	RandomPlay(actor)
end)

-- the nearest officer who saw it reports a fallen colleague
hook.Add('BGN_OnKilledActor', 'BGN_PoliceVoiceOfficerDown', function(actor)
	if not actor:HasTeam('police') then return end
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end

	local pos, nearest, nearest_dist = npc:GetPos(), nil, 1500 ^ 2
	for _, other in ipairs(bgNPC.Actors.GetByTeam('police')) do
		if other ~= actor and other:IsAlive() then
			local dist = other:GetNPC():GetPos():DistToSqr(pos)
			if dist < nearest_dist then nearest, nearest_dist = other, dist end
		end
	end
	if nearest then nearest:Voice('police_officer_down') end
end)
