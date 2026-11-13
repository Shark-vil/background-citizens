TOOL.AddToMenu = BGN_LOADER ~= 'legacy'
if not TOOL.AddToMenu then return end
TOOL.Category = 'Background NPCs Debug'
TOOL.Name = '#tool.bgn_carry_debug.name'
TOOL.ClientConVar = {
  item = 'suitcase'
}

TOOL.Information = {
  {
    name = 'left'
  },
  {
    name = 'right'
  }
}

local labels = {
  name = {
    default = 'Carried item debugger',
    russian = 'Отладка предметов в руках'
  },
  desc = {
    default = 'Force a carried item on an actor, ignoring spawn chance. Admins only.',
    russian = 'Выдать актору предмет без проверки шанса спавна. Только для администраторов.'
  },
  left = {
    default = 'Give selected item',
    russian = 'Выдать выбранный предмет'
  },
  right = {
    default = 'Remove carried item',
    russian = 'Убрать предмет'
  },
  item = {
    default = 'Item',
    russian = 'Предмет'
  },
  suitcase = {
    default = 'Briefcase',
    russian = 'Кейс'
  },
  ration = {
    default = 'Food parcel',
    russian = 'Еда'
  },
  newspaper = {
    default = 'Newspaper',
    russian = 'Газета'
  },
  failed = {
    default = 'Aim at a living, unarmed actor on foot in a calm state. The model must support this item.',
    russian = 'Наведитесь на живого безоружного актора вне машины в спокойном состоянии. Модель должна поддерживать предмет.'
  },
}

local function L(key, ply)
  return bgNPC.Util.Lang(labels[key], ply)
end

function TOOL:LeftClick(tr)
  if CLIENT then return true end
  local ply = self:GetOwner()
  if not IsValid(ply) or not ply:IsAdmin() then return false end
  local actor = bgNPC.Actors.Get(tr.Entity)
  local kind = self:GetClientInfo('item')
  if not actor or not actor:IsAlive() or actor:InVehicle() or actor:HasActiveWeapon() or not (actor:GetState() == 'none' or actor:EqualStateGroup('calm')) or not bgNPC.CarryItems.Supports(actor:GetNPC(), kind) then
    bgNPC.Util.Notify(ply, L('failed', ply), 'error', 6)
    return false
  end

  actor:SetState('walk', nil, true)
  if not bgNPC.CarryItems.Attach(actor, kind) then
    bgNPC.Util.Notify(ply, L('failed', ply), 'error', 6)
    return false
  end

  actor.carry_initialized = true
  return true
end

function TOOL:RightClick(tr)
  if CLIENT then return true end
  local ply = self:GetOwner()
  if not IsValid(ply) or not ply:IsAdmin() then return false end
  local actor = bgNPC.Actors.Get(tr.Entity)
  if not actor then return false end
  actor.carry_initialized = true
  bgNPC.CarryItems.Remove(actor)
  return true
end

if CLIENT then
  for key in pairs(labels) do
    language.Add('tool.bgn_carry_debug.' .. key, L(key))
  end

  function TOOL.BuildCPanel(panel)
    bgNPC.DebugInspector.ToolControls(panel)
    panel:Help(L('desc'))
    local combo = panel:ComboBox(L('item'), 'bgn_carry_debug_item')
    for _, kind in ipairs({'suitcase', 'ration', 'newspaper'}) do
      combo:AddChoice(L(kind), kind)
    end
  end
end

if CLIENT then
  function TOOL:DrawHUD()
    if self.ReportText then bgNPC.DebugInspector.DrawToolReport(self.ReportText) end
  end
end
