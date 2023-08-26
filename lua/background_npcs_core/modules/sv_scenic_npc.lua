local IsValid = IsValid
local isfunction = isfunction
local timer_Simple = timer.Simple
local ents_Create = ents.Create
local table_remove = table.remove
local table_insert = table.insert
local math_random = math.random
local ipairs = ipairs
--
local scenic_actors_parent = {}
local scenic_actions = {}

--[[
	Actors parent
--]]
-- scenic_actors_parent['npc_citizen'] = {
-- 	'npc_cheering_citizen_looping',
-- 	'npc_metrocop_abusing_male_wall_spread',
-- }

--[[
	Actors actions
--]]
scenic_actions['npc_cheering_citizen_looping'] = {
	OnInit = function(actor_info, scenic_ent)
		local actor = BGN_ACTOR:Instance(scenic_ent.npc, actor_info.npc_type)
		table_insert(scenic_ent.actors, actor)
	end,
	OnRemove = function(actor_info, scenic_ent)
		scenic_ent.npc = nil
	end
}

scenic_actions['npc_metrocop_abusing_male_wall_spread'] = {
	OnInit = function(actor_info, scenic_ent)
		local actor_citizen = BGN_ACTOR:Instance(scenic_ent.spreadwall_male, actor_info.npc_type)
		local actor_police = BGN_ACTOR:Instance(scenic_ent.spreadwall_metrocop, 'police')

		table_insert(scenic_ent.actors, actor_citizen)
		table_insert(scenic_ent.actors, actor_police)
	end,
	OnRemove = function(actor_info, scenic_ent)
		scenic_ent.spreadwall_male = nil
		scenic_ent.spreadwall_metrocop = nil
	end
}

hook.Add('BGN_OnValidSpawnActor', 'BGN_ScenicNPC', function(npc_type, npc_data, npc_class, position)
	local scenic_ent, scenic_class
	local actor_info = {
		npc_type = npc_type,
		npc_data = npc_data,
		npc_class = npc_class,
		position = position
	}

	if scenic_actors_parent[npc_class] then
		local tbl = scenic_actors_parent[npc_class]
		local id = math_random(1, #tbl)
		scenic_class = scenic_actors_parent[npc_class][id]
	end

	if not scenic_class then return end

	scenic_ent = ents_Create(scenic_class)
	scenic_ent:SetPos(position)
	scenic_ent:Spawn()

	if not IsValid(scenic_ent) then return end

	local actions = scenic_actions[scenic_class]
	if not actions then return end

	timer_Simple(.1, function()
		if not IsValid(scenic_ent) then return end

		scenic_ent.actors = {}

		if isfunction(scenic_ent.OnRemove) then
			local originalOnRemove = scenic_ent.OnRemove
			function scenic_ent:OnRemove()
				if isfunction(actions.OnRemove) and actions.OnRemove(actor_info, self) then
					return
				end
				return originalOnRemove(self)
			end
		end

		local originalThink = scenic_ent.Think
		function scenic_ent:Think()
			local actors_count = #self.actors
			if actors_count ~= 0 then
				for i = actors_count, 1, -1 do
					local actor = self.actors[i]
					if not actor or not actor:IsAlive() or not actor:HasState('scenic_npc') then
						table_remove(self.actors, i)
					end
				end
			end
			if actors_count == 0 then
				self:Remove()
				return
			end
			if isfunction(originalThink) then
				return originalThink(self)
			end
		end

		if isfunction(actions.OnInit) then
			actions.OnInit(actor_info, scenic_ent)
		end

		for _, parent_actor in ipairs(scenic_ent.actors) do
			if parent_actor and parent_actor:IsAlive() then
				parent_actor:SetState('scenic_npc')
				parent_actor.mechanics.ignore_limit = true

				local state_data = parent_actor:GetStateData()
				state_data.scenic_ent = scenic_ent

				local npc = parent_actor:GetNPC()
				if IsValid(npc) then
					npc:SetParent(nil)
					scenic_ent:DontDeleteOnRemove(npc)
					npc:DontDeleteOnRemove(scenic_ent)
				end
			end
		end

		for _, parent_actor in ipairs(scenic_ent.actors) do
			if parent_actor and parent_actor:IsAlive() then
				local npc = parent_actor:GetNPC()
				if IsValid(npc) then
					for _, another_parent_actor in ipairs(scenic_ent.actors) do
						if another_parent_actor and another_parent_actor ~= parent_actor then
							local another_npc = another_parent_actor:GetNPC()
							if IsValid(another_npc) then
								another_npc:DontDeleteOnRemove(npc)
								npc:DontDeleteOnRemove(another_npc)
							end
						end
					end
				end
			end
		end

		scenic_ent:SetParent(nil)
	end)

	return true
end)