bgNPC.Test.Add('vehicle.eject_preserves_actors', function(check)
  local npc = {}
  local seizer = {
    GetNPC = function() return npc end,
    InVehicle = function() return false end
  }

  local passengers = {seizer}
  local crew = {}
  for i = 1, 3 do
    local actor = {}
    function actor:InVehicle()
      return true
    end

    function actor:ExitVehicle(forced)
      check(self == actor and forced == true, 'eject the original actor with a forced exit')
      self.exited = true
      if i ~= 2 then table.RemoveByValue(passengers, self) end
    end

    function actor:HasTeam(other)
      return other == seizer and i == 1
    end

    function actor:AddEnemy(enemy, reaction)
      self.enemy, self.reaction = enemy, reaction
    end

    function actor:SetState(state)
      self.state = state
    end

    crew[i] = actor
    passengers[#passengers + 1] = actor
  end

  local provider = {
    GetPassengers = function() return passengers end
  }

  BGN_VEHICLE.VehicleClass.Eject(provider, seizer)
  for _, actor in ipairs(crew) do
    check(actor.exited, 'every original passenger gets an exit attempt despite list removal')
  end

  check(#passengers == 2 and passengers[1] == seizer and passengers[2] == crew[2], 'keep the seizer and a blocked passenger')
  check(crew[1].enemy == nil, 'an ally does not fear the seizer')
  check(crew[3].enemy == npc and crew[3].reaction == 'fear' and crew[3].state == 'fear', 'hostile passengers retain their reaction')
end)
