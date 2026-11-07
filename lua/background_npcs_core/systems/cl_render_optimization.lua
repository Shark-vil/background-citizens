--
local is_active = GetConVar('bgn_cl_field_view_optimization'):GetBool()
local min_range = GetConVar('bgn_cl_field_view_optimization_range'):GetFloat() ^ 2

cvars.AddChangeCallback('bgn_cl_field_view_optimization', function(convar_name, value_old, value_new)
	local new_value = tobool(value_new)
	if is_active == new_value then return end
	is_active = new_value

	if not is_active then
		local entities = bgNPC.Actors.GetAllNPCs()

		for i = 1, #entities do
			local npc = entities[i]

			if IsValid(npc) and npc:Health() > 0 then
				npc:SetNoDraw(false)
			end
		end
	end
end, 'ro_bgn_cl_field_view_optimization')

cvars.AddChangeCallback('bgn_cl_field_view_optimization_range', function(_, _, value_new)
	local new_value = tonumber(value_new) ^ 2
	if min_range == new_value then return end
	min_range = new_value
end, 'ro_bgn_cl_field_view_optimization_range')

bgNPC.Tasks.Add('bgn_client_render_optimization', function(yield, wait, budget)
	while true do
		if not is_active then
			wait(1)
			continue
		end

		local ply = LocalPlayer()
		local actors = bgNPC.Actors.GetAll()

		for i = 1, #actors do
			local actor = actors[i]

			if actor and actor:IsAlive() then
				local npc = actor:GetNPC()

				if not bgNPC.Animator.IsPlaying(npc) then
					local pos = npc:GetPos()
					local weapon = npc:GetActiveWeapon()
					local in_vehicle = actor:InVehicle()
					local past_set_no_draw = (npc.bgn_render_optimization or false)

					if in_vehicle or (
						ply:GetPos():DistToSqr(pos) > min_range and not bgNPC.Util.IsInView(ply, pos)
					) then
						if not past_set_no_draw and not npc:GetNoDraw() then
							npc:SetNoDraw(true)
							npc.bgn_render_optimization = true
							if IsValid(weapon) then
								weapon:SetNoDraw(true)
								npc.bgn_hidden_weapon = weapon
							end
						end
					elseif past_set_no_draw then
						-- No GetNoDraw check: a server update may have cleared the NPC's flag already,
						-- the weapon would then stay hidden in its hands for good.
						npc:SetNoDraw(false)
						npc.bgn_render_optimization = false
						if IsValid(npc.bgn_hidden_weapon) then npc.bgn_hidden_weapon:SetNoDraw(false) end
						npc.bgn_hidden_weapon = nil
					end

					budget()
				end
			end
		end

		yield()
	end
end)