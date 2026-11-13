local snet = slib.Components.Network
local SERVER = SERVER
local timer = timer
local istable = istable
local ipairs = ipairs
local isfunction = isfunction
local isentity = isentity
local IsValid = IsValid
local isbool = isbool
local unpack = unpack
local LocalPlayer = LocalPlayer
local player_GetAll = player.GetAll
local util_TraceLine = util.TraceLine
local table_InsertOrReplace = table.InsertOrReplace
local table_insert = table.insert
local table_HasValueBySeq = table.HasValueBySeq
local timer_Exists = timer.Exists
local timer_Remove = timer.Remove
local timer_Create = timer.Create
local timer_Simple = timer.Simple
local hook_Remove = hook.Remove
local util_CRC = util.CRC
local math_pi = math.pi
local ColorAlpha = ColorAlpha
local RENDERMODE_TRANSCOLOR = RENDERMODE_TRANSCOLOR
local RealTime = RealTime
--
local meta = FindMetaTable('Entity')

function meta:slibSetLocalVar(key, value)
	self.slibLocalVariables = self.slibLocalVariables or {}
	self.slibLocalVariables[key] = value
	return self.slibLocalVariables[key]
end

-- function meta:slibGetLocalVar(key, fallback, assign_a_fallback)
-- 	if not self.slibLocalVariables or self.slibLocalVariables[key] == nil then
-- 		if assign_a_fallback and fallback ~= nil then
-- 			return self:slibSetVar(key, fallback)
-- 		end
-- 		return fallback
-- 	end
-- 	return self.slibLocalVariables[key]
-- end

function meta:slibGetLocalVar(key, fallback)
	if not self.slibLocalVariables or self.slibLocalVariables[key] == nil then
		return fallback
	end
	return self.slibLocalVariables[key]
end

function meta:slibSetVar(key, value, unreliable)
	if not snet.ValueIsValid(value) then return end

	self.slibVariables = self.slibVariables or {}
	self.slibVariablesChangeCallback = self.slibVariablesChangeCallback or {}
	self.slibVariablesSetCallback = self.slibVariablesSetCallback or {}
	self.slibVariablesInstanceCallback = self.slibVariablesInstanceCallback or {}

	if not self or not istable(self.slibVariables) then return end

	local old_value = self.slibVariables[key]
	local new_value = value

	if old_value ~= nil and old_value == new_value then return end

	if old_value ~= nil and old_value ~= new_value and self.slibVariablesChangeCallback[key] ~= nil then
		for _, func in ipairs(self.slibVariablesChangeCallback[key]) do
			func(old_value, new_value)
		end
	end

	if self.slibVariables[key] == nil and self.slibVariablesInstanceCallback[key] then
		for _, func in ipairs(self.slibVariablesInstanceCallback[key]) do
			func(new_value)
		end
	end

	self.slibVariables[key] = new_value

	if self.slibVariablesSetCallback[key] then
		for _, func in ipairs(self.slibVariablesSetCallback[key]) do
			func(old_value, new_value)
		end
	end

	if SERVER then
		unreliable = unreliable or false

		if new_value == nil then
			snet.Request('slib_entity_variable_del', self, key).InvokeAll(unreliable)
		else
			snet.Request('slib_entity_variable_set', self, key, value).InvokeAll(unreliable)
		end
	end

	return self.slibVariables[key]
end

do
	local RecursiveSetPreventTransmit

	function RecursiveSetPreventTransmit(ent, ply, stopTransmitting)
		ent:SetPreventTransmit(ply, stopTransmitting)
		local childrens = ent:GetChildren()
		local childrens_count = #childrens
		if childrens_count == 0 then return end
		for children_index = 1, childrens_count do
			local children_entity = childrens[children_index]
			RecursiveSetPreventTransmit(children_entity, ply, stopTransmitting)
		end
	end

	function meta:SetTransmit(obj, stopTransmitting)
		if CLIENT then
			ErrorNoHalt('It\'s a server function')
			return
		end
		local players
		if IsEntity(obj) then
			players = { obj }
		elseif istable(obj) then
			players = obj
		end
		if not players then return end
		local players_count = #players
		if players_count == 0 then return end
		for player_index = 1, players_count do
			local ply = players[player_index]
			if IsValid(ply) and ply:IsPlayer() then
				RecursiveSetPreventTransmit(self, ply, stopTransmitting)
			end
		end
	end
end

function meta:slibGetVar(key, fallback, assign_a_fallback)
	if not self.slibVariables or self.slibVariables[key] == nil then
		if assign_a_fallback and fallback ~= nil then
			return self:slibSetVar(key, fallback)
		end
		return fallback
	end
	return self.slibVariables[key]
end

function meta:slibOnInstanceVarCallback(key, func)
	if not isfunction(func) then return end
	self.slibVariablesInstanceCallback = self.slibVariablesInstanceCallback or {}
	self.slibVariablesInstanceCallback[key] = self.slibVariablesInstanceCallback[key] or {}
	table_insert(self.slibVariablesInstanceCallback[key], func)
end

function meta:slibAddSetVarCallback(key, func)
	if not isfunction(func) then return end
	self.slibVariablesSetCallback = self.slibVariablesSetCallback or {}
	self.slibVariablesSetCallback[key] = self.slibVariablesSetCallback[key] or {}
	table_insert(self.slibVariablesSetCallback[key], func)
end

function meta:slibAddChangeVarCallback(key, func)
	if not isfunction(func) then return end
	self.slibVariablesChangeCallback = self.slibVariablesChangeCallback or {}
	self.slibVariablesChangeCallback[key] = self.slibVariablesChangeCallback[key] or {}
	table_insert(self.slibVariablesChangeCallback[key], func)
end

function meta:slibCreateTimer(timer_name, delay, repetitions, func)
	timer_name = 'SLIB_ENTITY_TIMER_' .. util_CRC(self:EntIndex() .. timer_name)

	timer_Create(timer_name, delay, repetitions, function()
		if not IsValid(self) then
			timer_Remove(timer_name)
			return
		end

		func(self)
	end)
end

function meta:slibSimpleTimer(delay, func)
	timer_Simple(delay, function()
		if not IsValid(self) then return end
		func(self)
	end)
end

function meta:slibExistsTimer(timer_name)
	timer_name = 'SLIB_ENTITY_TIMER_' .. util_CRC(self:EntIndex() .. timer_name)
	return timer_Exists(timer_name)
end

function meta:slibRemoveTimer(timer_name)
	timer_name = 'SLIB_ENTITY_TIMER_' .. util_CRC(self:EntIndex() .. timer_name)

	if timer_Exists(timer_name) then
		timer_Remove(timer_name)
	end
end

do
	local list_door_classes = {'func_door', 'func_door_rotating', 'prop_door_rotating'}

	function meta:slibIsDoor()
		return table_HasValueBySeq(list_door_classes, self:GetClass())
	end
end

function meta:slibDoorIsLocked()
	if not self:slibIsDoor() then return true end

	local result = self:GetInternalVariable('m_bLocked')
	if isbool(result) then return result end

	return true
end

function meta:slibSinglePlayerWatching(ply)
	if IsValid(ply) then
		return ply:slibIsViewVector(self:GetPos())
	end
	return false
end

function meta:slibPlayersWatching()
	local players = player_GetAll()
	local position = self:GetPos()
	for i = 1, #players do
		local ply = players[i]
		if IsValid(ply) and ply:slibIsViewVector(position) then return true end
	end
	return false
end

function meta:slibAutoDestroy(time)
	self:slibCreateTimer('_system_timer_slib_auto_destroy_entity_', time, 1, function()
		self:Remove()
	end)
end

function meta:slibFadeRemove(minus)
	if self.slibIsFadeRemove then return end
	self.slibIsFadeRemove = true

	minus = minus or 1

	self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	self:slibCreateTimer('slib.system.entity.remove.fade', 0.01, 0, function()
		local color = self:GetColor()
		if color.a - minus >= 0 then
			local newColor = ColorAlpha(color, color.a - minus)
			self:SetColor(newColor)
			if self.GetActiveWeapon then
				local weapon = self:GetActiveWeapon()
				if IsValid(weapon) then
					weapon:SetColor(newColor)
				end
			end
		else
			self:Remove()
		end
	end)
end

function meta:slibAddHook(hook_type, hook_name, func)
	hook_name = 'slib_system_entity_' .. hook_type .. '_' .. hook_name .. '_' .. tostring(self:EntIndex())
	hook.Add(hook_type, hook_name, function(...)
		if not IsValid(self) then
			hook_Remove(hook_type, hook_name)
			return
		end
		func(...)
	end)
end

function meta:slibRemoveHook(hook_type, hook_name)
	hook_name = 'slib_system_entity_' .. hook_type .. '_' .. hook_name .. '_' .. tostring(self:EntIndex())
	hook_Remove(hook_type, hook_name)
end

function meta:slibIsSingleCall()
	local delay = self:slibGetLocalVar('slib_is_single_call_delay', 0)
	self:slibSetLocalVar('slib_is_single_call_delay', RealTime() + 0.1)
	return delay < RealTime()
end

function snet.ClientRPC(ent, function_name, ...)
	if not SERVER then return end

	if not isentity(ent) and ent.Weapon then
		ent = ent.Weapon
	end

	if not ent or not IsValid(ent) then return end

	local ply
	local owner = ent:GetOwner()

	if IsValid(owner) and owner:IsPlayer() then
		ply = owner
	end

	if ply and ent:GetClass() == 'gmod_tool' then
		local tool = ply:GetTool()
		snet.Invoke('snet_entity_tool_call_client_rpc', ply, ent, tool:GetMode(), function_name, ...)
	else
		if ply then
			snet.Invoke('snet_entity_call_client_rpc', ply, ent, function_name, ...)
		else
			snet.InvokeAll('snet_entity_call_client_rpc', ent, function_name, ...)
		end
	end
end

function meta:slibClientRPC(function_name, ...)
	snet.ClientRPC(self, function_name, ...)
end

function meta:slibPredictedClientRPC(function_name, ...)
	if not IsFirstTimePredicted() then return end
	snet.ClientRPC(self, function_name, ...)
end

function meta:slibMoveTowardsPosition(target_vector, max_distance_delta)
	local new_vector = slib.MoveTowardsVector(self:GetPos(), target_vector, max_distance_delta)
	self:SetPos(new_vector)
end

function meta:slibMoveTowardsAngles(target_angle, max_distance_delta)
	local new_angle = slib.MoveTowardsVector(self:GetAngles(), target_angle, max_distance_delta)
	self:SetAngles(new_angle)
end

function meta:slibIsViewVector(pos, radius)
	local view_entity

	if self.GetViewEntity then
		view_entity = self:GetViewEntity()
	else
		view_entity = self
	end

	if not view_entity.EyePos or not view_entity.GetAimVector then return true end
	radius = radius or 90

	local DirectionAngle = math_pi / radius
	local EntityDifference = pos - view_entity:EyePos()
	local EntityDifferenceDot = view_entity:GetAimVector():Dot(EntityDifference) / EntityDifference:Length()

	return EntityDifferenceDot > DirectionAngle
end

function meta:slibIsTraceEntity(target, distance, check_view_vector)
	if not IsValid(target) then return false end

	distance = distance or 1000

	local target_pos = target:LocalToWorld(target:OBBCenter())
	local eye_pos

	if self.EyePos then
		eye_pos = self:EyePos()
	else
		local obb_center = self:OBBCenter()
		obb_center.z = self:OBBMaxs().z
		eye_pos = self:LocalToWorld(obb_center)
	end

	if check_view_vector and not self:slibIsViewVector(target_pos) then return false end

	local tr = util_TraceLine({
		start = eye_pos,
		endpos = target_pos,
		filter = function(ent)
			if ent ~= self then return true end
		end
	})

	if not tr.Hit then return false end

	local tr_ent = tr.Entity
	return tr_ent == target or (tr_ent:IsVehicle() and tr_ent:GetDriver() == target)
end

function snet.ServerRPC(ent, function_name, ...)
	if not CLIENT then return end

	if not isentity(ent) and ent.Weapon then
		ent = ent.Weapon
	end

	if not ent or not IsValid(ent) then return end

	local owner = ent:GetOwner()
	if IsValid(owner) and owner:IsPlayer() and owner ~= LocalPlayer() then return end

	if ent:GetClass() == 'gmod_tool' then
		local tool = LocalPlayer():GetTool()
		snet.InvokeServer('snet_entity_tool_call_server_rpc', ent, tool:GetMode(), function_name, ...)
	else
		snet.InvokeServer('snet_entity_call_server_rpc', ent, function_name, ...)
	end
end

function meta:slibServerRPC(function_name, ...)
	snet.ServerRPC(self, function_name, ...)
end

function meta:slibPredictedServerRPC(function_name, ...)
	if not IsFirstTimePredicted() then return end
	snet.ServerRPC(self, function_name, ...)
end

do
	local network_vars_types = {
		[1] = 'SetNWAngle',
		[2] = 'SetNWBool',
		[3] = 'SetNWEntity',
		[4] = 'SetNWFloat',
		[5] = 'SetNWInt',
		[6] = 'SetNWString',
		[7] = 'SetNWVarProxy',
		[8] = 'SetNWVector'
	}

	local network_vars_types_comparison = {
		['angle'] = network_vars_types[1],
		['ang'] = network_vars_types[1],
		['bool'] = network_vars_types[2],
		['boolean'] = network_vars_types[2],
		['entity'] = network_vars_types[3],
		['ent'] = network_vars_types[3],
		['float'] = network_vars_types[4],
		['num'] = network_vars_types[4],
		['number'] = network_vars_types[4],
		['int'] = network_vars_types[5],
		['integer'] = network_vars_types[5],
		['string'] = network_vars_types[6],
		['str'] = network_vars_types[6],
		['text'] = network_vars_types[6],
		['varproxy'] = network_vars_types[7],
		['proxy'] = network_vars_types[7],
		['vector'] = network_vars_types[8],
		['vec'] = network_vars_types[8],
	}

	function meta:slibSetNWListener(nw_type, listener_name, func, unique_id)
		local nw_listener_type = network_vars_types_comparison[nw_type]
		if not nw_listener_type or not isfunction(func) then return end

		self.slibSetNWVarsListeners = self.slibSetNWVarsListeners or {}
		self.slibSetNWVarsListeners[nw_listener_type] = self.slibSetNWVarsListeners[nw_listener_type] or {}

		local listeners = self.slibSetNWVarsListeners[nw_listener_type]
		listeners[listener_name] = listeners[listener_name] or {}

		if not unique_id then
			table_insert(listeners[listener_name], { id = slib.UUID(), func = func })
		else
			table_InsertOrReplace(listeners[listener_name], { id = unique_id, func = func }, function(_, value)
				return value.id == unique_id
			end)
		end
	end

	for i = 1, #network_vars_types do
		local nw_listener_type = network_vars_types[i]
		local original_function = meta[nw_listener_type]
		if not original_function or not isfunction(original_function) then continue end

		meta[nw_listener_type] = function(self, key, ...)
			local listeners = self.slibSetNWVarsListeners
			if listeners and listeners[nw_listener_type] and listeners[nw_listener_type][key] then
				local args = { ... }
				local def = slib.def
				local error = slib.Error
				local handlers = listeners[nw_listener_type][key]

				for handler_index = 1, #handlers do
					local handler = handlers[handler_index]
					if handler and handler.func then
						def({
							try = function() handler.func(unpack(args)) end,
							catch = function(error_message) error(error_message) end,
						})
					end
				end
			end

			return original_function(self, key, ...)
		end
	end
end