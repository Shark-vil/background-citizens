local bgNPC = bgNPC
local EFL_NO_THINK_FUNCTION = EFL_NO_THINK_FUNCTION
local IsValid = IsValid
local CurTime = CurTime
local isfunction = isfunction
local player_GetAll = player.GetAll
--
local bgn_enable = GetConVar('bgn_enable'):GetBool()
local bgn_disable_logic_radius = GetConVar('bgn_disable_logic_radius'):GetFloat() ^ 2

--[[
	Async process
--]]
local function process(yield, wait)
	local current_pass = 0

	while true do
		if not bgn_enable or bgn_disable_logic_radius <= 0 then
			wait(1)
			return
		end

		local players = player_GetAll()
		local players_count = #players

		if players_count == 0 then
			wait(1)
			return
		end

		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]

			if actor and not actor:InVehicle() then
				local npc = actor:GetNPC()

				if IsValid(npc) and (not isfunction(npc.GetActiveWeapon) or not IsValid(npc:GetActiveWeapon())) then
					local npc_pos = npc:GetPos()
					local is_adding_no_think_flag = true

					for k = 1, players_count do
						local ply = players[k]

						if IsValid(ply) then
							local dist = npc_pos:DistToSqr(ply:GetPos())
							if dist <= bgn_disable_logic_radius or ply:slibIsViewVector(npc_pos) then
								is_adding_no_think_flag = false
								break
							end
						end
					end

					local is_no_think_flag = npc:IsEFlagSet(EFL_NO_THINK_FUNCTION)
					local no_think_state = npc:slibGetLocalVar('bgn_optimize_no_think_enable', false)
					local delay = npc:slibGetLocalVar('bgn_optimize_no_think_delay', 0)
					local time = CurTime()

					if is_adding_no_think_flag and no_think_state and delay < time then
						is_adding_no_think_flag = false
					end

					if (is_adding_no_think_flag and is_no_think_flag) or (not is_adding_no_think_flag and not is_no_think_flag) then
						continue
					end

					if is_adding_no_think_flag then
						npc:AddEFlags(EFL_NO_THINK_FUNCTION)
					else
						npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
					end
					npc:slibSetLocalVar('bgn_optimize_no_think_enable', is_adding_no_think_flag)

					delay = is_adding_no_think_flag and time + 3 or time + 1
					npc:slibSetLocalVar('bgn_optimize_no_think_delay', delay)
				end
			end

			if current_pass >= 1 / slib.deltaTime then
				current_pass = 0
				yield()
			else
				current_pass = current_pass + 1
			end
		end

		yield()
	end
end
async.AddDedic('bgn_server_logic_optimization', process)

--[[
	Cvars
--]]
cvars.AddChangeCallback('bgn_disable_logic_radius', function(_, _, new_value)
	bgn_disable_logic_radius = tonumber(new_value) ^ 2

	if bgn_disable_logic_radius > 0 then
		if not async.Exists('bgn_server_logic_optimization') then
			async.Add('bgn_server_logic_optimization', process)
		end
	else
		async.Remove('bgn_server_logic_optimization')

		timer.Simple(1, function()
			local actors = bgNPC:GetAll()

			for i = 1, #actors do
				local actor = actors[i]
				if actor and actor:IsAlive() and not actor:InVehicle() then
					actor:GetNPC():RemoveEFlags(EFL_NO_THINK_FUNCTION)
				end
			end
		end)
	end
end, 'rlo_bgn_disable_logic_radius')

cvars.AddChangeCallback('bgn_enable', function(_, _, new_value)
	bgn_enable = tobool(new_value)
end, 'rlo_bgn_enable')