local bgNPC = bgNPC
local Assert = bgNPC.Assert
local IsValid = IsValid
local isnumber = isnumber
local math_cos = math.cos
local math_rad = math.rad
local util_TraceLine = util.TraceLine
local pairs = pairs
local ipairs = ipairs
local istable = istable
local isstring = isstring
local string_StartWith = string.StartWith
local table_Copy = table.Copy
local table_HasValueBySeq = table.HasValueBySeq
local string_Replace = string.Replace
local string_Explode = string.Explode
local table_insert = table.insert
--
local cvar_bgn_debug = GetConVar('bgn_debug')
local actors_config_cache = {}

function bgNPC:ClearActorsConfig()
	actors_config_cache = {}
end

-- Resolves "@type" references: a string value "@police@citizen" is replaced
-- with the same field from the referenced actor types.
local function ResolveFieldReferences(actor_type, data)
	for key, value in pairs(data) do
		if isstring(value) and string_StartWith(value, '@') then
			local resolved = false

			for _, ref_type in ipairs(string_Explode('@', string_Replace(value, ' ', ''))) do
				if #ref_type ~= 0 and ref_type ~= actor_type then
					local ref_data = bgNPC:GetActorConfig(ref_type)
					local ref_value = ref_data and ref_data[key]

					if ref_value ~= nil then
						if not resolved then
							data[key] = istable(ref_value) and table_Copy(ref_value) or ref_value
							resolved = true
						elseif istable(data[key]) and istable(ref_value) then
							local target = data[key]
							for ref_key, ref_item in pairs(ref_value) do
								if isnumber(ref_key) then
									table_insert(target, ref_item)
								elseif target[ref_key] == nil then
									target[ref_key] = ref_item
								end
							end
						end
					end
				end
			end

			if not resolved then data[key] = nil end
		end
	end
end

local resolving = {}

-- Returns the actor config with "inherit" and "@type" references resolved.
-- @param actor_type string
-- @return table|nil config (shared cached table, copy it before changing)
function bgNPC:GetActorConfig(actor_type)
	Assert.Arg(1, actor_type, 'string', 'bgNPC:GetActorConfig')

	local cached = actors_config_cache[actor_type]
	if cached then return cached end

	local source = bgNPC.cfg.actors[actor_type]
	if not source then return end

	if resolving[actor_type] then
		ErrorNoHalt('[Background NPCs] Circular actor config inheritance: ' .. actor_type .. '\n')
		return
	end

	resolving[actor_type] = true

	local data = table_Copy(source)

	if data.inherit and data.inherit ~= actor_type then
		local inherit_data = bgNPC:GetActorConfig(data.inherit)
		if inherit_data then
			bgNPC:Log('Data Inherit - ' .. data.inherit, 'GetActorConfig')

			for inherit_key, inherit_value in pairs(inherit_data) do
				if inherit_key ~= 'inherit' and data[inherit_key] == nil then
					data[inherit_key] = istable(inherit_value) and table_Copy(inherit_value) or inherit_value
				end
			end
		end
	end

	ResolveFieldReferences(actor_type, data)

	resolving[actor_type] = nil
	actors_config_cache[actor_type] = data

	return data
end

function bgNPC:Log(message, tag)
	if not cvar_bgn_debug:GetBool() then return end
	if tag ~= nil then
		MsgN('[Background NPCs][' .. tostring(tag) .. '] ' .. tostring(message))
	else
		MsgN('[Background NPCs] ' .. tostring(message))
	end
end

function bgNPC:PlayerIsViewVector(ply, pos, radius)
	return ply:slibIsViewVector(pos, radius)
end

-- Checks whether the position is inside the NPC's field of view.
-- @param fov number|nil half-angle of the view cone in degrees (default 90)
function bgNPC:NPCIsViewVector(ent, pos, fov)
	Assert.Arg(2, pos, 'vector', 'bgNPC:NPCIsViewVector')
	Assert.Arg(3, fov, 'number|nil', 'bgNPC:NPCIsViewVector')

	if not IsValid(ent) or ent:Health() <= 0 then return false end
	if not ent:IsNPC() then return true end

	local direction = pos - ent:GetShootPos()
	local length = direction:Length()
	if length == 0 then return true end

	return ent:GetAimVector():Dot(direction) / length >= math_cos(math_rad(fov or 90))
end

local function CanSee(actor, ent)
	if not actor or not actor:IsAlive() then return false end
	local npc = actor:GetNPC()
	return IsValid(npc) and npc:slibIsTraceEntity(ent, 1000, true)
end

-- Checks whether any actor sees the entity.
-- @param ent entity
-- @param exclude actor|table|nil actor or list of actors to skip
-- @return boolean, actor|nil
function bgNPC:CanAnyActorSeeEntity(ent, exclude)
	if not IsValid(ent) then return false end

	if istable(exclude) and exclude.isBgnClass then exclude = { exclude } end
	local has_exclude = istable(exclude) and #exclude ~= 0

	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if not (has_exclude and table_HasValueBySeq(exclude, actor)) and CanSee(actor, ent) then
			return true, actor
		end
	end

	return false
end

-- Returns all actors that see the entity.
-- @return boolean, table
function bgNPC:CanActorsSeeEntity(ent)
	if not IsValid(ent) then return false, {} end

	local actors = bgNPC:GetAll()
	local valid_actors = {}

	for i = 1, #actors do
		local actor = actors[i]
		if CanSee(actor, ent) then
			valid_actors[#valid_actors + 1] = actor
		end
	end

	return #valid_actors ~= 0, valid_actors
end

function bgNPC:GetModule(module_name)
	Assert.Arg(1, module_name, 'string', 'bgNPC:GetModule')
	return list.GetForEdit('BGN_Modules')[module_name]
end

-- Checks a direct line of sight from the watcher's eyes to the entity's center.
-- @return boolean visible, entity hit entity
function bgNPC:IsTargetRay(watcher, ent)
	if not IsValid(watcher) or watcher:Health() <= 0 then return false end
	if not IsValid(ent) or ent:Health() <= 0 then return false end

	local tr = util_TraceLine({
		start = watcher:EyePos(),
		endpos = ent:WorldSpaceCenter(),
		filter = watcher,
	})

	return tr.Hit and tr.Entity == ent, tr.Entity
end

function bgNPC:GetActivePlayerTool(tool_name, ply)
	if not tool_name or not isstring(tool_name) then return end

	if not IsValid(ply) then
		if SERVER then return end
		ply = LocalPlayer()
	end

	local tool = ply:GetTool()
	if not tool or not isfunction(tool.GetMode) or tool:GetMode() ~= tool_name then return end
	return tool
end

do
	local npcs_template_copy = table_Copy(bgNPC.cfg.actors)
	function bgNPC:ResetConfiguration()
		bgNPC.cfg.actors = table_Copy(npcs_template_copy)
	end
end