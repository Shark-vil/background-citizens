-- Removes the client-side ragdoll of an actor a medic brought back (systems/sv_medics.lua).
local RAGDOLL_DIST_SQR = 200 ^ 2
local ragdolls = setmetatable({}, { __mode = 'k' })

hook.Add('CreateClientsideRagdoll', 'BGN_Medics', function(_, ragdoll)
	ragdolls[ragdoll] = true
end)

bgNPC.Net.Receive('bgn.medic_revived', function(_, pos)
	local best, best_dist
	for ragdoll in pairs(ragdolls) do
		if IsValid(ragdoll) then
			local dist = ragdoll:GetPos():DistToSqr(pos)
			if dist < RAGDOLL_DIST_SQR and (not best or dist < best_dist) then best, best_dist = ragdoll, dist end
		end
	end
	if best then
		ragdolls[best] = nil
		best:Remove()
	end
end)
