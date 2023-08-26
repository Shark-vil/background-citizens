local function init_enhanced_npc_override()
	local IsValid = IsValid
	local timer_Simple = timer.Simple
	local bgNPC = bgNPC

	local player_spawned_hook = slib.Component('Hook', 'Get', 'PlayerSpawnedNPC', 'Enhanced Sbox NPC Handling')
	if player_spawned_hook then
		hook.Add('PlayerSpawnedNPC', 'Enhanced Sbox NPC Handling', function(ply, ent)
			timer_Simple(.1, function()
				if not IsValid(ent) or not IsValid(ply) then return end
				local actor = bgNPC:GetActor(ent)
				if actor and actor.mechanics.enhanced_npc_ignore then return end
				return player_spawned_hook(ply, ent)
			end)
		end)
	end

	local ent_spawned_hook = slib.Component('Hook', 'Get', 'OnEntityCreated', 'Enhanced Sbox NPC Handling')
	if ent_spawned_hook then
		hook.Add('OnEntityCreated', 'Enhanced Sbox NPC Handling', function(ent)
			timer_Simple(.1, function()
				if not IsValid(ent) then return end
				local actor = bgNPC:GetActor(ent)
				if actor and actor.mechanics.enhanced_npc_ignore then return end
				return ent_spawned_hook(ent)
			end)
		end)
	end
end
hook.Add('InitPostEntity', 'BGN_EnhancedNPC_Integration', init_enhanced_npc_override)