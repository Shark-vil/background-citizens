local GetConVar = GetConVar
local table_HasValueBySeq = table.HasValueBySeq
local table_insert = table.insert
local pairs = pairs
local weapons_GetList = weapons.GetList
local weapons_IsBasedOn = weapons.IsBasedOn
local math_random = math.random
--
local tfa_weapons_blacklist = {
	'tfa_projecthl2_crossbow',
}

hook.Add('BGN_PostSelectWeapon', 'BGN_Arc9WeaponReplacment', function(actor, npc, weapon_class)
	local rep_wep_base_table = {}

	local rep_arc9 = GetConVar('bgn_module_arc9_weapon_replacement'):GetBool()
	local rep_arccw = GetConVar('bgn_module_arccw_weapon_replacement'):GetBool()
	-- local rep_mw = GetConVar('bgn_module_mw_weapon_replacement'):GetBool()
	local rep_tfa = GetConVar('bgn_module_tfa_weapon_replacement'):GetBool()

	if rep_arc9 then table_insert(rep_wep_base_table, 'arc9') end
	if rep_arccw then table_insert(rep_wep_base_table, 'arccw') end
	-- if rep_mw then table_insert(rep_wep_base_table, 'mw') end
	if rep_tfa then table_insert(rep_wep_base_table, 'tfa') end

	local give_base_name = rep_wep_base_table[math_random(1, #rep_wep_base_table)]
	if give_base_name == 'arc9' then
		if not ARC9 then return end
		ARC9.ReplaceSpawnedWeapon(npc)
	elseif give_base_name == 'arccw' then
		local arcw_replacement = slib.Component('Hook', 'Get', 'OnEntityCreated', 'ArcCW_NPCWeaponReplacement')
		if not arcw_replacement then return end
		arcw_replacement(npc)
	elseif give_base_name == 'tfa' then
		local tfa_weapons = {}

		for _, wep in pairs(weapons_GetList()) do
			if not wep or not wep.Spawnable or wep.AdminOnly then
				continue
			end

			local tfa_class = wep.ClassName
			if not weapons_IsBasedOn(tfa_class, 'tfa_gun_base') or table_HasValueBySeq(tfa_weapons_blacklist, tfa_class) then
				continue
			end

			table_insert(tfa_weapons, tfa_class)
		end

		local tfa_weapons_count = #tfa_weapons
		if tfa_weapons_count == 0 then return end

		local new_weapon_class = tfa_weapons[math_random(1, tfa_weapons_count)]

		-- local active_weapon = npc:GetActiveWeapon()
		-- if IsValid(active_weapon) then
		-- 	active_weapon:Remove()
		-- end

		npc:Give(new_weapon_class)
		npc:SelectWeapon(new_weapon_class)
	end
end)