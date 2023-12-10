local bgNPC = bgNPC
local player_GetAll = player.GetAll
local ipairs = ipairs
local IsValid = IsValid
local cvar_friend_mode = GetConVar('bgn_friend_mode')
local cvar_agressive_mode = GetConVar('bgn_agressive_mode')

cvars.AddChangeCallback('bgn_friend_mode', function(_, _, new_value)
	if tonumber(new_value) == 0 then return end
	RunConsoleCommand('bgn_agressive_mode', 0)
end, 'on_change_bgn_friend_mode')

cvars.AddChangeCallback('bgn_agressive_mode', function(_, _, new_value)
	if tonumber(new_value) == 0 then return end
	RunConsoleCommand('bgn_friend_mode', 0)
end, 'on_change_bgn_agressive_mode')

function bgNPC:IsFriendMode()
	return cvar_friend_mode:GetBool()
end

function bgNPC:IsAgressiveMode()
	return cvar_agressive_mode:GetBool()
end

local function OverrideDamageReaction(attacker, target)
	if not bgNPC:IsFriendMode() or bgNPC:IsPeacefulMode() then return end

	local attacker_is_player = attacker:IsPlayer()
	local target_is_player = target:IsPlayer()

	local set_enemy, set_friend

	if attacker_is_player then
		set_enemy = target
		set_friend = attacker
	elseif target_is_player then
		set_enemy = attacker
		set_friend = target
	end

	if not set_enemy and not set_friend then return end

	for _, actor in ipairs(bgNPC:GetAll()) do
		if not actor or not actor:IsAlive() then continue end

		if set_friend then
			actor:RemoveEnemy(set_friend)
		end

		if set_enemy then
			actor:AddEnemy(set_enemy)
			if actor:EqualStateGroup('calm') then
				local reaction = actor:GetReactionForDamage()
				if reaction == 'ignore' then continue end
				actor:RemoveAllTargets()
				actor:SetState(reaction)
			end
		end
	end

	return false
end
hook.Add('BGN_PostReactionTakeDamage', 'BGN_Friend_Mode', OverrideDamageReaction)
hook.Add('BGN_PreReactionTakeDamage', 'BGN_Friend_Mode', OverrideDamageReaction)

async.Add('BGN_Agressive_Mode', function(yield, wait)
	while true do
		if not bgNPC:IsAgressiveMode() or bgNPC:IsPeacefulMode() then
			wait(1)
			continue
		end

		for _, actor in ipairs(bgNPC:GetAll()) do
			if actor and actor:IsAlive() then
				for _, ply in ipairs(player_GetAll()) do
					if ply and IsValid(ply) and ply:Alive() then
						actor:AddEnemy(ply)
						if actor:EqualStateGroup('calm') then
							local reaction = actor:GetReactionForDamage()
							if reaction ~= 'ignore' then
								actor:RemoveAllTargets()
								actor:SetState(reaction)
							end
						end
					end
				end
				yield()
			end
		end

		yield()
	end
end)