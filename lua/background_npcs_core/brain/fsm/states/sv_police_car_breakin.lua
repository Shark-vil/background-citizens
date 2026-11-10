--[[
	An officer goes to break into the car of a suspect (a player or an actor) who stands still in it
	(systems/arrest/sv_car_breakin.lua starts it and runs the break-in). It holds fire on the way: its enemies are put
	aside and come back when the state stops, so driving off turns it back into a fight. The suspect is its target meanwhile.
	data.target: the suspect's entity.
--]]

local ArrestModule = bgNPC.Modules.Get('player_arrest')
local REACH_SQR = 120 ^ 2

-- back to the fight (the enemies return in stop), or walk; never stay here
local function Leave(actor, data)
	data.leaving = true
	actor:SetState(#data.enemies ~= 0 and 'defense' or 'walk')
	if actor:HasState('police_car_breakin') then actor:SetState('walk', nil, true) end
end

bgNPC.States.Register('police_car_breakin', 'guarded', {
	pre_start = function(actor, state, data)
		local ply = data.target
		-- the suspect drove off, stepped out or died: no called break-in any more
		if not ArrestModule:BreakinCar(ply) then return true end
		if actor:InVehicle() then actor:ExitVehicle() end

		local enemies = table.Copy(actor.enemies)
		actor:RemoveAllEnemies()
		actor.mechanics.enemies_controller = false
		local body = actor:GetBody()
		body:SetDisposition(body:GetEnemy(), D_NU) -- the car (the enemy while the player drives)
		actor:AddTarget(ply)

		return state, { target = ply, enemies = enemies }
	end,
	-- nothing else pulls it away (a body to inspect, a chat, a random state); forced changes (arrest) still do
	not_stop = function(actor, state, data)
		return not data.leaving
	end,
	update = function(actor, state, data)
		local car = ArrestModule:BreakinCar(data.target)
		if not car then return Leave(actor, data) end

		local npc = actor:GetNPC()
		if npc:GetPos():DistToSqr(car:GetPos()) > REACH_SQR then
			if actor:CheckMoveUpdate('state_police_car_breakin', 1) then actor:WalkToTarget(car, 'run') end
		else
			actor:WalkToTarget(nil)
			npc:SetAngles(Angle(0, (car:GetPos() - npc:GetPos()):Angle().y, 0))
		end
	end,
	stop = function(actor, state, data)
		actor.mechanics.enemies_controller = true
		actor:RemoveTarget(data.target)
		for _, enemy in ipairs(data.enemies or {}) do
			-- an arrested player died silently (KillSilent may leave health above 0)
			if IsValid(enemy) and enemy:Health() > 0 and not (enemy:IsPlayer() and not enemy:Alive()) then actor:AddEnemy(enemy) end
		end
		actor:WalkToTarget(nil)
	end,
})
