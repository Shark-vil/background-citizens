--[[
	call_backup: an officer facing an armed enemy calls backup on the radio. Up to MAX_OFFICERS free officers on
	foot within SEARCH_DIST take its enemy and come (defense runs to a far enemy). After CALL_TIME it fights.
	actor.backup_until is the GOAP fact "backup_called" (brain/goap/sv_goap_actions.lua).
	State data: { enemy = <entity> }.
--]]

local SEARCH_DIST_SQR = 4000 ^ 2
local MAX_OFFICERS = 3
local CALL_TIME = 2
local BACKUP_TIME = 60 -- one call per officer this often

-- @return table the nearest free officers on foot
local function FreeOfficers(actor)
	local origin, list = actor:GetPos(), {}
	for _, officer in ipairs(bgNPC.Actors.GetByTeam('police')) do
		if officer ~= actor and officer:IsAlive() and not officer:InVehicle() and officer:HasNoEnemies() then
			local dist = officer:GetPos():DistToSqr(origin)
			if dist < SEARCH_DIST_SQR then list[#list + 1] = { officer = officer, dist = dist } end
		end
	end
	table.SortByMember(list, 'dist', true)
	return list
end

bgNPC.States.Register('call_backup', 'danger', {
	pre_start = function(actor, _, data)
		actor.backup_until = CurTime() + BACKUP_TIME -- also when nobody is free: don't ask again right away
		data.enemy = actor:GetNearEnemy()
		if not IsValid(data.enemy) or #FreeOfficers(actor) == 0 then return 'defense' end
	end,
	start = function(actor, _, data)
		data.done = CurTime() + CALL_TIME
		actor:Voice('police_backup', 'npc/metropolice/vo/officerneedsassistance.wav')
		actor:GetBody():StopMoving()

		local list = FreeOfficers(actor)
		for i = 1, math.min(#list, MAX_OFFICERS) do
			local officer = list[i].officer
			officer:AddEnemy(data.enemy)
			officer:SetState('defense')
		end
	end,
	update = function(actor, _, data)
		if not IsValid(data.enemy) or data.done < CurTime() then actor:SetState('defense') end
	end,
})
