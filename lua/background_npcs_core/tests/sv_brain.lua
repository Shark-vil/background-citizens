local GOAP = bgNPC.GOAP
local Action, Goal, F = GOAP.Action, GOAP.Goal, GOAP.Fact

bgNPC.Test.Add('goap.planner', function(check)
  local get_weapon = Action('test_get_weapon', {
    effects = {
      test_armed = true
    },
    cost = 2
  })

  local attack = Action('test_attack', {
    pre = {
      test_armed = true
    },
    effects = {
      test_win = true
    },
    cost = 1
  })

  local punch = Action('test_punch', {
    effects = {
      test_win = true
    },
    cost = 5
  })

  local win = Goal('test_win', {
    want = {
      test_win = true
    }
  })

  local plan = GOAP.Plan(0, win, {get_weapon, attack, punch})
  check(plan and #plan == 2 and plan[1] == get_weapon and plan[2] == attack, 'cheapest chain: get weapon, attack')
  plan = GOAP.Plan(F('test_armed'), win, {get_weapon, attack, punch})
  check(plan and #plan == 1 and plan[1] == attack, 'armed: attack right away')
  check(#GOAP.Plan(F('test_win'), win, {attack}) == 0, 'satisfied goal: empty plan')
  check(GOAP.Plan(0, win, {attack}) == nil, 'impossible goal: nil')
  check(GOAP.Plan(0, win, {attack}) == nil, 'impossible goal is cached')
end)

bgNPC.Test.Add('goap.sets', function(check)
  local actions = {GOAP.actions.attack, GOAP.actions.call_police, GOAP.actions.flee}
  local ws = bit.bor(F('has_enemy'), F('armed'))
  local plan = GOAP.Plan(ws, GOAP.goals.eliminate, actions)
  check(plan and plan[1] == GOAP.actions.attack, 'armed citizen can eliminate by attacking')
  plan = GOAP.Plan(F('has_enemy'), GOAP.goals.report, actions)
  check(plan and plan[1] == GOAP.actions.call_police, 'far enemy: call the police')
  plan = GOAP.Plan(bit.bor(F('has_enemy'), F('enemy_close')), GOAP.goals.report, actions)
  check(plan == nil, 'close enemy: cannot call the police')
  local citizen = GOAP.sets.citizen
  ws = bit.bor(F('has_enemy'), F('armed'), F('enemy_armed'))
  check(citizen.eliminate(ws) > citizen.survive(ws), 'armed citizen keeps fighting an armed enemy')
  ws = bit.bor(ws, F('low_health'))
  check(citizen.survive(ws) > citizen.eliminate(ws), 'hurt armed citizen runs')
  ws = bit.bor(F('has_enemy'), F('enemy_armed'))
  check(citizen.report(ws) > citizen.survive(ws), 'unarmed citizen reports a far armed enemy')
  check(GOAP.actions.flee:Runs('run_from_danger'), 'running from danger is still fleeing')
  local A = GOAP.actions
  local fight = {A.attack, A.take_cover, A.call_backup}
  ws = bit.bor(F('has_enemy'), F('armed'), F('enemy_armed'), F('is_police'))
  plan = GOAP.Plan(ws, GOAP.goals.eliminate, fight)
  check(plan and #plan == 2 and plan[1] == A.take_cover and plan[2] == A.attack, 'police vs one armed enemy: cover, attack, no backup')
  local crowd = bit.bor(F('has_enemy'), F('armed'), F('is_police'), F('outnumbered'))
  plan = GOAP.Plan(crowd, GOAP.goals.eliminate, fight)
  check(plan and #plan == 3 and plan[1] == A.take_cover and plan[2] == A.call_backup and plan[3] == A.attack, 'outnumbered police: cover, backup, attack')
  plan = GOAP.Plan(crowd, GOAP.goals.eliminate, {A.attack, A.call_backup})
  check(plan and #plan == 2 and plan[1] == A.call_backup, 'outnumbered, no cover: backup in the open')
  plan = GOAP.Plan(bit.bor(crowd, F('backup_called'), F('in_cover')), GOAP.goals.eliminate, fight)
  check(plan and #plan == 1 and plan[1] == A.attack, 'in cover with backup: attack')
  plan = GOAP.Plan(bit.bor(F('has_enemy'), F('armed')), GOAP.goals.eliminate, fight)
  check(plan and #plan == 1 and plan[1] == A.attack, 'unarmed enemy: attack right away')
  ws = bit.bor(F('has_enemy'), F('armed'), F('wanted'))
  local gangster = GOAP.sets.gangster
  check(gangster.hide(ws) > gangster.eliminate(ws), 'a wanted gangster hides first')
  plan = GOAP.Plan(ws, GOAP.goals.hide, {GOAP.actions.attack, GOAP.actions.hide})
  check(plan and plan[1] == GOAP.actions.hide, 'hiding runs retreat')
  ws = bit.bor(F('has_enemy'), F('armed'), F('wanted'), F('can_surrender'), F('enemy_police'))
  check(gangster.give_up(ws) > gangster.hide(ws), 'a hurt gangster facing the police gives up before hiding')
  plan = GOAP.Plan(ws, GOAP.goals.give_up, {A.attack, A.hide, A.surrender})
  check(plan and #plan == 1 and plan[1] == A.surrender, 'giving up runs the surrender')
  ws = bit.bor(F('has_enemy'), F('desperate'), F('can_hold_door'))
  plan = GOAP.Plan(ws, GOAP.goals.shelter, {A.hold_door, A.flee})
  check(plan and #plan == 1 and plan[1] == A.hold_door, 'a desperate actor can close and hold an open door')
  check(citizen.shelter(ws) > citizen.survive(ws), 'an available door takes priority in a hopeless fight')
  check(GOAP.sets.police.shelter == nil, 'police have no door shelter goal')
  plan = GOAP.Plan(bit.bor(ws, F('is_police')), GOAP.goals.shelter, {A.hold_door})
  check(plan == nil, 'police cannot plan to hold a door')
  plan = GOAP.Plan(F('has_enemy'), GOAP.goals.shelter, {A.hold_door})
  check(plan == nil, 'a normal fight or absent open door cannot start holding')
  ws = bit.bor(F('has_enemy'), F('is_police'), F('enemy_bracing'), F('armed'))
  plan = GOAP.Plan(ws, GOAP.goals.eliminate, {A.attack, A.breach_door})
  check(plan and #plan == 1 and plan[1] == A.breach_door, 'police breach a held door before attacking')
  plan = GOAP.Plan(bit.bor(F('has_enemy'), F('enemy_bracing')), GOAP.goals.eliminate, {A.breach_door})
  check(plan == nil, 'a civilian cannot choose the police breach action')
end)
