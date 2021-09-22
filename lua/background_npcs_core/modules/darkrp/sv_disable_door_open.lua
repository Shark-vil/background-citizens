hook.Add('BGN_PreOpenDoor', 'BGN_DarkRp_DoorIsOwner', function(actor, door)
	if engine.ActiveGamemode() ~= 'darkrp' then return end
	if not door:isKeysOwnable() or (IsValid(door:getDoorOwner()) and door:isLocked()) then return true end
end)