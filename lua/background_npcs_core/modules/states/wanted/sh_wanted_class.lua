local bgNPC = bgNPC
local SERVER = SERVER
local IsValid = IsValid
local GetConVar = GetConVar
local CurTime = CurTime
local isnumber = isnumber
local hook = hook
local table = table
local list = list
--
local ASSET = {}
local wanted_list = {}

function ASSET:AddWanted(ent)
	if IsValid(ent) and wanted_list[ent] == nil then
		local wanted_time = GetConVar('bgn_wanted_time'):GetFloat()
		local wanted_time_reset = CurTime() + wanted_time

		if SERVER and not ent:IsPlayer() then
			bgNPC:GetModule('player_arrest'):RemovePlayer(ent)
		end

		local c_Wanted = {
			time_reset =  wanted_time_reset,
			time = wanted_time,
			wait_time = wanted_time,
			level = 1,
			level_max = 5,
			next_kill_update = bgNPC.cfg.wanted.levels[1],

			UpdateWanted = function(self)
				self.time_reset = CurTime() + self.time
				self.wait_time = self.time

				if SERVER then
					snet.InvokeAll('bgn_module_wanted_UpdateWanted', ent)
				end
			end,

			UpdateWaitTime = function(self, time)
				self.wait_time = time

				if SERVER then
					snet.InvokeAll('bgn_module_wanted_UpdateWaitTime', ent, time)
				end
			end,

			SetLevel = function(self, level)
				if not isnumber(level) or level <= 0 then
					ASSET:RemoveWanted(ent)
					return
				elseif level > self.level_max then
					level = self.level_max
				end

				self.level = level

				if SERVER then
					snet.InvokeAll('bgn_module_wanted_UpdateLevel', ent, self.level)
				end

				local cfg_kills = bgNPC.cfg.wanted.levels[self.level]
				self.next_kill_update = bgNPC:GetWantedKillingStatisticSumm(ent) + cfg_kills
			end,

			LevelUp = function(self)
				if not GetConVar('bgn_wanted_level'):GetBool() then return end

				if self.level + 1 <= self.level_max then
					self.level = self.level + 1

					if SERVER then
						snet.InvokeAll('bgn_module_wanted_UpdateLevel', ent, self.level)
					end

					local cfg_kills = bgNPC.cfg.wanted.levels[self.level]
					self.next_kill_update = self.next_kill_update + cfg_kills

					hook.Run('BGN_WantedLevelUp', ent, self.next_kill_update)
				end
			end,

			LevelDown = function(self)
				if self.level - 1 > 0 then
					self.level = self.level - 1
					if self.level == 0 then
						ASSET:RemoveWanted(ent)
					elseif SERVER then
						snet.InvokeAll('bgn_module_wanted_UpdateLevel', ent, self.level)
					end

					local cfg_kills = bgNPC.cfg.wanted.levels[self.level + 1]
					self.next_kill_update = self.next_kill_update - cfg_kills

					if self.next_kill_update < 0 then
						self.next_kill_update = 0
					end

					hook.Run('BGN_WantedLevelDown', ent, self.next_kill_update)
				end
			end,
		}

		wanted_list[ent] = c_Wanted

		if SERVER then
			snet.InvokeAll('bgn_module_wanted_AddWanted', ent)
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
			snet.InvokeAll('bgn_module_wanted_RemoveWanted', ent)
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

hook.Add('PlayerDeath', 'BGN_WantedModule_PlayerDeathRemoveWanted', function(ply)
	if ASSET:HasWanted(ply) then ASSET:RemoveWanted(ply) end
end)

timer.Create('BGN_WantedModule_AutoClearDeathTargets', 1, 0, function()
	ASSET:ClearDeath()
end)

list.Set('BGN_Modules', 'wanted', ASSET)