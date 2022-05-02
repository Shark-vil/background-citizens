local function SetNPCRelationship(actor, npc)
	if not actor:IsAlive() then return end

	local actor_npc = actor:GetNPC()
	local is_ignore_another_npc = GetConVar('bgn_ignore_another_npc'):GetBool()

	local ply = player.GetAll()[1]
	if bgNPC:IsPeacefulMode() or is_ignore_another_npc or ( ply and npc:Disposition(ply) ~= D_HT ) then
		actor_npc:AddEntityRelationship(npc, D_NU, 99)
		npc:AddEntityRelationship(actor_npc, D_NU, 99)
		actor:RemoveEnemy(npc)
	elseif not is_ignore_another_npc then
		local reaction = actor:GetReactionForProtect()
		if actor:HasStateGroup(reaction, 'danger') then
			actor:SetState(reaction, nil, true)
			actor:AddEnemy(npc)
		end
	end
end

local function RebuildActorsRelationship(actor)
	if not actor or not actor:IsAlive() then return end

	local npc = actor:GetNPC()

	for _, another_actor in ipairs(bgNPC:GetAll()) do
		if not another_actor or not another_actor:IsAlive() or another_actor == actor then
			continue
		end

		local another_npc = another_actor:GetNPC()
		if not IsValid(another_npc) then continue end

		if bgNPC:IsPeacefulMode() or actor:HasTeam(another_actor) then
			if npc:IsNPC() then npc:AddEntityRelationship(another_npc, D_LI, 99) end
			if another_npc:IsNPC() then another_npc:AddEntityRelationship(npc, D_LI, 99) end
		else
			if npc:IsNPC() then npc:AddEntityRelationship(another_npc, D_NU, 99) end
			if another_npc:IsNPC() then another_npc:AddEntityRelationship(npc, D_NU, 99) end
		end
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

hook.Add('BGN_InitActor', 'BGN_RemoveActorTargetFixer', function(actor)
	RebuildActorsRelationship(actor)
end)

hook.Add('BGN_InitActor', 'BGN_AddAnotherNPCToIgnore', function(actor)
	if not actor:IsAlive() or not actor:GetNPC():IsNPC() then return end

	for _, npc in ipairs(ents.GetAll()) do
		if npc and npc:IsNPC() and not npc.isBgnActor then
			SetNPCRelationship(actor, npc)
		end
	end
end)

hook.Add('OnEntityCreated', 'BGN_AddAnotherNPCToIgnore', function(ent)
	if not ent:IsNPC() then return end

	timer.Simple(0.5, function()
		if not IsValid(ent) or ent.isBgnActor then return end

		for _, actor in ipairs(bgNPC:GetAll()) do
			if actor and actor:IsAlive() and actor:GetNPC():IsNPC() then
				SetNPCRelationship(actor, ent)
			end
		end
	end)
end)

--[[
hook.Add('BGN_InitActor', 'BGN_RemoveActorTargetFixer', function(actor)
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end

	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local AnotherActor = actors[i]
		local another_npc = AnotherActor:GetNPC()
		if IsValid(another_npc) and another_npc:IsNPC() then
			if bgNPC:IsPeacefulMode() or actor:HasTeam(AnotherActor) then
				if npc:IsNPC() then npc:AddEntityRelationship(another_npc, D_LI, 99) end
				another_npc:AddEntityRelationship(npc, D_LI, 99)
			else
				if npc:IsNPC() then npc:AddEntityRelationship(another_npc, D_NU, 99) end
				another_npc:AddEntityRelationship(npc, D_NU, 99)
			end
		end
	end

	if npc:IsNPC() then
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) then
				if bgNPC:IsPeacefulMode() or actor:HasTeam(ply) then
					npc:AddEntityRelationship(ply, D_LI, 99)
				else
					npc:AddEntityRelationship(ply, D_NU, 99)
				end
			end
		end
	end
end)
]]