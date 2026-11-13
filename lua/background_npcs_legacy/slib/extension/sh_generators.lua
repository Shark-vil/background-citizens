local tostring = tostring
local util_CRC = util.CRC
local util_Base64Encode = util.Base64Encode
local math_random = math.random
local uuid_template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
local string_gsub = string.gsub
local string_format = string.format
local string_char = string.char
local SysTime = SysTime
local RealTime = RealTime
--
local CURRENT_UID = 0
local UID_AS_MINUS = false
local MAX_INTEGER = 9007199254740000
local MIN_INTEGER = -MAX_INTEGER

function slib.GetUID()
  if UID_AS_MINUS then
    CURRENT_UID = CURRENT_UID - 1
    if CURRENT_UID <= MIN_INTEGER then
      CURRENT_UID = 0
      UID_AS_MINUS = false
    end
  else
    CURRENT_UID = CURRENT_UID + 1
    if CURRENT_UID >= MAX_INTEGER then
      CURRENT_UID = -1
      UID_AS_MINUS = true
    end
  end

  return CURRENT_UID
end
-- Compatibility with older versions
slib.GetUid = slib.GetUID

function slib.GetChecksumUID(salt)
  salt = salt and tostring(salt) or ''
  local sys_time = tostring(SysTime())
  local real_time = tostring(RealTime())

  return tostring(util_CRC(salt .. sys_time .. real_time))
end
-- Compatibility with older versions
slib.GenerateUid = slib.GetChecksumUID

-- Source:
-- https://gist.github.com/jrus/3197011
function slib.UUID()
  return string_gsub(uuid_template, '[xy]', function(c)
    local v = (c == 'x') and math_random(0, 0xf) or math_random(8, 0xb)

    return string_format('%x', v)
  end)
end

-- Source:
-- https://newbedev.com/lua-how-to-generate-a-random-string-in-lua-code-example
function slib.RandomString(length)
  length = length or 10
  local res = ''

  for i = 1, length do
    res = res .. string_char(math_random(97, 122))
  end

  return res
end