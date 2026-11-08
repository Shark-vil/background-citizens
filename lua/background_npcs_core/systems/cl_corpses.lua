-- Client-side ragdolls of the actors: the server removes one near a position (a medic revived the actor,
-- the corpse cleanup, systems/sv_corpses.lua), and hears when one fades or is cleaned up, so the medic stops coming for it.
-- npc_battle_cleanup leaves them alone: it would remove a body in seconds, before a medic or an officer gets to it.
local RAGDOLL_DIST_SQR = 200 ^ 2
local FADE_TIME = 0.8
local ragdolls = setmetatable({}, { __mode = 'k' })

hook.Add('CreateClientsideRagdoll', 'BGN_Corpses', function(owner, ragdoll)
	if IsValid(owner) and owner:GetNW2Bool('bgn_actor') then ragdolls[ragdoll] = true end
end)

hook.Add('EntityRemoved', 'BGN_Corpses', function(ent)
	if not ragdolls[ent] then return end
	ragdolls[ent] = nil
	bgNPC.Net.SendToServer('bgn.medic_body_gone', ent:GetPos())
end)

local function FadeRemove(ragdoll)
	local name, start = 'BGN_CorpseFade' .. tostring(ragdoll), CurTime()
	ragdoll:SetRenderMode(RENDERMODE_TRANSCOLOR)
	timer.Create(name, 0, 0, function()
		if not IsValid(ragdoll) then return timer.Remove(name) end
		local alpha = 1 - (CurTime() - start) / FADE_TIME
		if alpha > 0 then return ragdoll:SetColor(Color(255, 255, 255, 255 * alpha)) end
		timer.Remove(name)
		ragdoll:Remove()
	end)
end

bgNPC.Net.Receive('bgn.body_remove', function(_, pos, fade)
	local best, best_dist
	for ragdoll in pairs(ragdolls) do
		if IsValid(ragdoll) then
			local dist = ragdoll:GetPos():DistToSqr(pos)
			if dist < RAGDOLL_DIST_SQR and (not best or dist < best_dist) then best, best_dist = ragdoll, dist end
		end
	end
	if not best then return end
	ragdolls[best] = nil
	if fade then FadeRemove(best) else best:Remove() end
end)

-- npc_battle_cleanup defines its functions in its own InitPostEntity: wrap after all of them
hook.Add('InitPostEntity', 'BGN_Corpses_NBC', function()
	timer.Simple(0, function()
		local remove = NBC and NBC.RemoveClientsideCorpse
		if not isfunction(remove) then return end
		function NBC.RemoveClientsideCorpse(owner, corpse)
			local cvar = GetConVar('bgn_corpse_cleanup')
			if cvar and cvar:GetBool() and IsValid(owner) and owner:GetNW2Bool('bgn_actor') then return end
			return remove(owner, corpse)
		end
	end)
end)
