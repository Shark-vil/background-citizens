-- Police cars and ambulances (AI npc_dvbgn_police) are locked for players while an actor sits inside,
-- like the Car Keys addon does it: Use on the car and entering any of its seats are refused with a locked sound.
local LOCKED_SOUND = 'doors/handle_pushbar_locked1.wav'
-- @return boolean the car (or the car of this seat) is a service car with someone inside
local function IsLocked(ent)
  if not IsValid(ent) then return false end
  local provider = BGN_VEHICLE:GetVehicleProvider(ent)
  if not provider then
    local parent = ent:GetParent() -- simfphys seats are pods parented to the car
    provider = IsValid(parent) and BGN_VEHICLE:GetVehicleProvider(parent)
  end

  if not provider or provider.ai_class ~= 'npc_dvbgn_police' then return false end
  return provider:GetDriver() ~= nil or #provider:GetPassengers() ~= 0
end

local function Refuse(ply, ent)
  if (ply.bgn_locked_sound_time or 0) > CurTime() then return end
  ply.bgn_locked_sound_time = CurTime() + 1
  ent:EmitSound(LOCKED_SOUND)
end

hook.Add('PlayerUse', 'BGN_LockServiceCars', function(ply, ent)
  if IsLocked(ent) then
    Refuse(ply, ent)
    return false
  end
end)

hook.Add('CanPlayerEnterVehicle', 'BGN_LockServiceCars', function(ply, vehicle)
  if IsLocked(vehicle) then
    Refuse(ply, vehicle)
    return false
  end
end)
