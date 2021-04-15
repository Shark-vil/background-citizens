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

hook.Add("BGN_SetNPCState", "BGN_PoliceVoiceOnDefenseState", function(actor, state)
   if #replics == 0 then return end

	if actor:HasTeam('police') and state == 'defense' then
		local rnd = math.random(0, 100)
		if rnd < 50 then
			local sound = array.Random(replics)
			actor:GetNPC():EmitSound(sound)
		end
	end
end)