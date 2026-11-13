--[[
	Source:
	https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/sandbox/entities/weapons/gmod_tool/stools/duplicator/arming.lua
--]]

local DUPE_SEND_SIZE = 60000

if CLIENT then
	local LastDupeArm = 0

	local function CustomCommandHandler(ply, cmd, arg)
		if not arg[1] then return end

		if LastDupeArm > CurTime() and not game.SinglePlayer() then
			ply:ChatPrint('Please wait a second before trying to load another duplication!')
			return
		end

		LastDupeArm = CurTime() + 1

		local res = hook.Run('CanArmDupe', ply)
		if res == false then
			ply:ChatPrint('Refusing to load dupe, server has blocked usage of the Duplicator tool!')
			return
		end

		local dupe = engine.OpenDupe(arg[1])
		if not dupe then
			ply:ChatPrint('Error loading dupe.. (' .. tostring(arg[1]) .. ')')
			return
		end

		local uncompressed = util.Decompress(dupe.data, 5242880)
		if not uncompressed then
			ply:ChatPrint('That dupe seems to be corrupted!')
			return
		end

		local Dupe = util.JSONToTable(uncompressed)
		if Dupe.slibrary then
			local dupeId = Dupe.id
			local dupeData = Dupe.data

			if hook.Run('OnLoadDuplicator', ply, dupeId, dupeData) == false then
				return
			end
		end

		local length = dupe.data:len()
		local parts = math.ceil(length / DUPE_SEND_SIZE)
		local start = 0

		for i = 1, parts do
			local endbyte = math.min(start + DUPE_SEND_SIZE, length)
			local size = endbyte - start
			net.Start('ArmDupe')
			net.WriteUInt(i, 8)
			net.WriteUInt(parts, 8)
			net.WriteUInt(size, 32)
			net.WriteData(dupe.data:sub(start + 1, endbyte + 1), size)
			net.SendToServer()
			start = endbyte
		end
	end

	hook.Add('slib.OnCallCommand', 'Slib.CustomDuplicator.Override', function(commandName, ply, cmd, arg)
		if commandName ~= 'dupe_arm' then return end
		CustomCommandHandler(ply, cmd, arg)
		return false
	end)
else
	local function CustomNetworkHandler(size, client)
		if not IsValid(client) or size < 48 then return end
		local res = hook.Run('CanArmDupe', client)

		if res == false then
			client:ChatPrint('Server has blocked usage of the Duplicator tool!')
			return
		end

		local part = net.ReadUInt(8)
		local total = net.ReadUInt(8)
		local length = net.ReadUInt(32)
		if length > DUPE_SEND_SIZE then return end

		local data = net.ReadData(length)
		client.CurrentDupeBuffer = client.CurrentDupeBuffer or {}
		client.CurrentDupeBuffer[part] = data
		if part ~= total then return end

		data = table.concat(client.CurrentDupeBuffer)
		client.CurrentDupeBuffer = nil

		if (client.LastDupeArm or 0) > CurTime() and not game.SinglePlayer() then
			ServerLog(tostring(client) .. ' tried to arm a dupe too quickly!\n')
			return
		end

		client.LastDupeArm = CurTime() + 1
		ServerLog(tostring(client) .. ' is arming a dupe, size: ' .. data:len() .. '\n')
		local uncompressed = util.Decompress(data, 5242880)

		if not uncompressed then
			client:ChatPrint('Server failed to decompress the duplication!')
			MsgN('Couldn\'t decompress dupe from ' .. client:Nick() .. '!')
			return
		end

		local Dupe = util.JSONToTable(uncompressed)
		if not istable(Dupe) then return end

		if Dupe.slibrary then
			local dupeId = Dupe.id
			local dupeData = Dupe.data

			if hook.Run('OnLoadDuplicator', client, dupeId, dupeData) == false then
				return
			end
		end

		if not istable(Dupe.Constraints) then return end
		if not istable(Dupe.Entities) then return end
		if not isvector(Dupe.Mins) then return end
		if not isvector(Dupe.Maxs) then return end

		client.CurrentDupeArmed = true
		client.CurrentDupe = Dupe
		client:ConCommand('gmod_tool duplicator')

		local workshopCount = 0
		if Dupe.RequiredAddons then
			workshopCount = #Dupe.RequiredAddons
		end

		net.Start('CopiedDupe')
		net.WriteUInt(0, 1) -- Can save
		net.WriteVector(Dupe.Mins)
		net.WriteVector(Dupe.Maxs)
		net.WriteString('Loaded dupe')
		net.WriteUInt(table.Count(Dupe.Entities), 24)
		net.WriteUInt(workshopCount, 16)

		if Dupe.RequiredAddons then
			for _, wsid in ipairs(Dupe.RequiredAddons) do
				net.WriteString(wsid)
			end
		end

		net.Send(client)
	end

	hook.Add('slib.OnCallNetMessage', 'Slib.CustomDuplicator.Override', function(messageName, size, client)
		if messageName ~= 'ArmDupe' then return end
		CustomNetworkHandler(size, client)
		return false
	end)
end