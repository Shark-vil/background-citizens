local function UpdateServerConfig()
	local npcList = list.Get('NPC')

	for npcClass, actorTypesList in pairs(bgNPC.SpawnMenu.Creator['NPC']) do
		for _, actorType in ipairs(actorTypesList) do
			local data = bgNPC.cfg.npcs_template[actorType]
			if data then
				local listData = npcList[npcClass]
				local class = listData.Class or npcClass
				local model = listData.Model

				if isstring(data.class) then
					local saveDataClass = data.class
					data.class = { saveDataClass }
				end

				table.InsertNoValue(data.class, class)

				if model then
					data.models = data.models or {}
					table.InsertNoValue(data.models, model)
				end
			end
		end
	end
end

local function UpdateDataFile()
	local data = bgNPC.SpawnMenu.Creator['NPC']
	local writeData = util.Compress(util.TableToJSON(data, true))
	file.Write('background_npcs/custom.dat', writeData)
end

local function ReadDataFile()
	if not file.Exists('background_npcs/custom.dat', 'DATA') then return end

	local readData = file.Read('background_npcs/custom.dat', 'DATA')
	local data = util.JSONToTable(util.Decompress(readData))

	return data
end

local function IsValidActosConfig(actorType)
	if not actorType then return false end
	if not bgNPC or not bgNPC.cfg or not bgNPC.cfg.npcs_template then return false end
	if not bgNPC.cfg.npcs_template[actorType] then return false end
	return true
end

snet.Callback('BGN_ActorSpawnmenu', function(ply, actorType)
	if not IsValid(ply) or not IsValidActosConfig(actorType) then return end

	local tr = ply:GetEyeTrace()
	if not tr or not tr.Hit then return end

	local actor = bgNPC:SpawnActor(actorType, tr.HitPos + Vector(0, 0, 10))
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end

	actor.eternal = true

	DoPropSpawnedEffect(npc)

	undo.Create('Actor')
	undo.SetPlayer(ply)
	undo.AddEntity(npc)
	undo.Finish('Actor ( ' .. actorType .. ' )')

	ply:AddCleanup('npcs', npc)
end)

snet.Callback('BGN_ActorSpawnmenuToolSpawner', function(ply, actorType)
	if not IsValid(ply) or not IsValidActosConfig(actorType) then return end

	local gmod_tool_weapon = ply:GetWeapon('gmod_tool')
	if not IsValid(gmod_tool_weapon) then
		gmod_tool_weapon = ply:Give('gmod_tool')
	end

	if IsValid(gmod_tool_weapon) then
		ply:SelectWeapon(gmod_tool_weapon)
		ply:ConCommand('"gmod_tool" "bgn_actor_spawner"')

		local toolData = ply:GetTool('bgn_actor_spawner')
		if not toolData then return end

		toolData.actorType = actorType
	end
end)

snet.Callback('BGN_ActorSpawnmenuToolSpecificSpawner', function(ply, npcClass, actorType)
	local tbl = bgNPC.SpawnMenu.Creator['NPC']
	tbl[npcClass] = tbl[npcClass] or {}

	if not actorType then
		tbl[npcClass] = nil
	elseif not table.HasValueBySeq(tbl[npcClass], actorType) then
		table.insert(tbl[npcClass], actorType)
	end

	UpdateDataFile()
	UpdateServerConfig()
end).Protect()

snet.Callback('BGN_ActorSpawnmenuResetSpawner', function(ply, actorType)
	local tbl = bgNPC.SpawnMenu.Creator['NPC']

	if isbool(actorType) then
		if actorType == true then
			bgNPC:ResetConfiguration()
			bgNPC.SpawnMenu.Creator['NPC'] = {}
		end
	elseif isstring(actorType) then
		for npcClass, actorTypesList in pairs(tbl) do
			table.RemoveValueBySeq(actorTypesList, actorType)
		end

		UpdateServerConfig()
	end

	UpdateDataFile()
end).Protect()

snet.Callback('BGN_ActorSpawnmenuToolDefaultSpawner', function(ply, actorType)
	local tbl = bgNPC.SpawnMenu.Creator['Default']
	tbl[ply] = actorType
end)

hook.Add('PlayerSpawnedNPC', 'BGN_SpawnMenuChecker', function(ply, npc)
	timer.Simple(0, function()
		if not IsValid(npc) or not IsValid(ply) then return end

		local defaultTable = bgNPC.SpawnMenu.Creator['Default']
		if not defaultTable[ply] then return end

		local actorType = defaultTable[ply]

		if not actorType or not isstring(actorType) then return end
		if not bgNPC.cfg.npcs_template[actorType] then return end

		local actor = BGN_ACTOR:Instance(npc, actorType)
		if actor then actor.eternal = true end
	end)
end)

do
	local readData = ReadDataFile()
	if readData then
		bgNPC.SpawnMenu.Creator['NPC'] = readData
		UpdateServerConfig()
	end
end