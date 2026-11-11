TOOL.Category = 'Background NPCs'
TOOL.Name = '#tool.bgn_scenic_debug.name'
TOOL.ClientConVar = { scene = 'door_knock' }
TOOL.Information = { { name = 'left' }, { name = 'right' }, { name = 'reload' } }

local labels = {
	name = { default = 'Scene debugger', russian = 'Отладка сцен' },
	desc = { default = 'Place scenic scenes and test GOAP doors. Admins only.', russian = 'Создание scenic-сцен и проверка дверей GOAP. Только для администраторов.' },
	left = { default = 'Create the selected test', russian = 'Создать выбранный тест' },
	right = { default = 'Inspect an actor; click empty space for the last scene', russian = 'Осмотреть актора; пустое место — последняя сцена' },
	reload = { default = 'Remove the last test (Undo also works)', russian = 'Удалить последний тест (также работает Undo)' },
	choose = { default = 'Scene / test', russian = 'Сцена / тест' },
	help = { default = 'Click floor, a wall near the floor, directly on a closed door panel, or a supported chair. Knocking needs no lock. Normal actor models and body settings apply. Visible placement is allowed for this admin tool.',
		russian = 'Нажмите на пол, стену у пола, прямо на полотно закрытой двери или подходящий стул. Для стука замок не нужен. Модели и тип тела берутся из обычных настроек акторов. Для админского теста разрешён видимый спавн.' },
	door_help = { default = 'GOAP door test: aim at a closed unlocked door. Creates two normal actors; gives this pair GOAP, lowers the holder health, runs one kick and recovery. Server body/brain settings stay unchanged.',
		russian = 'Тест двери GOAP: наведитесь на закрытую незапертую дверь. Создаёт двух обычных акторов, включает GOAP для этой пары, снижает здоровье удерживающего и проверяет один удар и подъём. Настройки тела и мозга сервера не меняются.' },
	manual = { default = 'manual only', russian = 'только вручную' },
	placement = { default = 'Couches and the radio desk require an enclosed room. Ledge seating needs a wide, flat edge with room for the legs.',
		russian = 'Диваны и радист требуют закрытого помещения. Для сидения на уступе нужен широкий ровный край с местом для ног.' },
	goap_door = { default = 'GOAP: hold, breach, recover', russian = 'GOAP: удерживание, выбивание, подъём' },
	inspect = { default = 'Inspection', russian = 'Осмотр' },
	state = { default = 'State', russian = 'Состояние' },
	model = { default = 'Model', russian = 'Модель' },
	sequence = { default = 'Sequence', russian = 'Анимация' },
	door = { default = 'Door', russian = 'Дверь' },
	failed = { default = 'Missing sequence / setup rejected', russian = 'Нет анимации / постановка отклонена' },
	removed = { default = 'Test removed', russian = 'Тест удалён' },
	preparing = { default = 'Preparing', russian = 'Подготовка' },
	waiting = { default = 'Waiting for door hold', russian = 'Ожидание удерживания' },
	breaching = { default = 'Police approaching / kicking', russian = 'Полиция подходит / выбивает' },
	recovering = { default = 'Ragdoll / recovery', russian = 'Регдолл / подъём' },
	done = { default = 'Cycle completed', russian = 'Цикл завершён' },
	ended = { default = 'Actor or door removed / killed', russian = 'Актор или дверь удалены / актор погиб' },
	timeout = { default = 'Timed out: check navigation, models and free space', russian = 'Время вышло: проверьте навигацию, модели и свободное место' },
	closed = { default = 'closed', russian = 'закрыта' },
	open = { default = 'open / moving', russian = 'открыта / движется' },
	model_error = { default = 'Holder model has no doorbracer sequence', russian = 'У модели удерживающего нет анимации doorbracer' },
}

local function L(ply, key)
	return bgNPC.Util.Lang(labels[key] or { default = key }, ply)
end



if SERVER then
	local function ActorLines(ply, actor, detailed)
		local npc = actor:GetNPC()
		if not actor:IsAlive() or not IsValid(npc) then return { '#' .. tostring(actor.uid) .. ': ' .. L(ply, 'ended') } end
		local lines = { string.format('#%s %s | %s: %s | HP %s', actor.uid, npc:GetClass(), L(ply, 'state'), actor:GetState(), actor:Health()) }
		if detailed then
			lines[#lines + 1] = L(ply, 'model') .. ': ' .. npc:GetModel()
			lines[#lines + 1] = L(ply, 'sequence') .. ': ' .. npc:GetSequenceName(npc:GetSequence())
			local data = actor:GetStateData()
			local door = data.door or (data.spot and data.spot.door)
			if IsValid(door) then lines[#lines + 1] = L(ply, 'door') .. ' #' .. door:EntIndex() .. ': ' .. L(ply, bgNPC.Doors.IsClosed(door) and 'closed' or 'open') end
			local brain = actor.brain
			if brain and brain.goal then lines[#lines + 1] = 'GOAP: ' .. brain.goal.name end
		end
		return lines
	end

	function TOOL:Report()
		local ply, item = self:GetOwner(), self.LastItem
		local lines = {}
		if self.SelectedActor then
			lines = ActorLines(ply, self.SelectedActor, true)
		elseif item then
			lines[1] = item.id .. (item.phase and ' | ' .. L(ply, item.phase == 'model' and 'model_error' or item.phase) or '')
			if item.debug_removed or item.removed then lines[#lines + 1] = L(ply, 'removed') end
			for _, actor in ipairs(item.actors) do
				for _, line in ipairs(ActorLines(ply, actor, #item.actors == 1)) do lines[#lines + 1] = line end
			end
			for _, failure in ipairs(item.failures or {}) do
				local seq = istable(failure.sequences) and table.concat(failure.sequences, ', ') or failure.sequences
				lines[#lines + 1] = L(ply, 'failed') .. ': ' .. failure.type .. ' [' .. failure.model .. '] ' .. tostring(seq)
			end
		end
		bgNPC.Net.ToolRPC(self, 'SetReport', table.concat(lines, '\n'))
	end

	function TOOL:LeftClick(tr)
		local ply, debug = self:GetOwner(), bgNPC.Scenic.Debug
		if not debug.Allowed(ply) then return false end
		if (self.NextSpawn or 0) > CurTime() then return false end
		self.NextSpawn = CurTime() + 0.5
		local id = self:GetClientInfo('scene')
		local item, reason
		if id == 'goap_door' then item, reason = debug.DoorTest(ply, tr)
		else item, reason = debug.Spawn(ply, id, tr) end
		if not item then
			local message = debug.Message(ply, reason)
			bgNPC.Util.Notify(ply, message, 'error', 6)
			bgNPC.Net.ToolRPC(self, 'SetReport', message)
			return false
		end
		self.LastItem, self.SelectedActor = item, nil
		self:Report()
		return true
	end

	function TOOL:RightClick(tr)
		local ply = self:GetOwner()
		if not bgNPC.Scenic.Debug.Allowed(ply) then return false end
		self.SelectedActor = bgNPC.Actors.Get(tr.Entity) or (IsValid(tr.Entity) and tr.Entity.bgn_knocked_actor or nil)
		self:Report()
		local actor = self.SelectedActor
		if actor and actor.brain and actor.brain.Describe then ply:PrintMessage(HUD_PRINTCONSOLE, actor.brain:Describe() .. '\n') end
		return true
	end

	function TOOL:Reload()
		local ply = self:GetOwner()
		if not bgNPC.Scenic.Debug.Allowed(ply) then return false end
		if not bgNPC.Scenic.Debug.Remove(ply, self.LastItem) then return false end
		self.SelectedActor = nil
		self:Report()
		return true
	end

	function TOOL:Think()
		if (self.NextReport or 0) > CurTime() then return end
		self.NextReport = CurTime() + 0.5
		if bgNPC.Scenic.Debug.Allowed(self:GetOwner()) then self:Report() end
	end
	return
end

for _, key in ipairs({ 'name', 'desc', 'left', 'right', 'reload' }) do language.Add('tool.bgn_scenic_debug.' .. key, L(nil, key)) end

function TOOL:LeftClick() return true end
function TOOL:RightClick() return true end
function TOOL:Reload() return true end
function TOOL:SetReport(text) self.ReportText = text end

function TOOL:DrawHUD()
	if not self.ReportText or self.ReportText == '' then return end
	local lines = string.Explode('\n', self.ReportText)
	surface.SetFont('DermaDefault')
	local width = 0
	for _, line in ipairs(lines) do width = math.max(width, surface.GetTextSize(line)) end
	local y = math.min(ScrH() * 0.55, ScrH() - #lines * 17 - 24)
	draw.RoundedBox(4, 16, y - 8, math.min(width + 24, ScrW() - 32), #lines * 17 + 16, Color(0, 0, 0, 200))
	for i, line in ipairs(lines) do draw.SimpleText(line, 'DermaDefault', 24, y + (i - 1) * 17, color_white) end
end

function TOOL.BuildCPanel(panel)
	panel:Help(L(nil, 'help'))
	local choices = panel:ComboBox(L(nil, 'choose'), 'bgn_scenic_debug_scene')
	for id, scene in SortedPairs(bgNPC.cfg.scenic) do
		local name = bgNPC.Util.Lang(scene.name or { default = id })
		choices:AddChoice(name .. ' (' .. id .. ')' .. (scene.weight == 0 and ' [' .. L(nil, 'manual') .. ']' or ''), id)
	end
	choices:AddChoice(L(nil, 'goap_door'), 'goap_door')
	panel:Help(L(nil, 'door_help'))
	panel:Help(L(nil, 'placement'))
	panel:Help(L(nil, 'right') .. '. ' .. L(nil, 'reload') .. '.')
end
