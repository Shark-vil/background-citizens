--[[
	Networking on top of the "net" library. Replaces slib "snet".

	All messages go through one network string. Arguments are serialized into a
	compact string (nil, bool, number, string, entity, vector, angle, color, table),
	compressed when large and split into chunks above 60 KB, so any size works.

	Server (no-op on the client):
		Net.Send(name, target, ...)     target: player | list of players | nil (all players)
		Net.ToolRPC(tool, method, ...)  calls TOOL:method(...) on the owner's client
	Client (no-op on the server):
		Net.SendToServer(name, ...)
	Both:
		Net.Receive(name, function(ply, ...) end, options)
			options.admin          only admins may send it (server side)
			options.wait_entities  wait (up to 3 s) until entity arguments exist on the client
		Net.SetProgressText(name, text) shows a progress notification for chunked transfers
--]]

local Net = bgNPC.Net or {}
bgNPC.Net = Net

local CHANNEL = 'bgn_net'
local CHUNK_SIZE = 60000
local COMPRESS_FROM = 512
local CHUNK_LIFETIME = 30
local WAIT_ENTITIES_TIME = 3
local CLIENT_RATE_LIMIT = 100 -- messages per second from one client

--

-- ---------------------------------------------------------------------------
-- Serializer
-- ---------------------------------------------------------------------------

local function num(v)
	if v ~= v then return 'nan' end
	if v == math.huge then return 'inf' end
	if v == -math.huge then return '-inf' end
	if v % 1 == 0 and v > -1e15 and v < 1e15 then return string.format('%d', v) end
	return string.format('%.17g', v)
end

local function tonum(s)
	if s == 'nan' then return 0 / 0 end
	if s == 'inf' then return math.huge end
	if s == '-inf' then return -math.huge end
	return tonumber(s)
end

local Write

local function WriteValue(buf, n, v, seen)
	local id = TypeID(v)

	if id == TYPE_NIL then
		n = n + 1; buf[n] = '_'
	elseif id == TYPE_BOOL then
		n = n + 1; buf[n] = v and 'T' or 'F'
	elseif id == TYPE_NUMBER then
		n = n + 1; buf[n] = 'n' .. num(v) .. ';'
	elseif id == TYPE_STRING then
		n = n + 1; buf[n] = 's' .. #v .. ':' .. v
	elseif id == TYPE_ENTITY then
		if v == game.GetWorld() then
			n = n + 1; buf[n] = 'e0;'
		elseif IsValid(v) then
			n = n + 1; buf[n] = 'e' .. v:EntIndex() .. ';'
		else
			n = n + 1; buf[n] = 'E'
		end
	elseif id == TYPE_VECTOR then
		n = n + 1; buf[n] = 'v' .. num(v.x) .. ',' .. num(v.y) .. ',' .. num(v.z) .. ';'
	elseif id == TYPE_ANGLE then
		n = n + 1; buf[n] = 'a' .. num(v.p) .. ',' .. num(v.y) .. ',' .. num(v.r) .. ';'
	elseif id == TYPE_TABLE then
		if IsColor(v) then
			n = n + 1; buf[n] = 'c' .. v.r .. ',' .. v.g .. ',' .. v.b .. ',' .. v.a .. ';'
		elseif seen[v] then
			n = n + 1; buf[n] = '_' -- cyclic reference
		elseif v.NetSerialize then
			-- Objects can choose their network form (e.g. nodes send indexes instead of links).
			n = WriteValue(buf, n, v:NetSerialize(), seen)
		else
			seen[v] = true
			n = n + 1; buf[n] = '{'
			for key, value in pairs(v) do
				local key_id = TypeID(key)
				-- Keys that cannot be restored are skipped together with their value.
				if key_id == TYPE_STRING or key_id == TYPE_NUMBER or key_id == TYPE_BOOL or key_id == TYPE_ENTITY then
					n = Write(buf, n, key, seen)
					n = Write(buf, n, value, seen)
				end
			end
			n = n + 1; buf[n] = '}'
			seen[v] = nil
		end
	else
		n = n + 1; buf[n] = '_' -- functions, userdata and other unsupported values
	end

	return n
end
Write = WriteValue

-- Serializes a list of values (holes and trailing nils are kept).
function Net.Serialize(...)
	local count = select('#', ...)
	local buf = { 'n' .. count .. ';' }
	local n, seen = 1, {}
	for i = 1, count do
		n = WriteValue(buf, n, (select(i, ...)), seen)
	end
	return table.concat(buf, '', 1, n)
end

local Read

local function ReadNumberUntil(s, i, stop)
	local j = string.find(s, stop, i, true)
	return string.sub(s, i, j - 1), j + 1
end

local function ReadValue(s, i, state)
	local c = string.byte(s, i)

	if c == 95 then return nil, i + 1 -- _
	elseif c == 84 then return true, i + 1 -- T
	elseif c == 70 then return false, i + 1 -- F
	elseif c == 110 then -- n
		local text, j = ReadNumberUntil(s, i + 1, ';')
		return tonum(text), j
	elseif c == 115 then -- s
		local j = string.find(s, ':', i + 1, true)
		local len = tonumber(string.sub(s, i + 1, j - 1))
		return string.sub(s, j + 1, j + len), j + len + 1
	elseif c == 101 then -- e
		local text, j = ReadNumberUntil(s, i + 1, ';')
		local index = tonumber(text)
		local ent = Entity(index)
		if index ~= 0 and not IsValid(ent) then state.missing = true end
		return ent, j
	elseif c == 69 then return NULL, i + 1 -- E
	elseif c == 118 or c == 97 then -- v / a
		local text, j = ReadNumberUntil(s, i + 1, ';')
		local x, y, z = string.match(text, '^([^,]+),([^,]+),(.+)$')
		if c == 118 then return Vector(tonum(x), tonum(y), tonum(z)), j end
		return Angle(tonum(x), tonum(y), tonum(z)), j
	elseif c == 99 then -- c
		local text, j = ReadNumberUntil(s, i + 1, ';')
		local r, g, b, a = string.match(text, '^([^,]+),([^,]+),([^,]+),(.+)$')
		return Color(tonumber(r), tonumber(g), tonumber(b), tonumber(a)), j
	elseif c == 123 then -- {
		local t = {}
		i = i + 1
		while string.byte(s, i) ~= 125 do
			local key, value
			key, i = Read(s, i, state)
			value, i = Read(s, i, state)
			if key ~= nil then t[key] = value end
		end
		return t, i + 1
	end

	error('bgNPC.Net: corrupted data at position ' .. tostring(i))
end
Read = ReadValue

-- @return table values, number count, boolean has_missing_entities
function Net.Deserialize(s)
	local state = {}
	local text, i = ReadNumberUntil(s, 2, ';')
	local count = tonumber(text)
	local values = {}
	for k = 1, count do
		values[k], i = ReadValue(s, i, state)
	end
	return values, count, state.missing == true
end

-- ---------------------------------------------------------------------------
-- Transport
-- ---------------------------------------------------------------------------

local receivers = {}
local progress_texts = {}
local message_id = 0

function Net.Receive(name, func, options)
	receivers[name] = { func = func, options = options or {} }
end

function Net.RemoveReceiver(name)
	receivers[name] = nil
end

function Net.SetProgressText(name, text)
	progress_texts[name] = text
end

local function IsAdmin(ply)
	return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function CanReceive(receiver, ply)
	if not receiver then return false end
	if SERVER and receiver.options.admin and not IsAdmin(ply) then return false end
	return true
end

local function Execute(receiver, name, ply, values, count)
	xpcall(receiver.func, function(err)
		ErrorNoHaltWithStack('[Background NPCs] Network callback "' .. name .. '" error: ' .. tostring(err) .. '\n')
	end, ply, unpack(values, 1, count))
end

local function Dispatch(name, ply, payload)
	local receiver = receivers[name]
	if not CanReceive(receiver, ply) then return end

	local ok, values, count, missing = pcall(Net.Deserialize, payload)
	if not ok then
		ErrorNoHaltWithStack('[Background NPCs] Bad network data in "' .. name .. '": ' .. tostring(values) .. '\n')
		return
	end

	if CLIENT and missing and receiver.options.wait_entities then
		local give_up = RealTime() + WAIT_ENTITIES_TIME
		message_id = message_id + 1
		local timer_name = 'bgn_net_wait_' .. message_id
		timer.Create(timer_name, .1, 0, function()
			local _, new_values, new_count, still_missing = pcall(Net.Deserialize, payload)
			if still_missing and RealTime() < give_up then return end
			timer.Remove(timer_name)
			Execute(receiver, name, ply, new_values, new_count)
		end)
		return
	end

	Execute(receiver, name, ply, values, count)
end

local function Progress(id, text, part, total)
	if SERVER or not text or text == '' then return end
	notification.AddProgress(id, text, part / total)
	if part >= total then
		notification.AddProgress(id, '✓ ' .. text, 1)
		timer.Simple(3, function() notification.Kill(id) end)
	end
end

-- Sends one network message with the already prepared header.
local function WriteMessage(name, total, id, part, text, compressed, data, send)
	net.Start(CHANNEL)
	net.WriteString(name)
	net.WriteUInt(total, 16)
	if total > 1 then
		net.WriteUInt(id, 32)
		net.WriteUInt(part, 16)
		net.WriteString(text or '')
	end
	net.WriteBool(compressed)
	net.WriteUInt(#data, 32)
	net.WriteData(data, #data)
	send()
end

local function Transmit(name, send, ...)
	local payload = Net.Serialize(...)
	local compressed = #payload > COMPRESS_FROM
	if compressed then payload = util.Compress(payload) end

	local total = math.ceil(#payload / CHUNK_SIZE)
	if total <= 1 then
		WriteMessage(name, 1, 0, 1, nil, compressed, payload, send)
		return
	end

	message_id = message_id + 1
	local id = message_id
	local text = progress_texts[name]
	local part = 0

	-- One chunk per tick, so big transfers never overflow the reliable channel.
	timer.Create('bgn_net_send_' .. id, 0, total, function()
		part = part + 1
		local chunk = string.sub(payload, (part - 1) * CHUNK_SIZE + 1, part * CHUNK_SIZE)
		WriteMessage(name, total, id, part, text, compressed, chunk, send)
		if CLIENT then Progress('bgn_net_' .. id, text, part, total) end
	end)
end

if SERVER then
	util.AddNetworkString(CHANNEL)

	function Net.Send(name, target, ...)
		if target == nil then
			target = player.GetHumans()
			if #target == 0 then return end
		elseif not istable(target) and not IsValid(target) then
			return
		end

		Transmit(name, function() net.Send(target) end, ...)
	end

	-- Calls a method of the tool object on the client of the tool owner.
	function Net.ToolRPC(tool, method, ...)
		local ply = tool and tool.GetOwner and tool:GetOwner()
		if not IsValid(ply) or not ply:IsPlayer() then return end
		Net.Send('bgn.tool_rpc', ply, tool:GetMode(), method, ...)
	end

	-- Shared code may call it on both realms; like slib, the wrong realm is a no-op.
	function Net.SendToServer() end
else
	function Net.Send() end
	function Net.ToolRPC() end

	function Net.SendToServer(name, ...)
		Transmit(name, net.SendToServer, ...)
	end

	Net.Receive('bgn.tool_rpc', function(_, mode, method, ...)
		local tool = LocalPlayer():GetTool(mode)
		if tool and tool[method] then tool[method](tool, ...) end
	end)
end

-- Incoming chunked messages: sender -> id -> buffer
local buffers = {}
local rate = {}

net.Receive(CHANNEL, function(_, ply)
	if SERVER then
		local now = RealTime()
		local r = rate[ply]
		if not r or r.reset < now then
			r = { count = 0, reset = now + 1 }
			rate[ply] = r
		end
		r.count = r.count + 1
		if r.count > CLIENT_RATE_LIMIT then return end
	end

	local name = net.ReadString()
	-- Drop data nobody listens to before buffering anything.
	if not CanReceive(receivers[name], ply) then return end

	local total = net.ReadUInt(16)
	local id, part, text = 0, 1, nil
	if total > 1 then
		id = net.ReadUInt(32)
		part = net.ReadUInt(16)
		text = net.ReadString()
	end

	local compressed = net.ReadBool()
	local data = net.ReadData(net.ReadUInt(32))

	if total > 1 then
		local sender = SERVER and ply or 'server'
		buffers[sender] = buffers[sender] or {}
		local buffer = buffers[sender][id]
		if not buffer then
			buffer = { parts = {}, count = 0 }
			buffers[sender][id] = buffer
		end

		if not buffer.parts[part] then
			buffer.parts[part] = data
			buffer.count = buffer.count + 1
		end
		buffer.expire = RealTime() + CHUNK_LIFETIME

		Progress('bgn_net_' .. id, text, buffer.count, total)
		if buffer.count < total then return end

		buffers[sender][id] = nil
		data = table.concat(buffer.parts, '', 1, total)
	end

	if compressed then
		data = util.Decompress(data)
		if not data then return end
	end

	Dispatch(name, ply, data)
end)

timer.Create('bgn_net_buffers_cleanup', 5, 0, function()
	local now = RealTime()
	for sender, list in pairs(buffers) do
		if sender ~= 'server' and not IsValid(sender) then
			buffers[sender] = nil
		else
			for id, buffer in pairs(list) do
				if buffer.expire < now then list[id] = nil end
			end
		end
	end

	for ply in pairs(rate) do
		if not IsValid(ply) then rate[ply] = nil end
	end
end)
