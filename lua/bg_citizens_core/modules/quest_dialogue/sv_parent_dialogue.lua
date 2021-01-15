hook.Add("BGN_PostSpawnNPC", "BGN_QuestSystem_DialogueParent", function(actor)
    if QuestDialogue == nil then 
        hook.Remove("BGN_PostSpawnNPC", "BGN_QuestSystem_DialogueParent")
        return
    end

    QuestDialogue:AutoParentToNPC(actor:GetNPC())
end)