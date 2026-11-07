local table_RandomBySeq = bgNPC.Table.Random
local Chance = bgNPC.Util.Chance
--
local replics = {
	'ambient/voices/cough1.wav',
	'ambient/voices/cough2.wav',
	'ambient/voices/cough3.wav',
	'ambient/voices/cough4.wav'
}

bgNPC.Tasks.Add('BGN_ActorsResidentsRandomVoice', function(yield, wait)
	for _, actor in ipairs(bgNPC.Actors.GetByTeam('residents')) do
		if actor and actor:IsAlive() and actor:EqualStateGroup('calm') and Chance(20) and (not actor._delay_cough_sound or actor._delay_cough_sound < CurTime()) then
			actor:GetNPC():EmitSound(table_RandomBySeq(replics), math.random(50, 70), 100, 1, CHAN_AUTO)
			actor._delay_cough_sound = CurTime() + math.random(10, 60)
		end
		yield()
	end
	wait(3)
end)