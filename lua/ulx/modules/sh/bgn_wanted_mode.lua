local CATEGORY_NAME = 'Background NPCs'

function ulx.bgnsetwantedlevel(calling_ply, target_ply, wanted_level)
   if not wanted_level then return end

   if wanted_level == 0 then
      ulx.fancyLogAdmin(calling_ply, "#A remove wanted level for #T", target_ply)
      ULib.queueFunctionCall(function(target)
         local ASSET = bgNPC:GetModule('wanted')
         if ASSET:HasWanted(target) then
            ASSET:RemoveWanted(target)
         end
      end, target_ply)
   else
		ulx.fancyLogAdmin(calling_ply, "#A set wanted level for #T (#s)", target_ply, wanted_level)
      ULib.queueFunctionCall(function(target, wanted_level)
         local delay = 0

         local ASSET = bgNPC:GetModule('wanted')
         if not ASSET:HasWanted(target) then
            ASSET:AddWanted(target)
            delay = 1
         end

         timer.Simple(delay, function()
            local WANTED_CLASS = ASSET:GetWanted(target)
            WANTED_CLASS:SetLevel(tonumber(wanted_level))
         end)
      end, target_ply, wanted_level)
	end
end
local set_wanted_level = ulx.command(CATEGORY_NAME,
   'ulx bgnsetwantedlevel',
   ulx.bgnsetwantedlevel,
   '!bgnsetwantedlevel'
)

set_wanted_level:addParam{
   type = ULib.cmds.PlayerArg
}

set_wanted_level:addParam{ 
   type = ULib.cmds.StringArg,
   hint = "wanted level",
   ULib.cmds.optional,
   ULib.cmds.takeRestOfLine,
   completes = { 0, 1, 2, 3, 4, 5 }
}

set_wanted_level:defaultAccess(ULib.ACCESS_ADMIN)
set_wanted_level:help("Set wanted level for target.")