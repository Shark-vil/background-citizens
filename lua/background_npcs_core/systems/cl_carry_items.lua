-- Real actor visuals use the existing PVS actor snapshots; ghosts own their separate props.
local Carry = bgNPC.CarryItems
for _, prop in pairs(Carry.visuals or {}) do if IsValid(prop) then prop:Remove() end end
Carry.visuals = {}
local next_scan = 0
hook.Add('Think', 'BGN_CarryVisuals', function()
	if CurTime() < next_scan then return end
	next_scan = CurTime() + 0.25
	for actor, prop in pairs(Carry.visuals) do
		if not IsValid(prop) or not actor:IsAlive() or not actor.carry_visual or prop.bgn_kind ~= actor.carry_visual
			or prop:GetParent() ~= actor:GetNPC() then
			if IsValid(prop) then prop:Remove() end
			Carry.visuals[actor] = nil
		end
	end
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local npc, kind = actor:GetNPC(), actor.carry_visual
		if kind == 'newspaper' and IsValid(npc) then
			local weapon = npc:GetActiveWeapon()
			if IsValid(weapon) and weapon:GetClass() == 'weapon_citizenpackage' then weapon:SetNoDraw(true) end
		end
		if actor:IsAlive() and kind and not IsValid(Carry.visuals[actor]) and Carry.Supports(npc, kind) then
			local prop = Carry.CreateVisual(npc, kind, npc:IsNPC())
			if IsValid(prop) then prop.bgn_kind = kind Carry.visuals[actor] = prop end
		end
	end
end)
