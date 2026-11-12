bgNPC.Test.Add('vehicle_lod.trace_hold', function(check)
  local hold = hook.GetTable()['Decent Vehicle: Trace']['BGN_VehicleLOD']
  local now = CurTime()
  local far = {
    bgnFarLOD = true,
    StopByTrace = now + .1
  }

  hold(far)
  check(far.StopByTrace > now + .25, 'a clear scan of a far car keeps it going until the next scan')
  local blocked = {
    bgnFarLOD = true,
    StopByTrace = now - 1
  }

  hold(blocked)
  check(blocked.StopByTrace == now - 1, 'a blocked scan is not extended')
  local near = {
    StopByTrace = now + .1
  }

  hold(near)
  check(near.StopByTrace == now + .1, 'a near car keeps the native timing')
end)
