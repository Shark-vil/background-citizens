local ServerLoad = bgNPC.ServerLoad
local Squads = bgNPC.Squads
local SPACING = Squads.SPACING
local GetPlayersDisposition = bgNPC.NextBotBody.GetPlayersDisposition
local Cast, FINALS = bgNPC.Conversation.Cast, bgNPC.Conversation.FINALS
local SafeSet = bgNPC.Modules.Get('player_arrest').SafeSet
local NextBot = scripted_ents.GetStored('bgn_nextbot').t
local SwepStats, PROFICIENCY, DEFAULT_WEAPON = NextBot.SwepStats, NextBot.PROFICIENCY, NextBot.DEFAULT_WEAPON

bgNPC.Test.Add('server_load', function(check)
  local interval = 1 / 66
  check(not ServerLoad.IsSlowWindow(66, 1, interval), 'a full second of ticks is no lag')
  check(not ServerLoad.IsSlowWindow(56, 1, interval), 'a few missing ticks are no lag')
  check(ServerLoad.IsSlowWindow(40, 1, interval), 'a third of the ticks missing is a lag')
  check(ServerLoad.IsSlowWindow(70, 1.5, interval), 'the window length counts')
end)

bgNPC.Test.Add('squads.formations', function(check)
  local line = Squads.FormationOffsets('line', 3)
  check(line[1][2] == -SPACING and line[2][2] == 0 and line[3][2] == SPACING, 'line is abreast and centered')
  local wedge = Squads.FormationOffsets('wedge', 5)
  check(wedge[1][1] == 0 and wedge[1][2] == 0, 'wedge tip is the leader')
  check(wedge[2][1] == wedge[3][1] and wedge[2][2] == -wedge[3][2], 'wedge rows are symmetric')
  check(wedge[4][1] < wedge[2][1], 'wedge widens backwards')
  local column = Squads.FormationOffsets('column', 3)
  check(column[3][1] == -2 * SPACING and column[3][2] == 0, 'column is in file')
end)

bgNPC.Test.Add('nextbot.players_disposition', function(check)
  local npc = {
    Disposition = function(_, relation) return relation end
  }

  for _, relation in ipairs({D_HT, D_FR, D_LI, D_NU, D_ER}) do
    check(GetPlayersDisposition(npc, {relation, D_HT, relation}) == relation, 'most frequent disposition ' .. relation)
  end

  check(GetPlayersDisposition(npc, {}) == D_NU, 'no players')
  check(GetPlayersDisposition(npc, {D_HT, D_LI}) == D_NU, 'tie is neutral')
  check(GetPlayersDisposition(npc, {D_LI, D_HT, D_LI, D_FR, D_FR}) == D_NU, 'tie after an early leader')
  check(GetPlayersDisposition(npc, {D_HT, D_LI, D_FR, D_FR}) == D_FR, 'plurality without absolute majority')
end)

bgNPC.Test.Add('conversations.scripts', function(check)
  for _, script in ipairs(bgNPC.cfg.conversations or {}) do
    local lines = bgNPC.cfg.replics['conv_' .. script.id]
    check(lines and #lines == #script.lines, 'conv_' .. script.id .. ': phrases match the script lines')
    check(#script.roles >= 2 and #script.roles <= 3, script.id .. ': 2-3 roles')
    check(not script.final or FINALS[script.final], script.id .. ': known final')
    for _, line in ipairs(script.lines) do
      check(script.roles[line[1]] ~= nil, script.id .. ': speaker has a role')
    end
  end
end)

bgNPC.Test.Add('conversations.cast', function(check)
  local function Fake(actor_type)
    return {
      GetType = function() return actor_type end
    }
  end

  local police, thief, citizen = Fake('police'), Fake('thief'), Fake('citizen')
  local script = {
    id = 'police_thief',
    roles = {'police', 'thief'},
    lines = bgNPC.cfg.replics['conv_police_thief']
  }

  local cast = Cast(script, thief, {citizen, police})
  check(cast and cast[1] == police and cast[2] == thief, 'the initiator takes its own role, a candidate the other')
  check(Cast(script, citizen, {police, thief}) == nil, 'no role for the initiator: no conversation')
  check(Cast(script, police, {citizen}) == nil, 'a role nobody can take: no conversation')
end)

bgNPC.Test.Add('arrest.safe_weapons', function(check)
  local safe = SafeSet('weapon_fists, gmod_tool,weapon_physgun')
  check(safe.weapon_fists and safe.gmod_tool and safe.weapon_physgun and not safe[''], 'comma list, spaces ignored')
end)

bgNPC.Test.Add('nextbot.swep_stats', function(check)
  local s = SwepStats({
    Damage = 30,
    RPM = 600,
    ClipSize = 25,
    Sound = {'A.Single'}
  }, 'ar2')

  check(s.damage == 30 and s.delay == 0.1 and s.clip == 25 and s.sound == 'A.Single' and s.hold == 'rifle', 'tfa-style rifle')
  s = SwepStats({
    ClipSize = -1
  }, 'knife')

  check(s.melee and s.clip == nil and s.range == 75 and s.hold == 'melee', 'melee without clip')
  s = SwepStats({}, 'revolver')
  check(s.hold == 'pistol' and s.damage == DEFAULT_WEAPON.damage, 'empty primary falls back to pistol')
end)

bgNPC.Test.Add('nextbot.proficiency_ladder', function(check)
  for p = 1, 4 do
    local a, b = PROFICIENCY[p - 1], PROFICIENCY[p]
    check(b.spread < a.spread and b.damage > a.damage and b.reaction < a.reaction, 'skill ' .. p .. ' beats ' .. (p - 1))
  end
end)
