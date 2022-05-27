local IsValid = IsValid
local timer_Simple = timer.Simple
local cvar_bgn_module_followers_mod_addon = GetConVar('bgn_module_followers_mod_addon')
--

local function movement_handler(actor)
	if not cvar_bgn_module_followers_mod_addon:GetBool() then return end
	if not actor or not actor:IsAlive() then return end

	local npc = actor:GetNPC()
	local follower = npc:GetNWEntity('FMOD_MyTarget', nil)
	if not follower or not IsValid(follower) then return end

	if actor:WalkDestinationExists() then
		actor:StopWalk()
	end

	return false
end

local function created_actor_handler(actor)
	local npc = actor:GetNPC()
	timer_Simple(0, function()
		if not IsValid(npc) then return end
		npc:slibSetNWListener('entity', 'FMOD_MyTarget', function(val, default)
			if not val then return end
			movement_handler(actor)
		end, 'bgn_module_fmod')
	end)
end

hook.Add('BGN_PreSetWalkPos', 'BGN_Module_FollowersMod', movement_handler)
hook.Add('BGN_PreNPCStartAnimation', 'BGN_Module_FollowersMod', movement_handler)
hook.Add('BGN_InitActor', 'BGN_Module_FollowersMod', created_actor_handler)