hook.Add('BGN_InitActor', 'BGN_QuestSystem_DialogueParent', function(actor)
	if QuestDialogue == nil then
		hook.Remove('BGN_InitActor', 'BGN_QuestSystem_DialogueParent')
		return
	end

	QuestDialogue:AutoParentToNPC(actor:GetNPC())
end)

hook.Add('QSystem.StartDialogue', 'BGN_QuestSystem_StartDialogue', function(eDialogue)
	if eDialogue:GetDialogue().isBackground then return end

	local npc = eDialogue:GetNPC()
	if IsValid(npc) and npc:IsNPC() then
		local actor = bgNPC:GetActor(npc)
		if actor ~= nil then
			actor:StopWalk()
			actor:SetState('quest_dialogue')
			actor:StateLock(true)
		end
	end
end)

hook.Add('QSystem.StopDialogue', 'BGN_QuestSystem_StopDialogue', function(eDialogue)
	if eDialogue:GetDialogue().isBackground then return end

	local npc = eDialogue:GetNPC()
	if IsValid(npc) and npc:IsNPC() then
		local actor = bgNPC:GetActor(npc)
		if actor ~= nil then
			actor:StateLock(false)
			actor:RandomState()
		end
	end
end)