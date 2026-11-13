local IsValid = IsValid

function slib.IsAlive(ent)
	if not ent or not IsValid(ent) then return false end
	local isNPC = (ent and ent.IsNPC and ent:IsNPC()) or false
	local health = (ent and ent.Health and ent:Health()) or 0

	if health <= 0 then return false end
	if SERVER and isNPC and (not ent or not ent.IsCurrentSchedule or ent:IsCurrentSchedule(SCHED_DIE)) then
		return false
	end
	return true
end

-- slib.Storage.Entities = slib.Storage.Entities or {}

-- function slib.GetAllEntities(has_valid)
-- 	has_valid = has_valid or false

-- 	if has_valid then
-- 		for i = #slib.Storage.Entities, 1, -1 do
-- 			local ent = slib.Storage.Entities[i]
-- 			if not ent or not IsValid(ent) then
-- 				table.remove(slib.Storage.Entities, i)
-- 			end
-- 		end
-- 	end

-- 	return slib.Storage.Entities
-- end

-- hook.Add('InitPostEntity', 'Slib.InitOptimizationEntsWatcher', function()
-- 	slib.Storage.Entities = ents.GetAll()
-- end)

-- hook.Add('OnEntityCreated', 'Slib.OptimizationEntsWatcher', function(ent)
-- 	timer.Simple(0, function()
-- 		if not IsValid(ent) then return end
-- 		slib.Storage.Entities[#slib.Storage.Entities + 1] = ent
-- 	end)
-- end)

-- hook.Add('EntityRemoved', 'Slib.OptimizationEntsWatcher', function(ent)
-- 	for i = #slib.Storage.Entities, 1, -1 do
-- 		if slib.Storage.Entities[i] == ent then
-- 			table.remove(slib.Storage.Entities, i)
-- 			break
-- 		end
-- 	end
-- end)