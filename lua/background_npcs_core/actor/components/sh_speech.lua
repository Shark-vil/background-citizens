local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
--

-- ---------------------------------------------------------------------------
-- Speech
-- ---------------------------------------------------------------------------
function Actor:VoiceSay(sound_path, sound_level, pitch_percent, volume, channel, sound_flags, dsp)
	Assert.Arg(1, sound_path, 'string|nil', 'ACTOR:VoiceSay')

	if not sound_path or not self:IsAlive() then return end

	self.npc:EmitSound(sound_path,
		sound_level or 75,
		pitch_percent or 100,
		volume or 1,
		channel or CHAN_AUTO,
		sound_flags or 0,
		dsp or 0)
end

function Actor:Say(say_text, say_time, voice_sound, animation_sequence)
	Assert.Arg(1, say_text, 'string|nil', 'ACTOR:Say')
	Assert.Arg(2, say_time, 'number|nil', 'ACTOR:Say')

	if say_text then
		bgNPC.Net.Send('bgn_actor_text_say', nil, self.uid, say_text, say_time or 5)
	end

	self:VoiceSay(voice_sound)
	if animation_sequence then self:PlayStaticSequence(animation_sequence) end
end

function Actor:SayReplic(replic_id, replic_index, say_time, voice_sound, animation_sequence)
	Assert.Arg(1, replic_id, 'string', 'ACTOR:SayReplic')
	Assert.Arg(2, replic_index, 'number', 'ACTOR:SayReplic')

	local replics = bgNPC.cfg.replics[replic_id]
	if not replics or not replics[replic_index] then return end

	bgNPC.Net.Send('bgn_actor_text_say_replic', nil, self.uid, replic_id, replic_index, say_time or 5)
	self:VoiceSay(voice_sound)
	if animation_sequence then self:PlayStaticSequence(animation_sequence) end
end

-- A voice line without text. Each client plays a random clip of voice_id in its own language
-- (actor/cl_actor_voice.lua), or the fallback sound when it has voices off or no clip. voice_id nil: fallback only.
local COMBAT_VOICES = { police_combat = true, police_contact = true }
local COMBAT_VOICE_COOLDOWN = 20 -- shooting and getting hit fire these every moment: one line per actor this often

function Actor:Voice(voice_id, fallback)
	Assert.Arg(1, voice_id, 'string|nil', 'ACTOR:Voice')
	Assert.Arg(2, fallback, 'string|nil', 'ACTOR:Voice')

	if not self:IsAlive() then return end
	if COMBAT_VOICES[voice_id] then
		local now = CurTime()
		if (self.combat_voice_next or 0) > now then return end
		self.combat_voice_next = now + COMBAT_VOICE_COOLDOWN
	end
	bgNPC.Net.Send('bgn_actor_voice', nil, self.uid, voice_id, fallback)
end
