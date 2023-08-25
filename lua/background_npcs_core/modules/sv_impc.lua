local IsValid = IsValid

hook.Add('BGN_InitActor', 'BGN_iMPC_Integration', function(actor)
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	npc.inpcIgnore = true
	print('блок inpc')
end)