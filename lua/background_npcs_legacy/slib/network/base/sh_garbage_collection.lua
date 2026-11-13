local slib = slib
local snet = slib.Components.Network
local RealTime = RealTime
local table_remove = table.remove
local xpcall = xpcall
local IsValid = IsValid
local pairs = pairs
local Log = slib.Log
local Error = slib.Error

function snet.RunGarbageCollection(requests)
  local counting_requests = {}

  for i = #requests, 1, -1 do
    local data = requests[i]
    if not data or (data.request and not data.request.eternal and data.timeout < RealTime()) then
      table_remove(requests, i)
      if data and data.request then
        if data.request.func_complete then
          xpcall(function()
            if not IsValid(data.receiver) or not data.receiver.IsBot or data.receiver:IsBot() then return end
            data.request.func_complete(data.receiver, data)
          end, function(error_message)
            Error('Failed to complete the request due to an error')
            Error('NETWORK ERROR:\n' .. error_message)
          end)
        end
        local request_name = data.request.name
        counting_requests[request_name] = counting_requests[request_name] or 0
        counting_requests[request_name] = counting_requests[request_name] + 1
      end
    end
  end

  local count = #requests
  if count >= 500 then
    Log('WARNING: Something is making too many requests (' .. count .. ')')
    for k, v in pairs(counting_requests) do
      Log('COUNTING REQUEST: ' .. k .. ' - ' .. v)
    end
  end
end