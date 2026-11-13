local isfunction = isfunction
local istable = istable
local setmetatable = setmetatable
local table_Merge = table.Merge
local string_StartWith = string.StartWith
local string_sub = string.sub
--

function slib.Instance(component_name, ...)
	local component = slib.Components[component_name]
	if not component then return end

	if isfunction(component.Instance) then
		return component:Instance(...)
	elseif isfunction(component.New) then
		return component:New(...)
	end
end
slib.New = slib.Instance

function slib.Component(component_name, function_name, ...)
	if not function_name then
		return slib.Components[component_name]
	else
		local component = slib.Components[component_name]
		local self_caller = false

		if string_StartWith(function_name, ':') then
			function_name = string_sub(function_name, 2)
			self_caller = true
		end

		if not component or not component[function_name] then return end

		local invoke = component[function_name]
		if not isfunction(invoke) then return end

		if self_caller then
			return invoke(component, ...)
		else
			return invoke(...)
		end
	end
end

function slib.PracticeComponent(component_name, component)
	if not slib.Components[component_name] then
		slib.SetComponent(component_name, component)
	elseif istable(component) then
		local get_component = slib.Components[component_name]
		table_Merge(get_component, component)
	end
end

function slib.SetComponent(component_name, component, extends)
	local new_component

	if istable(component) then
		new_component = component
	elseif isfunction(component) then
		new_component.__call = component
	end

	if not new_component then return end

	if extends and istable(extends) then
		new_component.__index = extends
		setmetatable(new_component, extends)
	end

	slib.Components[component_name] = new_component
end