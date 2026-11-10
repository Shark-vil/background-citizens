--[[
	Gang members (config/actors/sh_gangs.lua): a light one wears HL2 citizen clothes (group01) and carries a pistol,
	a heavy one wears rebel gear (group03) and carries an SMG or a rifle. The clothes sheet of the model is replaced
	with the gang's recolor (materials/background_npcs/gangs/<gang>/<class>_<sex>, made by tools/make_gang_skins.py)
	through SetSubMaterial; the class is read back from the model, so it also survives revival and leaving a car.
--]]

local LIGHT = {}
local HEAVY = {}
for _, id in ipairs({ '01', '02', '03', '04', '05', '06', '07', '08', '09' }) do
	LIGHT[#LIGHT + 1] = 'models/humans/group01/male_' .. id .. '.mdl'
	HEAVY[#HEAVY + 1] = 'models/humans/group03/male_' .. id .. '.mdl'
end
for _, id in ipairs({ '01', '02', '03', '04', '06', '07' }) do
	LIGHT[#LIGHT + 1] = 'models/humans/group01/female_' .. id .. '.mdl'
	HEAVY[#HEAVY + 1] = 'models/humans/group03/female_' .. id .. '.mdl'
end

-- @param npc entity
-- @param gang string 'crows' | 'wolves'
local function Dress(npc, gang)
	if not IsValid(npc) then return end
	local model = npc:GetModel() or ''
	local class = model:find('group03', 1, true) and 'heavy' or 'light'
	local sex = model:find('female', 1, true) and 'female' or 'male'
	local material = 'background_npcs/gangs/' .. gang .. '/' .. class .. '_' .. sex
	for index, name in ipairs(npc:GetMaterials()) do
		if name:find('_sheet', 1, true) then npc:SetSubMaterial(index - 1, material) end
	end
end

-- The class is the model: picked before the spawn, "unique" (4) keeps it on an npc_citizen.
hook.Add('BGN_PreSpawnActor', 'BGN_Gangs_Model', function(npc, npc_type, data)
	if not data.gang then return end
	local models = math.random(100) <= (data.heavy_chance or 0) and HEAVY or LIGHT
	npc:SetKeyValue('citizentype', 4)
	npc:SetModel(models[math.random(#models)])
end)

hook.Add('BGN_InitActor', 'BGN_Gangs_Weapon', function(actor)
	local data = actor:GetData()
	if not data.gang then return end
	local heavy = actor:GetNPC():GetModel():find('group03', 1, true) ~= nil
	local weapons = heavy and data.heavy_weapons or data.light_weapons
	if weapons and #weapons ~= 0 and actor.weapon then actor.weapon = weapons[math.random(#weapons)] end
	Dress(actor:GetNPC(), data.gang)
end)

hook.Add('BGN_ActorEntityChanged', 'BGN_Gangs_Dress', function(actor, _, npc)
	local gang = actor:GetData().gang
	if gang then Dress(npc, gang) end
end)
