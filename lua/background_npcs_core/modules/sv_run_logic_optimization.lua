local bgNPC = bgNPC
local EFL_NO_THINK_FUNCTION = EFL_NO_THINK_FUNCTION
local IsValid = IsValid
local CurTime = CurTime
local player_GetAll = player.GetAll
--
local bgn_enable = GetConVar('bgn_enable'):GetBool()
local bgn_disable_logic_radius = GetConVar('bgn_disable_logic_radius'):GetFloat() ^ 2
local max_pass = 5

cvars.AddChangeCallback('bgn_disable_logic_radius', function(_, _, new_value)
	if tonumber(new_value) > 0 then return end
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor:IsAlive() and not actor:InVehicle() then
			actor:GetNPC():RemoveEFlags(EFL_NO_THINK_FUNCTION)
		end
	end
end)

cvars.AddChangeCallback('bgn_enable', function(_, _, new_value)
	bgn_enable = tobool(new_value)
end)

cvars.AddChangeCallback('bgn_disable_logic_radius', function(_, _, new_value)
	bgn_disable_logic_radius = tonumber(new_value) ^ 2
end)

async.Add('bgn_server_logic_optimization', function(yield)
	if not bgn_enable or bgn_disable_logic_radius <= 0 then return end
	local actors = bgNPC:GetAll()
	local players = player_GetAll()
	local pass = 0

	for i = 1, #actors do
		local actor = actors[i]

		if actor and not actor:InVehicle() then
			local npc = actor:GetNPC()

			if IsValid(npc) then
				local npc_pos = npc:GetPos()
				local max_dist = nil
				local is_adding_no_think_flag = true

				for k = 1, #players do
					local ply = players[k]

					if IsValid(ply) then
						local dist = npc_pos:DistToSqr(ply:GetPos())
						if not max_dist or dist < max_dist then max_dist = dist end

						if dist <= bgn_disable_logic_radius or ply:slibIsViewVector(npc_pos) then
							is_adding_no_think_flag = false
							break
						end
					end
				end

				local no_think_state = npc:slibGetLocalVar('bgn_optimize_no_think_enable', false)
				local no_think_enable = no_think_state

				if is_adding_no_think_flag then
					local delay = npc:slibGetLocalVar('bgn_optimize_no_think_delay', 0)
					local time = CurTime()

					if delay < time then
						no_think_enable = not no_think_enable

						if no_think_enable and max_dist >= 1000000 then
							delay = time + 3
						else
							delay = time + 1
						end

						npc:slibSetLocalVar('bgn_optimize_no_think_delay', delay)
					end
				elseif no_think_enable then
					no_think_enable = false
				end

				if no_think_state ~= no_think_enable then
					if no_think_enable then
						npc:AddEFlags(EFL_NO_THINK_FUNCTION)
					else
						npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
					end

					npc:slibSetLocalVar('bgn_optimize_no_think_enable', no_think_enable)
				end

				pass = pass + 1
				if pass == max_pass then
					pass = 0
					yield()
				end
			end
		end
	end
end)