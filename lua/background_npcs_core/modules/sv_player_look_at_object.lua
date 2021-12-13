local IsValid = IsValid
local RealTime = RealTime
local player_GetAll =  player.GetAll
local util_TraceLine = util.TraceLine
local hook_Run = hook.Run
--

timer.Create('BGN_Timer_PlayerLookAtObject', 1, 0, function()
	local players = player_GetAll()
	for i = 1, #players do
		local ply = players[i]
		if not IsValid(ply) or not ply:Alive() then continue end

		local tr = util_TraceLine({
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:EyeAngles():Forward() * 1000,
			filter = function(ent)
				if ent ~= ply then return true end
			end
		})

		local ent = tr.Entity
		if tr.Hit and IsValid(ent) then
			ply.bgNPCLookObject = ply.bgNPCLookObject or ent
			ply.bgNPCLookObjectTime = ply.bgNPCLookObjectTime or RealTime()

			if ply.bgNPCLookObject ~= ent then
				ply.bgNPCLookObject = ent
				ply.bgNPCLookObjectTime = RealTime()
			end

			local LookTime = RealTime() - ply.bgNPCLookObjectTime
			if hook_Run('BGN_PlayerLookAtObject', ply, ent, LookTime) then
				ply.bgNPCLookObjectTime = RealTime()
			end
		end
	end
end)