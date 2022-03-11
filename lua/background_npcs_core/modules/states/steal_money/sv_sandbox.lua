local weapon_ignore = {
   'gmod_camera',
   'weapon_fists',
   'weapon_medkit',
   'gmod_tool',
   'hands_obs',
   'hand',
   'hands',
   'blank',
   'weaponholster',
   'weapon_physgun',
   'weapon_physcannon',
}

hook.Add('BGN_StealFinish', 'BGN_Sandbox_StealMoney', function(actor, target, success)
   if not success then return end
   if engine.ActiveGamemode() ~= 'sandbox' then return end

   local stealWeapon
   local activeWeapon = target:GetActiveWeapon()

   for _, weapon in ipairs(target:GetWeapons()) do
      if activeWeapon ~= weapon and not table.HasValueBySeq(weapon_ignore, weapon:GetClass()) then
         stealWeapon = weapon
         break
      end
   end

   if not stealWeapon then return end

   local weapon_class = stealWeapon:GetClass()
   local npc = actor:GetNPC()
   npc:slibSetVar('weaponStealData', {
      class = weapon_class,
      clip1 = stealWeapon:Clip1(),
      clip2 = stealWeapon:Clip2()
   })

   target:StripWeapon(weapon_class)
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_Sandbox_DropStealMoney', function(attacker, target)
   if engine.ActiveGamemode() ~= 'sandbox' then return end
   if not target:slibGetVar('is_stealer') then return end

   if attacker:IsNPC() then
      local actor = bgNPC:GetActor(attacker)
      if actor == nil or not actor:HasTeam('police') then return end
   elseif not attacker:IsPlayer() then return end

   local weaponStealData = target:slibGetVar('weaponStealData', nil)
   if weaponStealData then
      local weapon = ents.Create(weaponStealData.class)
      weapon:SetPos(target:GetPos() + target:GetUp() * 10 + target:GetForward() * 20)
      weapon:SetClip1(weaponStealData.clip1)
      weapon:SetClip2(weaponStealData.clip2)
      weapon:Spawn()

      target:slibSetVar('weaponStealData', nil)
   end
end)