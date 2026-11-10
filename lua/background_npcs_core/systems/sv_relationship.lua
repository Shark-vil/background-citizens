--
local cvar_bgn_ignore_another_npc = GetConVar('bgn_ignore_another_npc')
-- local cvar_bgn_debug = GetConVar('bgn_debug')
-- local log_disposition = {
-- 	[D_ER] = 'Error',
-- 	[D_HT] = 'Hate',
-- 	[D_FR] = 'Frightened / Fear',
-- 	[D_LI] = 'Like',
-- 	[D_NU] = 'Neutral'
-- }
--

--[[
-- Gets the maximum value that the NPC has on players.
local function GetPlayersDisposition(npc)
	local disposition_result = D_NU

	if not npc.Disposition or not isfunction(npc.Disposition) then
		return disposition_result
	end

	local dispositions = {}

	for _, ply in ipairs(player.GetAll()) do
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
		for _, ply in ipairs(player.GetAll()) do
			if npc:Disposition(ply) == D_HT then
				return D_HT
			end
		end
	end

	return D_NU
end

-- @param disposition number|nil precomputed GetPlayersDisposition(another_npc), it does not depend on the actor
local function SetNPCRelationship(actor, another_npc, disposition)
	if not actor:IsAlive() then return end
	if another_npc.bgn_probe then return end -- sv_nextbot_hostility.lua

	local actor_npc = actor:GetNPC()
	local another_actor = bgNPC.Actors.Get(another_npc)
	local is_ignore_another_npc = cvar_bgn_ignore_another_npc:GetBool()
	disposition = disposition or GetPlayersDisposition(another_npc)

	if another_actor then
		if bgNPC.Modes.IsPeaceful() or actor:HasTeam(another_actor) then
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
		if bgNPC.Modes.IsPeaceful() or is_ignore_another_npc or disposition ~= D_HT then
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
				-- a forced restart of a running danger state for every new hostile NPC froze the server with many actors
				if not actor:EqualStateGroup('danger') then actor:SetState(reaction, nil, true) end
				actor:AddEnemy(another_npc)
			end
		end
	end

	-- if cvar_bgn_debug:GetBool() and actor_npc:IsNPC() then
	-- 	bgNPC.Util.Log(
	-- 		string.format('Actor NPC: [%s] %q > [%s] %q : %s',
	-- 			tostring(actor:GetType()),
	-- 			tostring(actor_npc),
	-- 			tostring(another_actor and another_actor:GetType() or 'NPC'),
	-- 			tostring(another_npc),
	-- 			tostring(log_disposition[another_npc:Disposition(actor_npc)])
	-- 		),
	-- 		'Relationship'
	-- 	)
	-- end
end

local function RebuildActorsRelationship(actor)
	if not actor or not actor:IsAlive() then return end

	bgNPC.Util.Log('RebuildActorsRelationship', 'Relationship')

	for _, another_actor in ipairs(bgNPC.Actors.GetAll()) do
		if not another_actor or not another_actor:IsAlive() or another_actor == actor then
			continue
		end

		SetNPCRelationship(actor, another_actor:GetNPC())
	end
end

cvars.AddChangeCallback('bgn_peaceful_mode', function()
	timer.Simple(.1, function()
		local entities = ents.GetAll()

		for _, actor in ipairs(bgNPC.Actors.GetAll()) do
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

cvars.AddChangeCallback('bgn_friend_mode', function(_, old_value, new_value)
	timer.Simple(.1, function()
		local new_value_number = tonumber(new_value)
		if new_value_number == 0 then return end

		local asset = bgNPC.Modules.Get('wanted')
		for _, ply in ipairs(player.GetAll()) do
			if asset:HasWanted(ply) then
				asset:RemoveWanted(ply)
			end
			for _, actor in ipairs(bgNPC.Actors.GetAll()) do
				actor:RemoveEnemy(ply)
			end
		end
	end)
end, 'bgn_friend_mode')

-- hook.Add('BGN_InitActor', 'BGN_RemoveActorTargetFixer', function(actor)
-- 	RebuildActorsRelationship(actor)
-- end)

local function SetPlayersRelationship(actor)
	if not actor:IsAlive() or actor:InVehicle() then return end

	local npc = actor:GetNPC()

	-- Sets neutral relations for all existing players
	if isfunction(npc.AddEntityRelationship) then
		for _, ply in ipairs(player.GetAll()) do
			npc:AddEntityRelationship(ply, actor:GetRelationship(ply) or D_NU, 99)

			-- if cvar_bgn_debug:GetBool() then
			-- 	bgNPC.Util.Log(
			-- 		string.format('Player relationship: %q > %q : %s',
			-- 			tostring(npc),
			-- 			tostring(ply),
			-- 			tostring(log_disposition[npc:Disposition(ply)])
			-- 		),
			-- 		'Relationship'
			-- 	)
			-- end
		end
	end
end
hook.Add('BGN_InitActor', 'BGN_SetPlayersRelationship', SetPlayersRelationship)
hook.Add('BGN_ActorEntityChanged', 'BGN_SetPlayersRelationship', SetPlayersRelationship)

-- Sets relationships for all existing NPCs and NextBots in the map
local function SetExistingNPCRelationships(actor)
	if not actor:IsAlive() or actor:InVehicle() then return end

	for _, npc in ipairs(ents.GetAll()) do
		if IsValid(npc) and (npc:IsNPC() or npc:IsNextBot()) then
			SetNPCRelationship(actor, npc)
		end
	end
end
hook.Add('BGN_InitActor', 'BGN_AddAnotherNPCToIgnore', SetExistingNPCRelationships)
hook.Add('BGN_ActorEntityChanged', 'BGN_AddAnotherNPCToIgnore', SetExistingNPCRelationships)

-- A seated officer's body is a Decent Vehicle entity without NPC senses, and the hooks above skip seated actors:
-- hostile NPCs and NextBots near the car become its enemies here, so it steps out (modules/dv/sv_move_to_target.lua).
local SEATED_SPOT_RADIUS = 1000

-- An NPC hostile to players, or a NextBot (no Disposition) hunting a player or an actor.
local function IsHostile(ent)
	if ent:IsNPC() then return GetPlayersDisposition(ent) == D_HT end
	local target = isfunction(ent.GetEnemy) and ent:GetEnemy()
	return IsValid(target) and (target:IsPlayer() or bgNPC.Actors.Get(target) ~= nil)
end

timer.Create('BGN_SeatedPoliceSpotHostileNPC', 1, 0, function()
	if bgNPC.Modes.IsPeaceful() or cvar_bgn_ignore_another_npc:GetBool() then return end

	for _, actor in ipairs(bgNPC.Actors.GetByTeam('police')) do
		local car = actor:IsAlive() and actor:GetVehicle()
		if IsValid(car) then
			for _, ent in ipairs(ents.FindInSphere(car:GetPos(), SEATED_SPOT_RADIUS)) do
				if (ent:IsNPC() or ent:IsNextBot()) and not ent.isBgnActor and not ent.bgn_probe and ent:Health() > 0
					and not actor:HasEnemy(ent) and IsHostile(ent) and bgNPC.Vision.HasLineOfSight(actor:GetNPC(), ent)
				then
					SetNPCRelationship(actor, ent, D_HT)
				end
			end
		end
	end
end)

-- Sets relationships for newly created NPCs and NextBots
hook.Add('OnEntityCreated', 'BGN_AddAnotherNPCToIgnore', function(npc)
	if not npc:IsNPC() and not npc:IsNextBot() then return end

	timer.Simple(.5, function()
		if not IsValid(npc) or npc.isBgnActor then return end

		local actors = bgNPC.Actors.GetAll()
		local disposition = GetPlayersDisposition(npc)
		for i = #actors, 1, -1 do -- backwards: IsAlive() unregisters dead actors from this live list
			local actor = actors[i]
			if actor and actor:IsAlive() then
				SetNPCRelationship(actor, npc, disposition)
			end
		end
	end)
end)
