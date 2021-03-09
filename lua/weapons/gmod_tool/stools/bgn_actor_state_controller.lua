--[=[
TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_actor_state_controller.name"

TOOL.PanelIsInit = false
TOOL.IsBGNActorStateController = true
TOOL.Trace = nil
TOOL.Distance = 10000
TOOL.Actor = nil
TOOL.Target = NULL

function TOOL:GetToolOwner()
	local ply = self:GetOwner()
	if not ply:IsAdmin() or not ply:IsSuperAdmin() then return NULL end
	return ply
end

function TOOL:LeftClick()
	if CLIENT then return end

	local ply = self:GetToolOwner()
	if not IsValid(ply) then return end

	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
		filter = function(ent)
			if ent ~= ply and ent:IsNPC() then
				return true
			end
		end
	})

	if not tr.Hit then return end

	local ent = tr.Entity

	if self.Actor == nil then
		self:SelectActor(ent)
	elseif self.Actor:GetNPC() ~= ent then
		self:SelectTarget(ent)
	end
end

function TOOL:SelectActor(ent)
	local actor = bgNPC:GetActor(ent)
	if actor == nil then
		bgNPC:Log('Failed to convert ' .. tostring(ent) .. ' to actor', 'Debugger')
		return
	end

	if CLIENT then return end

	snet.IsValidForClient(ply, function(ply, success)
		bgNPC:Log('Actor validator result: ' .. tostring(ply) .. ' - ' ..  tostring(success), 'Debugger')

		if success then
         actor:SetState('none')
         actor.debugger = true
			actor.eternal = true
			
         self.Actor = actor

			snet.Invoke('bgn_tool_actor_state_controller_left_click', ply, ent)
		end
	end, 'actor', 'bgn_debugger_tool', nil, ent)
end

function TOOL:SelectTarget(ent)
	
end

function TOOL:Reload()
   if CLIENT then return end
	if self.Actor == nil then return end

	local ply = self:GetToolOwner()
	if not IsValid(ply) then return end

	self.Actor.debugger = false
	self.Actor.eternal = false
	self.Actor:RandomState()
	self.Actor = nil
	
	snet.Invoke('bgn_tool_actor_state_controller_reload_click', ply)
end

function TOOL:Think()
	if CLIENT then
		self:UpdateControlPanel()
	end
end

if CLIENT then
	function TOOL:UpdateControlPanel()
		local Panel = controlpanel.Get( "bgn_tool_actor_state_controller" )
		if not Panel then bgNPC:Log("Couldn't find bgn_tool_actor_state_controller panel!", 'Tool') return end
		if self.PanelIsInit then return end
	
		self.PanelIsInit = true
	
		Panel:ClearControls()
		
		Panel:AddControl("ListBox", {
			['Label'] = "Буба хуба",
			['Options'] = {
				['key'] = {
					['subkey'] = 'val'
				}
			},
		})
	end

	local function GetRealTool()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNActorStateController then return nil end
		return tool
	end

	snet.RegisterCallback('bgn_tool_actor_state_controller_reload_click', function(ply, ent)
		local tool = GetRealTool()
		if tool == nil then return end

      tool.Actor = nil
	end)

	snet.RegisterCallback('bgn_tool_actor_state_controller_left_click', function(ply, ent)
		local tool = GetRealTool()
		if tool == nil then return end

		if tool.Actor == nil then
			tool:SelectActor(ent)
		else
			tool:SelectTarget(ent)
		end
	end)
	
	local en_lang = {
		['tool.bgn_actor_state_controller.name'] = 'Actor state controller',
		['tool.bgn_actor_state_controller.desc'] = '',
		['tool.bgn_actor_state_controller.0'] = '',
	}

	local ru_lang = {
		['tool.bgn_actor_state_controller.name'] = 'Контроллер состояний актёров',
		['tool.bgn_actor_state_controller.desc'] = '',
		['tool.bgn_actor_state_controller.0'] = '',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end
end
--]=]