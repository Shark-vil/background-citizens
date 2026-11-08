-- Copyright © 2018-2030 Decent Vehicle
-- written by ∩(≡＾ω＾≡)∩ (https://steamcommunity.com/id/greatzenkakuman/)
-- and DangerKiddy(DK) (https://steamcommunity.com/profiles/76561198132964487/).
-- Shark_vil modify

ENT.dir_eyetrace = Vector(0, 0, 0)

local FakeViewOffset = vector_up * 32
local function FakeEyeTrace(self)
	return util.QuickTrace(self:GetPos(), self.dir_eyetrace * 16384, self)
end

function ENT:AccountID() end -- For bots and in singleplayer, return no value
function ENT:AddCleanup() end
function ENT:AddCount() end
function ENT:AddVCDSequenceToGestureSlot() end
function ENT:Alive() return self:Health() > 0 end
function ENT:AllowFlashlight() end
function ENT:AnimResetGestureSlot() end
function ENT:AnimRestartGesture() end
function ENT:AnimRestartMainSequence() end
function ENT:AnimSetGestureSequence() end
function ENT:AnimSetGestureWeight() end
function ENT:Armor() return 0 end
function ENT:CanUseFlashlight() return false end
function ENT:ChatPrint() end
function ENT:CheckLimit() return true end
function ENT:ConCommand() end
function ENT:Crouching() return false end
function ENT:Deaths() return 0 end
function ENT:DoAnimationEvent() end
function ENT:DoAttackEvent() end
function ENT:DoCustomAnimEvent() end
function ENT:DoReloadEvent() end
function ENT:DoSecondaryAttack() end
function ENT:DrawViewModel() end
function ENT:FlashlightIsOn() return false end
function ENT:Frags() return 0 end
function ENT:GetActiveWeapon() return NULL end
function ENT:GetAimVector() return self.dir_eyetrace end
function ENT:GetAllowFullRotation() return false end
function ENT:GetAllowWeaponsInVehicle() return false end
function ENT:GetAmmo() return {} end
function ENT:GetAmmoCount() return 0 end
function ENT:GetAvoidPlayers() return false end
function ENT:GetCanWalk() return false end
function ENT:GetCanZoom() return false end
function ENT:GetClassID() return 0 end
function ENT:GetCount() return 0 end
function ENT:GetCrouchedWalkSpeed() return 0 end
function ENT:GetCurrentCommand() return dvd.FakeCUserCmd end
function ENT:GetCurrentViewOffset() return FakeViewOffset end
--function ENT:GetDrivingEntity() return NULL end
function ENT:GetDrivingMode() return 0 end
function ENT:GetDuckSpeed() return 0.3 end
function ENT:GetEntityInUse() return NULL end
function ENT:GetEyeTrace() return FakeEyeTrace(self) end
function ENT:GetEyeTraceNoCursor() return FakeEyeTrace(self) end
function ENT:GetFOV() return 62 end
function ENT:GetHands() return NULL end
function ENT:GetHoveredWidget() return NULL end
function ENT:GetHull() return self:GetCollisionBounds() end
function ENT:GetHullDuck() return self:GetCollisionBounds() end
function ENT:GetJumpPower() return 200 end
function ENT:GetLaggedMovementValue() return 1 end
function ENT:GetMaxSpeed() return 0 end
function ENT:GetName() return self.PrintName end
function ENT:GetNoCollideWithTeammates() return false end
function ENT:GetObserverMode() return OBS_MODE_NONE end
function ENT:GetObserverTarget() return NULL end
function ENT:GetPData() return "" end
function ENT:GetPlayerColor() return Vector(1, 1, 1) end
function ENT:GetPressedWidget() return NULL end
function ENT:GetPunchAngle() return Angle() end
function ENT:GetRagdollEntity() return NULL end
function ENT:GetRenderAngles() return Angle() end
function ENT:GetRunSpeed() return 0 end
function ENT:GetShootPos() return self:GetPos() end
function ENT:GetStepSize() return 16 end
function ENT:GetTool() end
function ENT:GetUnDuckSpeed() return 0.3 end
function ENT:GetUserGroup() return "user" end
function ENT:GetVehicle() return self.v or NULL end
function ENT:GetViewEntity() return self end
function ENT:GetViewModel() return NULL end
function ENT:GetViewOffset() return FakeViewOffset end
function ENT:GetViewOffsetDucked() return FakeViewOffset end
function ENT:GetViewPunchAngles() return Angle() end
function ENT:GetWalkSpeed() return 0 end
function ENT:GetWeapon() return NULL end
function ENT:GetWeaponColor() return Vector(1, 1, 1) end
function ENT:GetWeapons() return {} end
function ENT:HasGodMode() return false end
function ENT:HasWeapon() return false end
function ENT:InVehicle() return true end
function ENT:IsAdmin() return false end
function ENT:IsBot() return true end
function ENT:PlayerEnteredSCar() end -- For SCAR base
function ENT:OnTakeDamage() end -- For SCAR base
function ENT:RemoveCarConnection() end -- For SCAR base
function ENT:InVehicle() return true end
function ENT:IsDrivingEntity() return true end
function ENT:IsFrozen() return false end
function ENT:IsPlayingTaunt() return false end
function ENT:IsSprinting() return false end
function ENT:IsSuitEquipped() return false end
function ENT:IsSuperAdmin() return false end
function ENT:IsTyping() return false end
function ENT:IsUserGroup() return false end
function ENT:IsWorldClicking() return false end
function ENT:KeyDownLast() return false end
function ENT:KeyPressed() return false end
function ENT:KeyReleased() return false end
function ENT:LagCompensation() end
function ENT:LimitHit() end
function ENT:MotionSensorPos() return self:GetPos() end
function ENT:Name() return self.PrintName end
function ENT:Nick() return self.PrintName end
function ENT:PacketLoss() return 0 end
function ENT:PhysgunUnfreeze() return 0 end
function ENT:Ping() return 0 end
function ENT:PrintMessage() end
function ENT:RemoveAmmo() end
function ENT:RemovePData() return false end
function ENT:ResetHull() end
function ENT:ScreenFade() end
function ENT:SetAllowFullRotation() end
function ENT:SetAmmo() end
function ENT:SetAvoidPlayers() end
function ENT:SetCanWalk() end
function ENT:SetClassID() end
function ENT:SetCrouchedWalkSpeed() end
function ENT:SetCurrentViewOffset() end
function ENT:SetDrivingEntity() end
function ENT:SetDSP() end
function ENT:SetDuckSpeed() end
function ENT:SetEyeAngles() end
function ENT:SetFOV() end
function ENT:SetHands() end
function ENT:SetHoveredWidget() end
function ENT:SetHull() end
function ENT:SetHullDuck() end
function ENT:SetJumpPower() end
function ENT:SetMaxSpeed() end
function ENT:SetObserverMode() end
function ENT:SetPData() return false end
function ENT:SetPlayerColor() end
function ENT:SetPressedWidget() end
function ENT:SetRenderAngles() end
function ENT:SetRunSpeed() end
function ENT:SetStepSize() end
function ENT:SetSuppressPickupNotices() end
function ENT:SetUnDuckSpeed() end
function ENT:SetViewOffset() end
function ENT:SetViewOffsetDucked() end
function ENT:SetViewPunchAngles() end
function ENT:SetWalkSpeed() end
function ENT:SetWeaponColor() end
function ENT:StartSprinting() end
function ENT:StartWalking() end
function ENT:SteamID() return SERVER and "BOT" or "NULL" end
function ENT:StopSprinting() end
function ENT:StopWalking() end
function ENT:Team() return TEAM_UNASSIGNED end
function ENT:TranslateWeaponActivity() return ACT_INVALID end
function ENT:UnfreezePhysicsObjects() end
function ENT:UniqueID() return self:EntIndex() end
function ENT:UniqueIDTable(key)
	self.UniqueTable = self.UniqueTable or {}
	self.UniqueTable[key] = self.UniqueTable[key] or {}
	return self.UniqueTable[key]
end
function ENT:UserID() return 0 end
function ENT:ViewPunch() end
function ENT:ViewPunchReset() end

if CLIENT then
	function ENT:AddPlayerOption() end
	function ENT:GetFriendStatus() return "none" end
	function ENT:GetPlayerInfo()
		return {
			customfiles = {"00000000", "00000000", "00000000", "00000000"},
			fakeplayer = true,
			filesdownloaded = 0,
			friendid = 0,
			friendname = "",
			guid = "BOT",
			ishltv = false,
			name = self.PrintName,
			userid = 1,
		}
	end
	function ENT:IsMuted() return false end
	function ENT:IsSpeaking() return false end
	function ENT:IsVoiceAudible() return false end
	function ENT:KeyDown() return false end
	function ENT:SetMuted() end
	function ENT:ShouldDrawLocalPlayer() return false end
	function ENT:ShowProfile() end
	function ENT:SteamID64() end
	function ENT:VoiceVolume() return 0 end
	return
end

function ENT:AddDeaths() end
function ENT:AddFrags() end
function ENT:AddFrozenPhysicsObject() end
function ENT:AllowImmediateDecalPainting() end
function ENT:Ban() end
function ENT:CreateRagdoll() end
function ENT:CrosshairDisable() end
function ENT:CrosshairEnable() end
function ENT:DebugInfo() end
function ENT:DetonateTripmines() end
function ENT:DrawWorldModel() end
function ENT:DropNamedWeapon() end
function ENT:DropObject() end
function ENT:DropWeapon() end
function ENT:EnterVehicle() end
function ENT:EquipSuit() end
function ENT:ExitVehicle() end
function ENT:Flashlight() end
function ENT:Freeze() end
function ENT:GetInfo() return "" end
function ENT:GetInfoNum(key, default)
	return isnumber(default) and default or 0
end
function ENT:GetPreferredCarryAngles() end
function ENT:GetTimeoutSeconds() return 0 end
function ENT:Give() return NULL end
function ENT:GiveAmmo() return 0 end
function ENT:GodDisable() end
function ENT:GodEnable() end
function ENT:IPAddress() return "" end
function ENT:IsConnected() return false end
function ENT:IsFullyAuthenticated() return false end
function ENT:IsListenServerHost() return false end
function ENT:IsTimingOut() return false end
function ENT:KeyDown(key, pressed)
	return pressed or false
end
function ENT:Kick() end
function ENT:Kill() end
function ENT:KillSilent() end
function ENT:LastHitGroup() return HITGROUP_GENERIC end
function ENT:Lock() end
function ENT:PickupObject() end
function ENT:PlayStepSound() end
function ENT:RemoveAllAmmo() end
function ENT:RemoveAllItems() end
function ENT:RemoveSuit() end
function ENT:Say() end
function ENT:SelectWeapon() end
function ENT:SendHint() end
function ENT:SendLua() end
function ENT:SetActiveWeapon() end
function ENT:SetAllowWeaponsInVehicle() end
function ENT:SetArmor() end
function ENT:SetCanZoom() end
function ENT:SetDeaths() end
function ENT:SetFrags() end
function ENT:SetLaggedMovementValue() end
function ENT:SetNoCollideWithTeammates() end
function ENT:SetNoTarget() end
function ENT:SetTeam() end
function ENT:SetupHands() end
function ENT:SetUserGroup() end
function ENT:SetViewEntity() end
function ENT:ShouldDropWeapon() return false end
function ENT:SimulateGravGunDrop() end
function ENT:SimulateGravGunPickup() end
function ENT:Spectate() end
function ENT:SpectateEntity() end
function ENT:SprayDecal() end
function ENT:SprintDisable() end
function ENT:SprintEnable() end
function ENT:SteamID64() return 90071996842377216 end
function ENT:StopZooming() end
function ENT:StripAmmo() end
function ENT:StripWeapon() end
function ENT:StripWeapons() end
function ENT:SuppressHint() end
function ENT:SwitchToDefaultWeapon() end
function ENT:TimeConnected() return 0 end
function ENT:TraceHullAttack() return NULL end
function ENT:UnLock() end
function ENT:UnSpectate() end