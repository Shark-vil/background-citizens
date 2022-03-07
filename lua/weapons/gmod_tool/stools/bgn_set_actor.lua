local surface = surface
local LocalPlayer = LocalPlayer
--

TOOL.Category = 'Background NPCs'
TOOL.Name = 'Set NPC Actor'
TOOL.panel_is_init = false
TOOL.Trace = nil

local function GetTraceNPC(ply)
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 1000,
		filter = function(ent)
			if ent ~= ply and (ent:IsNPC() or ent:IsNextBot()) then
				return true
			end
		end
	})

	if not tr.Hit then
		if CLIENT then
			surface.PlaySound('common/wpn_denyselect.wav')
		end
	else
		return tr.Entity
	end
end

if SERVER then
	snet.Callback('bgn_tool_set_actor', function(_, npc, npc_type)
		local actor = BGN_ACTOR:Instance(npc, npc_type)
		actor.eternal = true
	end).Protect()

	function TOOL:LeftClick()
		if not IsFirstTimePredicted() then return end
		local ply = self:GetOwner()
		if not ply:IsAdmin() or not ply:IsSuperAdmin() then return end
		snet.ClientRPC(self, 'RpcLeftClick')
	end

	function TOOL:RightClick()
		if not IsFirstTimePredicted() then return end
		local ply = self:GetOwner()
		if not ply:IsAdmin() or not ply:IsSuperAdmin() then return end

		local npc = GetTraceNPC(ply)
		if IsValid(npc) and npc.isBgnActor then
			bgNPC:RemoveNPC(npc)
			snet.ClientRPC(self, 'RpcRightClick')
		end
	end
else
	CreateConVar('bgn_tool_set_actor_select_actor', 'citizen', nil, '', 0, 1)

	function TOOL:Think()
		self:UpdateControlPanel()
	end

	function TOOL:RpcRightClick()
		surface.PlaySound('common/blip1.wav')
	end

	function TOOL:RpcLeftClick()
		local npc = GetTraceNPC(LocalPlayer())

		if IsValid(npc) and not npc.isBgnActor and (npc:IsNPC() or npc:IsNextBot()) then
			snet.InvokeServer('bgn_tool_set_actor', npc, GetConVar('bgn_tool_set_actor_select_actor'):GetString())
			surface.PlaySound('common/wpn_select.wav')
		else
			surface.PlaySound('common/wpn_denyselect.wav')
		end
	end

	function TOOL:UpdateControlPanel()
		local panel = controlpanel.Get('bgn_set_actor')
		if not panel then bgNPC:Log('Couldn\'t find bgn_set_actor panel!', 'Tool') return end

		if self.panel_is_init then return end
		self.panel_is_init = true

		panel:ClearControls()

		local select_actor_options_table = {}

		for npcType, v in pairs(bgNPC.cfg.npcs_template) do
			select_actor_options_table[npcType] = { ['bgn_tool_set_actor_select_actor'] = npcType }
		end

		panel:AddControl('ListBox', {
			['Label'] = 'Select actor type',
			['Command'] = 'bgn_tool_set_actor_select_actor',
			['Options'] = select_actor_options_table
		})
	end
end