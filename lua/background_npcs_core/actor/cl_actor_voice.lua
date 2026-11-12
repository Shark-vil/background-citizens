--[[
	Voiced lines (cvar "bgn_cl_voices", this computer only). The server only says who speaks which line:
	SayReplic (text + voice) and Actor:Voice (voice only). Enabled in both actor modes; 0 mutes voices.
	Conversations use their own clips; individual events may supply a fallback sound. The clip is
		sound/background_npcs/vo/<language>/<line id>/<index>[_f].ogg
	in the language of the phrases (config/replics), index = the phrase's place in bgNPC.cfg.replics[line id],
	_f = the female take when there is one. Made by tools/voices/make_voices.py.
--]]
local cvar_voices = GetConVar('bgn_cl_voices')
local exists = {}
local function Exists(path)
  if exists[path] == nil then exists[path] = file.Exists('sound/' .. path, 'GAME') end
  return exists[path]
end

local function Clip(actor, line_id, index)
  local base = 'background_npcs/vo/' .. bgNPC.cfg.replics_language .. '/' .. line_id .. '/' .. index
  if actor:GetGenderByModel() == 'female' and Exists(base .. '_f.ogg') then return base .. '_f.ogg' end
  if Exists(base .. '.ogg') then return base .. '.ogg' end
end

local function Emit(actor, path)
  local npc = actor:GetNPC()
  if not IsValid(npc) then return end
  -- police shout and use the radio: heard further than citizens talking
  npc:EmitSound(path, actor:HasTeam('police') and 85 or 70, 100, 1, CHAN_VOICE)
end

-- @return boolean a clip was played
local function Play(actor, line_id, index)
  if not line_id or not cvar_voices:GetBool() then return false end
  local lines = bgNPC.cfg.replics[line_id]
  if not lines or #lines == 0 then return false end
  index = index or math.random(#lines)
  local path = Clip(actor, line_id, index)
  if not path then return false end
  Emit(actor, path)
  return true
end

bgNPC.VoicePlay = Play -- the phrases with text (cl_actor_text_say.lua)
bgNPC.Net.Receive('bgn_actor_voice', function(_, actor_uid, voice_id, fallback)
  local actor = bgNPC.Actors.GetByUid(actor_uid)
  if not actor or Play(actor, voice_id) or not fallback or not cvar_voices:GetBool() then return end
  Emit(actor, fallback)
end)
