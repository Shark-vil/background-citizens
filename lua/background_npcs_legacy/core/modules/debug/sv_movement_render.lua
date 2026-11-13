local cvar_bgn_debug = GetConVar('bgn_debug')

timer.Create('BGN_Debug_MovementPathRender', 1, 0, function()
	if not cvar_bgn_debug:GetBool() then return end

	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if actor and actor:IsAlive() then
			local position = actor:GetPos()
			local players = player.GetAll()
			for k = 1, #players do
				local ply = players[k]
				if ply and ply.snet_ready and (ply:IsAdmin() or ply:IsSuperAdmin()) and position:DistToSqr(ply:GetPos()) <= 250000 then
					snet.Invoke('bgn_debug_send_actor_movement_path', ply, actor.uid, actor.walkPath)
				end
			end
		end
	end
end)