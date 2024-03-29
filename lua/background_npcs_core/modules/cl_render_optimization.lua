local bgNPC = bgNPC
local IsValid = IsValid
local LocalPlayer = LocalPlayer
--
local is_active = GetConVar('bgn_cl_field_view_optimization'):GetBool()
local min_range = GetConVar('bgn_cl_field_view_optimization_range'):GetFloat() ^ 2

cvars.AddChangeCallback('bgn_cl_field_view_optimization', function(convar_name, value_old, value_new)
	local new_value = tobool(value_new)
	if is_active == new_value then return end
	is_active = new_value

	if not is_active then
		local entities = bgNPC:GetAllNPCs()

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

async.AddDedic('bgn_client_render_optimization', function(yield, wait)
	local current_pass = 0

	while true do
		if not is_active then
			wait(1)
			return
		end

		local ply = LocalPlayer()
		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]

			if actor and actor:IsAlive() then
				local npc = actor:GetNPC()

				if not IsValid(npc.slib_animator) then
					local pos = npc:GetPos()
					local weapon = npc:GetActiveWeapon()
					local in_vehicle = actor:InVehicle()
					local past_set_no_draw = npc:slibGetLocalVar('bgn_render_optimization', false)

					if in_vehicle or (
						ply:GetPos():DistToSqr(pos) > min_range and not ply:slibIsViewVector(pos)
					) then
						if not past_set_no_draw and not npc:GetNoDraw() then
							npc:SetNoDraw(true)
							npc:slibSetLocalVar('bgn_render_optimization', true)

							if IsValid(weapon) then
								weapon:SetNoDraw(true)
							end
						end
					else
						if past_set_no_draw and npc:GetNoDraw() then
							npc:SetNoDraw(false)
							npc:slibSetLocalVar('bgn_render_optimization', false)

							if IsValid(weapon) then
								weapon:SetNoDraw(false)
							end
						end
					end

					if current_pass >= 1 / slib.deltaTime then
						current_pass = 0
						yield()
					else
						current_pass = current_pass + 1
					end
				end
			end
		end

		yield()
	end
end)