local movement_keys = {
	IN_JUMP,
	IN_FORWARD,
	IN_BACK,
	IN_MOVELEFT,
	IN_MOVERIGHT,
	IN_WALK,
	IN_SPEED,
	IN_RUN
}

hook.Add('Move', 'SlibOverrideAnimatorPlayerMovement', function(ply, mv)
	for i = #slib.Storage.ActiveAnimations, 1, -1 do
		local value = slib.Storage.ActiveAnimations[i]
		local settings = value.settings
		local entity = value.entity
		local is_player = value.is_player
		local stop_time = value.stop_time

		if not is_player or not IsValid(entity) or entity ~= ply or settings.not_lock_movement then
			continue
		end

		for k = 1, #movement_keys do
			if mv:KeyDown(movement_keys[k]) and not settings.loop and stop_time > CurTime() + .1 then
				ply:Freeze(true)
				timer.Simple(.3, function() ply:Freeze(false) end)
				return true
			end
		end
	end
end)

local function GetAnimationInfo(ent)
	for i = #slib.Storage.ActiveAnimations, 1, -1 do
		local value = slib.Storage.ActiveAnimations[i]
		if value.entity == ent then return value end
	end
end

local function DestroyAnimatorAction(ent)
	local anim = GetAnimationInfo(ent)
	if not anim then return end

	if isfunction(anim.OnDestroy) then anim.OnDestroy(ent) end
	if isfunction(anim.OnStop) then anim.OnStop(ent) end

	snet.InvokeAll('slib_animator_destroyed', ent)
	slib.Animator.ClearInactive()
end
hook.Add('EntityRemoved', 'SlibAnimatorRemoveIfEntityDestroyed', DestroyAnimatorAction)
hook.Add('OnNPCKilled', 'SlibAnimatorRemoveIfEntityDestroyed', DestroyAnimatorAction)
hook.Add('PlayerDeath', 'SlibAnimatorRemoveIfEntityDestroyed', DestroyAnimatorAction)
hook.Add('EntityTakeDamage', 'SlibAnimatorRemoveIfEntityTakeDamage', function(ent, dmginfo)
	local anim = GetAnimationInfo(ent)
	if not anim or not IsValid(anim.animator) then return end

	if isfunction(anim.OnTakeDamage) then anim.OnTakeDamage(ent, dmginfo) end
	if not anim.settings.stop_on_damage then return end

	anim.animator:Remove()
	snet.InvokeAll('slib_animator_destroyed', ent)
	slib.Animator.ClearInactive()
end)

hook.Add('Think', 'SlibAnimatorRotationFixed', function()
	for i = #slib.Storage.ActiveAnimations, 1, -1 do
		local value = slib.Storage.ActiveAnimations[i]
		local settings = value.settings
		local animator = value.animator
		local entity = value.entity

		if not IsValid(entity) or not IsValid(animator) or settings.not_parent then continue end

		if value.is_player then
			animator:SetAngles(Angle(-entity:EyeAngles().x, entity:GetAngles().y, 0))
		elseif value.is_npc then
			entity:SetNPCState(NPC_STATE_SCRIPT)
			entity:SetSchedule(SCHED_SLEEP)
		end
	end
end)