local Assert = bgNPC.Assert
local Util = bgNPC.Util
local Config = bgNPC.Config
--

local resolved_cache = {}
local resolving = {}
local defaults_snapshot

local function CopyValue(value)
	return istable(value) and table.Copy(value) or value
end

-- Resolves "@type" references: a string value "@police@citizen" is replaced
-- with the same field from the referenced actor types. Tables are merged.
local function ResolveFieldReferences(actor_type, data)
	for key, value in pairs(data) do
		if isstring(value) and string.StartWith(value, '@') then
			local resolved = false

			for _, ref_type in ipairs(string.Explode('@', string.Replace(value, ' ', ''))) do
				if #ref_type ~= 0 and ref_type ~= actor_type then
					local ref_data = Config.GetActor(ref_type)
					local ref_value = ref_data and ref_data[key]

					if ref_value ~= nil then
						if not resolved then
							data[key] = CopyValue(ref_value)
							resolved = true
						elseif istable(data[key]) and istable(ref_value) then
							local target = data[key]
							for ref_key, ref_item in pairs(ref_value) do
								if isnumber(ref_key) then
									table.insert(target, ref_item)
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

-- Returns the actor config with "inherit" and "@type" references resolved.
-- @param actor_type string
-- @return table|nil config (shared cached table, copy it before changing)
function Config.GetActor(actor_type)
	Assert.Arg(1, actor_type, 'string', 'bgNPC.Config.GetActor')

	local cached = resolved_cache[actor_type]
	if cached then return cached end

	local source = bgNPC.cfg.actors[actor_type]
	if not source then return end

	if resolving[actor_type] then
		ErrorNoHalt('[Background NPCs] Circular actor config inheritance: ' .. actor_type .. '\n')
		return
	end

	resolving[actor_type] = true

	local data = table.Copy(source)
	local parent_type = data.inherit

	if parent_type and parent_type ~= actor_type then
		local parent_data = Config.GetActor(parent_type)
		if parent_data then
			Util.Log('Data Inherit - ' .. parent_type, 'Config.GetActor')

			for parent_key, parent_value in pairs(parent_data) do
				if parent_key ~= 'inherit' and data[parent_key] == nil then
					data[parent_key] = CopyValue(parent_value)
				end
			end
		end
	end

	ResolveFieldReferences(actor_type, data)

	resolving[actor_type] = nil
	resolved_cache[actor_type] = data

	return data
end

-- Returns the list of all actor types from the config.
function Config.GetActorTypes()
	local types = {}
	for actor_type in pairs(bgNPC.cfg.actors) do
		types[#types + 1] = actor_type
	end
	return types
end

function Config.ActorExists(actor_type)
	return bgNPC.cfg.actors[actor_type] ~= nil
end

-- Drops the resolved configs cache. Call it after changing bgNPC.cfg.actors.
function Config.ClearCache()
	resolved_cache = {}
end

-- Remembers the current actor configs as defaults for Config.Reset.
function Config.SaveDefaults()
	defaults_snapshot = table.Copy(bgNPC.cfg.actors)
end

-- Restores the actor configs saved by Config.SaveDefaults.
function Config.Reset()
	if not defaults_snapshot then return end
	bgNPC.cfg.actors = table.Copy(defaults_snapshot)
	Config.ClearCache()
end

-- The wanted level that summons the type, or nil when the wanted system can't reach it (wanted mode off, or
-- level growth off and the level is above 1): then the type spawns like any other actor.
function Config.GetWantedLevel(data)
	local level = data and data.wanted_level
	if not level then return end
	local mode, growth = Util.GetCVar('bgn_enable_wanted_mode'), Util.GetCVar('bgn_wanted_level')
	if not (mode and mode:GetBool()) then return end
	if level > 1 and not (growth and growth:GetBool()) then return end
	return level
end

-- Is the actor type enabled by its "bgn_npc_type_<type>" console variable.
function Config.IsTypeActive(actor_type)
	Assert.Arg(1, actor_type, 'string', 'bgNPC.Config.IsTypeActive')
	local cvar = Util.GetCVar('bgn_npc_type_' .. actor_type)
	return cvar ~= nil and cvar:GetBool()
end

-- Default maximum of actors of the type, from "fullness" (percent of bgn_max_npc) or "limit".
function Config.GetFullness(actor_type)
	Assert.Arg(1, actor_type, 'string', 'bgNPC.Config.GetFullness')

	local data = bgNPC.cfg.actors[actor_type]
	if not data then return 0 end

	if data.fullness ~= nil then
		local cvar_max = Util.GetCVar('bgn_max_npc')
		local max_npc = cvar_max and cvar_max:GetInt() or 0
		local max = math.Round((data.fullness / 100) * max_npc)
		if max >= 0 then return max end
	elseif data.limit ~= nil then
		return math.Round(data.limit)
	end

	return 0
end

-- Current maximum of actors of the type, from "bgn_npc_type_max_<type>".
function Config.GetTypeLimit(actor_type)
	Assert.Arg(1, actor_type, 'string', 'bgNPC.Config.GetTypeLimit')
	local cvar = Util.GetCVar('bgn_npc_type_max_' .. actor_type)
	return cvar and cvar:GetInt() or 0
end
