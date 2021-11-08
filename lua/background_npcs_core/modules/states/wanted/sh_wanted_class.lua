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

function ASSET:Instance(ent)
	local wanted_time = GetConVar('bgn_wanted_time'):GetFloat()
	local wanted_time_reset = CurTime() + wanted_time
	local public = {}
	public.target = ent
	public.time_reset =  wanted_time_reset
	public.time = wanted_time
	public.wait_time = wanted_time
	public.level = 1
	public.level_max = 5
	public.next_kill_update = bgNPC.cfg.wanted.levels[1]

	function public:UpdateWanted()
		self.time_reset = CurTime() + self.time
		self.wait_time = self.time

		if SERVER then
			snet.InvokeAll('bgn_module_wanted_UpdateWanted', ent)
		end
	end

	function public:UpdateWaitTime(time)
		self.wait_time = time

		if SERVER then
			snet.InvokeAll('bgn_module_wanted_UpdateWaitTime', ent, time)
		end
	end

	function public:SetLevel(level)
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
	end

	function public:LevelUp()
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
	end

	function public:LevelDown()
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
	end

	return public
end

function ASSET:AddWanted(ent)
	if self:HasWanted(ent) then return end

	if SERVER and not ent:IsPlayer() then
		local ArrestComponent = bgNPC:GetModule('player_arrest')
		if ArrestComponent then
			ArrestComponent:RemovePlayer(ent)
		end
	end

	local WantedClass = self:Instance(ent)
	table.insert(wanted_list, WantedClass)

	if SERVER then
		snet.InvokeAll('bgn_module_wanted_AddWanted', ent)
	end

	hook.Run('BGN_AddWantedTarget', ent)
	bgNPC:Log('AddWanted - ' .. tostring(ent), 'Module | Wanted')

	return WantedClass
end

function ASSET:RemoveWanted(ent)
	local _, index = self:GetWanted(ent)
	if index == -1 then return false end

	table.remove(wanted_list, index)

	if SERVER then
		snet.InvokeAll('bgn_module_wanted_RemoveWanted', ent)
	end

	hook.Run('BGN_RemoveWantedTarget', ent)
	bgNPC:Log('RemoveWanted - ' .. tostring(ent), 'Module | Wanted')

	return true
end

function ASSET:ClearAll()
	bgNPC:Log('ClearAll', 'Module | Wanted')
	wanted_list = {}
end

function ASSET:ClearDeath()
	for i = #wanted_list, 1, -1 do
		local WantedClass = wanted_list[i]
		local target = WantedClass.target

		if not IsValid(target) or target:Health() <= 0 then
			table.remove(wanted_list, i)
			bgNPC:Log('RemoveWanted - ' .. tostring(target), 'Module | Wanted')
		end
	end
end

function ASSET:HasWanted(ent)
	if not IsValid(ent) then return false end
	return table.WhereHasValueBySeq(wanted_list, function(k, v) return v.target == ent end)
end

function ASSET:GetWanted(ent)
	for i = 1, #wanted_list do
		local WantedClass = wanted_list[i]
		if WantedClass.target == ent then
			return WantedClass, i
		end
	end
	return nil, -1
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