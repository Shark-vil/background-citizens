hook.Add("BGN_PostSpawnNPC", "BGN_QuestSystem_DialogueParent", function(npc, type, data)
	if QuestDialogue == nil then 
		hook.Remove("BGN_PostSpawnNPC", "BGN_QuestSystem_DialogueParent")
		return
	end

	QuestDialogue:AutoParentToNPC(npc)
end)

hook.Add("QSystem.StartDialogue", "BGN_QuestSystem_StartDialogue", function(eDialogue)
	if eDialogue:GetDialogue().isBackground then return end

	local npc = eDialogue:GetNPC()
	if IsValid(npc) and npc:IsNPC() then
		local actor = bgNPC:GetActor(npc)
		if actor ~= nil then
			actor:SetState('quest_dialogue')
			actor:StateLock(true)
		end
	end
end)

hook.Add("QSystem.StopDialogue", "BGN_QuestSystem_StopDialogue", function(eDialogue)
	if eDialogue:GetDialogue().isBackground then return end
	
	local npc = eDialogue:GetNPC()
	if IsValid(npc) and npc:IsNPC() then
		local actor = bgNPC:GetActor(npc)
		if actor ~= nil then
			actor:StateLock(false)
			actor:SetOldState()
		end
	end
end)