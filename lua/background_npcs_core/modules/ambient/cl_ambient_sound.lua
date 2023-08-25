local currentAmbient
local oldAmbient
local currentSound

local function SetAmbient(ambient_value)
	if not ambient_value then
		if currentSound and currentAmbient and currentSound:IsPlaying() then
			if timer.Exists('BGN_SetNewAmbientSoundAfterFade') then
				timer.Remove('BGN_SetNewAmbientSoundAfterFade')
			end

			if timer.Exists('BGN_SetNewAmbientSoundAfterFadeChangeVolume') then
				timer.Remove('BGN_SetNewAmbientSoundAfterFadeChangeVolume')
			end

			currentSound:FadeOut(2)

			timer.Create('BGN_AmbientSoundStopFade', 2.1, 1, function()
				if not currentSound then return end
				currentSound:Stop()
				currentSound = nil
			end)

			bgNPC:Log('Stop ambient - ' .. currentAmbient)
		end

		currentAmbient = nil
		return
	end

	if ambient_value.sound == currentAmbient then return end
	currentAmbient = ambient_value.sound

	local sound_name = currentAmbient
	local sound_volume = ambient_value.volume ~= nil and ambient_value.volume or 1
	local fade_time = 2

	if currentSound and currentSound:IsPlaying() then
		currentSound:FadeOut(fade_time)
	else
		fade_time = 0
	end

	timer.Create('BGN_SetNewAmbientSoundAfterFade', fade_time + 0.1, 1, function()
		if currentSound then
			currentSound:Stop()
			bgNPC:Log('Stop ambient - ' .. tostring(currentAmbient))
		end

		currentSound = CreateSound(game.GetWorld(), sound_name)
		currentSound:SetSoundLevel(0)
		currentSound:PlayEx(0, 100)

		timer.Create('BGN_SetNewAmbientSoundAfterFadeChangeVolume', 0.01, 0, function()
			if not currentSound then return end

			local current_volume = currentSound:GetVolume()

			if not currentSound or current_volume == sound_volume then
				timer.Remove('BGN_SetNewAmbientSoundAfterFadeChangeVolume')
				return
			end

			current_volume = current_volume + 0.1
			if current_volume > sound_volume then
				current_volume = sound_volume
			end

			if current_volume ~= sound_volume then
				bgNPC:Log('Ambient volume - ' .. current_volume)
			end

			currentSound:ChangeVolume(current_volume)
		end)

		if oldAmbient ~= currentAmbient then
			bgNPC:Log('Play ambient - ' .. sound_name)
		end
	end)

	oldAmbient = currentAmbient
end

timer.Create('BGN_SetAmbientSound', 2, 0, function()
	if not GetConVar('bgn_cl_ambient_sound'):GetBool() then
		SetAmbient()
		return
	end

	if not LocalPlayer().snet_ready then return end

	local ply = LocalPlayer()
	local entities = ents.FindInSphere(ply:GetPos(), 1000)
	local count = 0

	for i = 1, #entities do
		local npc = entities[i]

		if bgNPC:GetActor(npc) ~= nil and bgNPC:IsTargetRay(ply, npc) then
			count = count + 1
		end
	end

	if count == 0 then
		SetAmbient()
		return
	end

	table.sort(bgNPC.cfg.ambient, function(a, b)
		return a.count > b.count
	end)

	for _, v in ipairs(bgNPC.cfg.ambient) do
		if count >= v.count then
			SetAmbient(v)
			break
		end
	end
end)