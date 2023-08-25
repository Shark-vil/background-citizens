local ipairs = ipairs
local math_random = math.random
local table_RandomBySeq = table.RandomBySeq
local CurTime = CurTime
local CHAN_AUTO = CHAN_AUTO
local slib_chance = slib.chance
--
local replics = {
	'ambient/voices/cough1.wav',
	'ambient/voices/cough2.wav',
	'ambient/voices/cough3.wav',
	'ambient/voices/cough4.wav'
}

async.Add('BGN_ActorsResidentsRandomVoice', function(yield, wait)
	for _, actor in ipairs(bgNPC:GetAllByTeam('residents')) do
		if actor and actor:IsAlive() and actor:EqualStateGroup('calm') and slib_chance(20) and (not actor._delay_cough_sound or actor._delay_cough_sound < CurTime()) then
			actor:GetNPC():EmitSound(table_RandomBySeq(replics), math_random(50, 70), 100, 1, CHAN_AUTO)
			actor._delay_cough_sound = CurTime() + math_random(10, 60)
		end
		yield()
	end
	wait(3)
end)