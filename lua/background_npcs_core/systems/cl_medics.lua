-- Client-side ragdolls for the medics (systems/sv_medics.lua): removes the one of a revived actor,
-- tells the server when one fades out or is cleaned up, so the medic stops coming for it.
local RAGDOLL_DIST_SQR = 200 ^ 2
local ragdolls = setmetatable({}, { __mode = 'k' })

hook.Add('CreateClientsideRagdoll', 'BGN_Medics', function(_, ragdoll)
	ragdolls[ragdoll] = true
end)

hook.Add('EntityRemoved', 'BGN_Medics', function(ent)
	if not ragdolls[ent] then return end
	ragdolls[ent] = nil
	bgNPC.Net.SendToServer('bgn.medic_body_gone', ent:GetPos())
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
