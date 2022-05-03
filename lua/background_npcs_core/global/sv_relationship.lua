local ipairs = ipairs
local player_GetAll = player.GetAll
local ents_GetAll = ents.GetAll
local isfunction = isfunction
local IsValid = IsValid
--
local cvar_bgn_ignore_another_npc = GetConVar('bgn_ignore_another_npc')
local cvar_bgn_debug = GetConVar('bgn_debug')
local log_disposition = {
	[D_ER] = 'Error',
	[D_HT] = 'Hate',
	[D_FR] = 'Frightened / Fear',
	[D_LI] = 'Like',
	[D_NU] = 'Neutral'
}
--

--[[
-- Gets the maximum value that the NPC has on players.
local function GetPlayersDisposition(npc)
	local disposition_result = D_NU

	if not npc.Disposition or not isfunction(npc.Disposition) then
		return disposition_result
	end

	local dispositions = {}

	for _, ply in ipairs(player_GetAll()) do
		local index = npc:Disposition(ply)
		dispositions[index] = dispositions[index] or 0
		dispositions[index] = dispositions[index] + 1
	end

	local last_max_disposition_count = 0

	for disposition_index, disposition_count in pairs(dispositions) do
		if disposition_count > last_max_disposition_count then
			last_max_disposition_count = disposition_count
			disposition_result = disposition_index
		end
	end

	return disposition_result
end
--]]

-- Gets a neutral value if the NPC is not aggressive towards any player
local function GetPlayersDisposition(npc)
	if isfunction(npc.Disposition) then
		for _, ply in ipairs(player_GetAll()) do
			if npc:Disposition(ply) == D_HT then
				return D_HT
			end
		end
	end

	return D_NU
end

local function SetNPCRelationship(actor, another_npc)
	if not actor:IsAlive() then return end

	local actor_npc = actor:GetNPC()
	local another_actor = bgNPC:GetActor(another_npc)
	local is_ignore_another_npc = cvar_bgn_ignore_another_npc:GetBool()
	local disposition = GetPlayersDisposition(another_npc)

	if another_actor then
		if bgNPC:IsPeacefulMode() or actor:HasTeam(another_actor) then
			if isfunction(actor_npc.AddEntityRelationship) then
				actor_npc:AddEntityRelationship(
					another_npc,
					actor:GetRelationship(another_npc) or D_LI,
					99
				)
			end

			if isfunction(another_npc.AddEntityRelationship) then
				another_npc:AddEntityRelationship(
					actor_npc,
					another_actor:GetRelationship(actor_npc) or D_LI,
					99
				)
			end
		else
			if isfunction(actor_npc.AddEntityRelationship) then
				actor_npc:AddEntityRelationship(
					another_npc,
					actor:GetRelationship(another_npc) or D_NU,
					99
				)
			end

			if isfunction(another_npc.AddEntityRelationship) then
				another_npc:AddEntityRelationship(
					actor_npc,
					another_actor:GetRelationship(actor_npc) or D_NU,
					99
				)
			end
		end
	else
		if bgNPC:IsPeacefulMode() or is_ignore_another_npc or disposition ~= D_HT then
			if isfunction(actor_npc.AddEntityRelationship) then
				actor_npc:AddEntityRelationship(another_npc, actor:GetRelationship(another_npc) or D_NU, 99)
			end

			if isfunction(another_npc.AddEntityRelationship) then
				another_npc:AddEntityRelationship(actor_npc, D_NU, 99)
			end

			actor:RemoveEnemy(another_npc)
		elseif not is_ignore_another_npc then
			local reaction = actor:GetReactionForProtect()
			if actor:HasStateGroup(reaction, 'danger') then
				actor:SetState(reaction, nil, true)
				actor:AddEnemy(another_npc)
			end
		end
	end

	if cvar_bgn_debug:GetBool() and actor_npc:IsNPC() then
		bgNPC:Log(
			string.format('Actor NPC: [%s] %q > [%s] %q : %s',
			actor:GetType(), actor_npc,
			another_actor and another_actor:GetType() or 'NPC', another_npc,
			log_disposition[another_npc:Disposition(actor_npc)]
		), 'Relationship')
	end
end

local function RebuildActorsRelationship(actor)
	if not actor or not actor:IsAlive() then return end

	bgNPC:Log('RebuildActorsRelationship', 'Relationship')

	for _, another_actor in ipairs(bgNPC:GetAll()) do
		if not another_actor or not another_actor:IsAlive() or another_actor == actor then
			continue
		end

		SetNPCRelationship(actor, another_actor:GetNPC())
	end
end

cvars.AddChangeCallback('bgn_peaceful_mode', function()
	timer.Simple(.1, function()
		local entities = ents.GetAll()

		for _, actor in ipairs(bgNPC:GetAll()) do
			actor:RemoveAllEnemies()
			actor:SetState('walk', nil, true)

			RebuildActorsRelationship(actor)

			for _, npc in ipairs(entities) do
				if npc and npc:IsNPC() and not npc.isBgnActor then
					SetNPCRelationship(actor, npc)
				end
			end
		end
	end)
end, 'bgn_peaceful_mode')

-- hook.Add('BGN_InitActor', 'BGN_RemoveActorTargetFixer', function(actor)
-- 	RebuildActorsRelationship(actor)
-- end)

hook.Add('BGN_InitActor', 'BGN_SetPlayersRelationship', function(actor)
	if not actor:IsAlive() then return end

	local npc = actor:GetNPC()

	-- Sets neutral relations for all existing players
	if isfunction(npc.AddEntityRelationship) then
		for _, ply in ipairs(player_GetAll()) do
			npc:AddEntityRelationship(ply, actor:GetRelationship(ply) or D_NU, 99)

			if cvar_bgn_debug:GetBool() then
				bgNPC:Log(
					string.format('Player relationship: %q > %q : %s',
					npc, ply, log_disposition[npc:Disposition(ply)]
				), 'Relationship')
			end
		end
	end
end)

-- Sets relationships for all existing NPCs and NextBots in the map
hook.Add('BGN_InitActor', 'BGN_AddAnotherNPCToIgnore', function(actor)
	if not actor:IsAlive() then return end

	for _, npc in ipairs(ents_GetAll()) do
		if IsValid(npc) and (npc:IsNPC() or npc:IsNextBot()) then
			SetNPCRelationship(actor, npc)
		end
	end
end)

-- Sets relationships for newly created NPCs and NextBots
hook.Add('OnEntityCreated', 'BGN_AddAnotherNPCToIgnore', function(npc)
	if not npc:IsNPC() and not npc:IsNextBot() then return end

	timer.Simple(.5, function()
		if not IsValid(npc) or npc.isBgnActor then return end

		for _, actor in ipairs(bgNPC:GetAll()) do
			if actor and actor:IsAlive() then
				SetNPCRelationship(actor, npc)
			end
		end
	end)
end)