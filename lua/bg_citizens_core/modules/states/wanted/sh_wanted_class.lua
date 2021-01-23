local ASSET = {}
local wanted_list = {}

function ASSET:AddWanted(ent)
    if IsValid(ent) and wanted_list[ent] == nil then
        local wanted_time = GetConVar('bgn_wanted_time'):GetFloat()
        local wanted_time_reset = CurTime() + wanted_time

        local c_Wanted = {
            time_reset =  wanted_time_reset,
            time = wanted_time,
            wait_time = wanted_time,
            level = 1,
            level_max = 5,
            next_kill_update = 5,

            UpdateWanted = function(self)
                self.time_reset = CurTime() + self.time
                self.wait_time = self.time

                if SERVER then
                    bgNPC:TemporaryVectorVisibility(ent, 3)
                    timer.Simple(1, function() 
                        if not IsValid(ent) then return end
                        net.InvokeAll('bgn_module_wanted_UpdateWanted', ent)
                    end)
                end
            end,
            
            UpdateWaitTime = function(self, time)
                self.wait_time = time

                if SERVER then
                    bgNPC:TemporaryVectorVisibility(ent, 3)
                    timer.Simple(1, function() 
                        if not IsValid(ent) then return end
                        net.InvokeAll('bgn_module_wanted_UpdateWaitTime', ent, time)
                    end)
                end
            end,

            LevelUp = function(self)
                if self.level + 1 <= self.level_max then
                    self.level = self.level + 1

                    bgNPC:TemporaryVectorVisibility(ent, 3)
                    timer.Simple(1, function() 
                        if not IsValid(ent) then return end
                        net.InvokeAll('bgn_module_wanted_UpdateLevel', ent, self.level)
                    end)

                    self.next_kill_update = self.next_kill_update + 10
                end
            end,

            LevelDown = function(self)
                if self.level - 1 > 0 then
                    self.level = self.level - 1
                    if self.level == 0 then
                        ASSET:RemoveWanted(ent)
                    else
                        bgNPC:TemporaryVectorVisibility(ent, 3)
                        timer.Simple(1, function() 
                            if not IsValid(ent) then return end
                            net.InvokeAll('bgn_module_wanted_UpdateLevel', ent, self.level)
                        end)
                    end

                    self.next_kill_update = self.next_kill_update - 10
                end
            end,
        }

        wanted_list[ent] = c_Wanted

        if SERVER then
            bgNPC:TemporaryVectorVisibility(ent, 3)
            timer.Simple(1, function() 
                if not IsValid(ent) then return end
                net.InvokeAll('bgn_module_wanted_AddWanted', ent)
            end)
        end

        hook.Run('BGN_AddWantedTarget', ent)
        bgNPC:Log('AddWanted - ' .. tostring(ent), 'Module | Wanted')

        return true
    end
    return false
end

function ASSET:RemoveWanted(ent)
    if IsValid(ent) and wanted_list[ent] ~= nil then
        wanted_list[ent] = nil

        if SERVER then
            bgNPC:TemporaryVectorVisibility(ent, 3)
            timer.Simple(1, function() 
                if not IsValid(ent) then return end
                net.InvokeAll('bgn_module_wanted_RemoveWanted', ent)
            end)
        end

        hook.Run('BGN_RemoveWantedTarget', ent)
        bgNPC:Log('RemoveWanted - ' .. tostring(ent), 'Module | Wanted')

        return true
    end
    return false
end

function ASSET:ClearAll()
    bgNPC:Log('ClearAll', 'Module | Wanted')
    table.Empty(wanted_list)
end

function ASSET:ClearDeath()
    local t = {}

    for ent, c_Wanted in pairs(wanted_list) do
        if IsValid(ent) and ent:Health() > 0 then
            t[ent] = c_Wanted
        else
            bgNPC:Log('RemoveWanted - ' .. tostring(ent), 'Module | Wanted')
        end
    end

    wanted_list = t
end

function ASSET:HasWanted(ent)
    if IsValid(ent) and wanted_list[ent] ~= nil then
        return true
    end
    return false
end

function ASSET:GetWanted(ent)
    return wanted_list[ent]
end

function ASSET:GetAllWanted()
    return wanted_list
end

hook.Add('PostCleanupMap', 'BGN_WantedModule_ClearWantedListOnCleanupMap', function()
    ASSET:ClearAll()
end)

if CLIENT then
    timer.Create('BGN_WantedModule_AutoClearDeathTargets', 1, 0, function()
        ASSET:ClearDeath()
    end)
end

list.Set('BGN_Modules', 'wanted', ASSET)