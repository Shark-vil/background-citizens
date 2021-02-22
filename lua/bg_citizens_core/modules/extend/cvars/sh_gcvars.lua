bgNPC.GlobalCvars = bgNPC.GlobalCvars or {}

function bgNPC:RegisterGlobalCvar(cvar_name, value, flag, helptext, min, max)
   if bgNPC.GlobalCvars[cvar_name] == nil then
      helptext = helptext or ''

      CreateConVar(cvar_name, value, flag, helptext, min, max)

      bgNPC.GlobalCvars[cvar_name] = {
         value = GetConVar(cvar_name):GetFloat(),
         flag = flag,
         helptext = helptext,
         min = min,
         max = max
      }
   end
end