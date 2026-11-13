local bgNPC = bgNPC
local IsValid = IsValid
local pairs = pairs
local istable = istable
local GetConVar = GetConVar
local CurTime = CurTime
local isbool = isbool
local table_insert = table.insert
--

--[[
	Spawn Area / Zone system.

	Each area is an AABB (startPoint/endPoint). Per actor type inside `area.actors`
	one of three modes can be set:
	  - 'default' (or no entry at all): normal global spawn/despawn rules apply,
	    the zone has no effect on this type.
	  - 'blocked': this actor type will never spawn or be teleported inside the
	    area (this is the only thing the old spawn-area tool used to support).
	  - 'boosted': the zone actively tries to keep `count` alive actors of this
	    type inside its bounds at all times, on top of whatever spawns normally
	    elsewhere on the map. Actors that wander out of the area are simply left
	    alone - the normal global despawn rules (distance/visibility) apply to
	    them exactly like any other actor, and the zone will just top itself
	    back up to `count`.
--]]

bgNPC.SPAWN_AREA_MODE_DEFAULT = 'default'
bgNPC.SPAWN_AREA_MODE_BLOCKED = 'blocked'
bgNPC.SPAWN_AREA_MODE_BOOSTED = 'boosted'

local AREA_MODE_DEFAULT = bgNPC.SPAWN_AREA_MODE_DEFAULT
local AREA_MODE_BLOCKED = bgNPC.SPAWN_AREA_MODE_BLOCKED
local AREA_MODE_BOOSTED = bgNPC.SPAWN_AREA_MODE_BOOSTED

local valid_modes = {
	[AREA_MODE_DEFAULT] = true,
	[AREA_MODE_BLOCKED] = true,
	[AREA_MODE_BOOSTED] = true
}

local file_path = 'background_npcs/spawn_area/' .. game.GetMap() .. '.dat'

local function SanitizeAreaActors(actors)
	local sanitized = {}

	if istable(actors) then
		for actorType, value in pairs(actors) do
			if istable(value) then
				-- Current format: { mode = 'default'|'blocked'|'boosted', count = number }
				local mode = value.mode
				if not valid_modes[mode] then mode = AREA_MODE_DEFAULT end

				local count = math.Clamp(math.floor(tonumber(value.count) or 0), 0, 200)

				if mode ~= AREA_MODE_DEFAULT then
					sanitized[actorType] = { mode = mode, count = count }
				end
			elseif value == false then
				-- Legacy format from the old tool: `false` meant "blocked"
				sanitized[actorType] = { mode = AREA_MODE_BLOCKED, count = 0 }
			end
		end
	end

	return sanitized
end

function bgNPC:LoadSpawnAreas()
	local areas = {}

	if SERVER and file.Exists(file_path, 'DATA') then
		local readData = file.Read(file_path, 'DATA')
		local ok, decoded = pcall(util.JSONToTable, readData)

		if ok and istable(decoded) then
			for areaName, area in pairs(decoded) do
				if istable(area) and isvector(area.startPoint) and isvector(area.endPoint) then
					areas[areaName] = {
						name = areaName,
						startPoint = area.startPoint,
						endPoint = area.endPoint,
						actors = SanitizeAreaActors(area.actors)
					}
				end
			end
		end
	end

	bgNPC.SpawnArea = areas

	return areas
end

if SERVER then
	if not file.Exists('background_npcs/spawn_area', 'DATA') then
		file.CreateDir('background_npcs/spawn_area')
	end

	function bgNPC:SaveSpawnAreas()
		file.Write(file_path, util.TableToJSON(bgNPC.SpawnArea, true))
	end

	function bgNPC:SetSpawnArea(areaName, startPoint, endPoint, actors)
		if not isstring(areaName) or #areaName == 0 then return end
		if not isvector(startPoint) or not isvector(endPoint) then return end

		local area = {
			name = areaName,
			startPoint = startPoint,
			endPoint = endPoint,
			actors = SanitizeAreaActors(actors)
		}

		bgNPC.SpawnArea[areaName] = area
		bgNPC:SaveSpawnAreas()

		return area
	end

	function bgNPC:RemoveSpawnArea(areaName)
		if not bgNPC.SpawnArea[areaName] then return false end
		bgNPC.SpawnArea[areaName] = nil
		bgNPC:SaveSpawnAreas()
		return true
	end
end

function bgNPC:GetSpawnAreas()
	return bgNPC.SpawnArea
end

function bgNPC:GetSpawnArea(areaName)
	return bgNPC.SpawnArea[areaName]
end

function bgNPC:GetAreaActorMode(area, actorType)
	local entry = area.actors[actorType]
	if not entry then return AREA_MODE_DEFAULT, 0 end
	return entry.mode, entry.count
end

function bgNPC:GetSpawnAreasAtPosition(position)
	local list = {}

	for _, area in pairs(bgNPC.SpawnArea) do
		if position:WithinAABox(area.startPoint, area.endPoint) then
			table_insert(list, area)
		end
	end

	return list
end

-- Kept as its own function (rather than folded into the zone-boost spawner
-- below) because it's a hot-path gate called from both the normal spawner
-- and the actor teleporter/despawn-avoidance path.
function bgNPC:IsValidSpawnArea(actorType, spawnPosition)
	for _, area in pairs(bgNPC.SpawnArea) do
		if spawnPosition:WithinAABox(area.startPoint, area.endPoint) then
			local mode = bgNPC:GetAreaActorMode(area, actorType)
			if mode == AREA_MODE_BLOCKED then
				return false
			end
		end
	end

	return true
end

bgNPC:LoadSpawnAreas()

if SERVER then
	local function CountAliveInArea(area, actorType)
		local count = 0
		local actors = bgNPC:GetAllByType(actorType)

		for i = 1, #actors do
			local actor = actors[i]

			if actor:IsAlive() then
				local npc = actor:GetNPC()
				if IsValid(npc) and npc:GetPos():WithinAABox(area.startPoint, area.endPoint) then
					count = count + 1
				end
			end
		end

		return count
	end

	local function FindSpawnPositionInArea(area)
		local center = (area.startPoint + area.endPoint) / 2
		local radius = center:Distance(area.startPoint) + 1

		for _ = 1, 5 do
			local position = bgNPC:FindSpawnPositionAsync({ position = center, radius = radius })
			if position and position:WithinAABox(area.startPoint, area.endPoint) then
				return position
			end
		end
	end

	-- Same gating rules the normal spawner applies per actor type (active/limit/
	-- wanted level/validator/respawn delay), reused here so a boosted zone can't
	-- bypass them (e.g. force wanted-only actors to camp a zone with no chase
	-- going on, or ignore an admin-set per-type max).
	local function CanActorTypeSpawnNow(npc_type, npc_data)
		if not bgNPC:IsActiveNPCType(npc_type) or npc_data.hidden then return false end

		local max_limit = bgNPC:GetLimitActors(npc_type)
		if max_limit == 0 or #bgNPC:GetAllNPCsByType(npc_type) >= max_limit then return false end

		if npc_data.wanted_level then
			local asset = bgNPC:GetModule('wanted')
			local wanted_list = asset:GetAllWanted()
			local has_target = false

			for i = #wanted_list, 1, -1 do
				local WantedClass = wanted_list[i]
				if WantedClass and IsValid(WantedClass.target) and WantedClass.level >= npc_data.wanted_level then
					has_target = true
					break
				end
			end

			if not has_target then return false end
		end

		if npc_data.validator then
			local result = npc_data.validator(npc_data, npc_type)
			if isbool(result) and not result then return false end
		end

		local spawn_delayer = bgNPC.respawn_actors_delay[npc_type]
		if npc_data.respawn_delay and spawn_delayer and spawn_delayer.count ~= 0 then
			if spawn_delayer.time < CurTime() then
				spawn_delayer.time = CurTime() + npc_data.respawn_delay
				spawn_delayer.count = spawn_delayer.count - 1
			else
				return false
			end
		end

		return true
	end

	local zone_spawner_timer_name = 'BGN_ZoneActorsSpawnerProcess'

	local function InitZoneBoostSpawner(delay)
		async.AddDedic('bgn_zone_actors_spawner_process', function(yield, wait)
			while true do
				wait(delay)

				if not GetConVar('bgn_enable'):GetBool() or player.GetCount() == 0 then continue end

				for _, area in pairs(bgNPC.SpawnArea) do
					yield()

					for actorType, entry in pairs(area.actors) do
						yield()

						if entry.mode ~= AREA_MODE_BOOSTED or entry.count <= 0 then continue end

						local npc_data = bgNPC.cfg.actors[actorType]
						if not npc_data then continue end
						if not CanActorTypeSpawnNow(actorType, npc_data) then continue end
						if CountAliveInArea(area, actorType) >= entry.count then continue end

						yield()

						local position = FindSpawnPositionInArea(area)
						if position then
							bgNPC:ActorSpawnOnPosition(actorType, position)
						end
					end
				end
			end
		end)
	end

	InitZoneBoostSpawner(GetConVar('bgn_spawn_period'):GetFloat())

	cvars.AddChangeCallback('bgn_spawn_period', function(_, _, new_value)
		InitZoneBoostSpawner(tonumber(new_value))
	end, zone_spawner_timer_name)
end
