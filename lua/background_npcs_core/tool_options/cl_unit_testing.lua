bgNPC.unit = {}
bgNPC.unit.TestsList = nil

concommand.Add('bgn_unit_test_add_result', function(ply, cmd, args)
	if not bgNPC.unit or not bgNPC.unit.TestsList then return end
	local name = args[1]
	local result = args[2]

	if not name or not result then return end
	bgNPC.unit.TestsList:AddLine(name, result)
end)

local function TOOL_MENU(Panel)
	Panel:AddControl('Button', {
		['Label'] = 'Start Tests',
		['Command'] = 'bgn_unit_tests_start',
	})

	local MainPanel = vgui.Create('DPanel')
	MainPanel:SetPos(0, 0)
	MainPanel:SetHeight(400)
	MainPanel:SizeToContentsX(-5)

	local BtnStartTests = vgui.Create('DButton', MainPanel)
	BtnStartTests:SetText('Start Tests')
	BtnStartTests:SetPos(10, 10)
	BtnStartTests:SetHeight(30)
	BtnStartTests:SizeToContentsX()

	local TestsList = vgui.Create('DListView', MainPanel)
	TestsList:Dock(FILL)
	TestsList:SetMultiSelect(false)
	TestsList:AddColumn('Test Name')
	TestsList:AddColumn('Result')
	bgNPC.unit.TestsList = TestsList

	Panel:AddPanel(MainPanel)
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_UnitTesting', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Unit_Testing',
		'#bgn.settings.unit_tests_title', '', '', TOOL_MENU)
end)