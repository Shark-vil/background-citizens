--[[
	bgn_nextbot: NextBot actor body for maps with a NavMesh (HL2 human, metropolice and combine models).
	Driven by bgNPC.NextBotBody (actor/body/sv_nextbot_body.lua); has no AI of its own except combat:
	it shoots or hits the enemy the body gave it.

	Movement: PathFollower on the NavMesh, doors are opened on the way, stuck handling (jump, then teleport
	to the next path point). Weapons: a real HL2 weapon entity bonemerged to the hand (players can't pick it up),
	shots are FireBullets from the bot with per-weapon stats.
--]]

AddCSLuaFile()

ENT.Base = 'base_nextbot'
ENT.Type = 'nextbot'
ENT.PrintName = 'Background NPCs actor'
ENT.Spawnable = false
ENT.IsBGNNextBot = true

-- Shared, so client code that asks NPCs for their weapon works with the bot too.
function ENT:GetActiveWeapon() return self:GetNW2Entity('bgn_weapon') end

if CLIENT then return end

local WALK_SPEED = 75
local RUN_SPEED = 210
local MIN_MOVE_SPEED = 30 -- units per second; slower than that stands in the idle pose
local GOAL_TOLERANCE = 30
local REPATH_PERIOD = 1
local DOOR_CHECK_PERIOD = 0.5
local STUCK_TELEPORT_TIME = 3
local PROGRESS_PERIOD = 1.5
local MIN_PROGRESS_SQR = 16 ^ 2
local PULL_OUT_STALLS = 3      -- stalled progress checks in a row before the bot is pulled out
local PULL_OUT_RADIUS = 220
local PULL_OUT_MIN_SQR = 70 ^ 2
local PULL_OUT_GOAL_SQR = 150 ^ 2 -- standing this close to its goal is not being stuck
local SIDESTEP_TIME = 0.8
local SIDESTEP_DIST = 80
local CONTACT_PUSH = 60
local AIM_TURN_RATE = 540 -- degrees per second while moving in combat
local EYE_OFFSET = Vector(0, 0, 62)
local LOF_HULL = Vector(10, 10, 10) -- covers the spread of a few shots
local LOF_STEP_DIST = 120
local LOF_STEP_PERIOD = 1.5
local HULL_MINS, HULL_MAXS = Vector(-13, -13, 0), Vector(13, 13, 72)

local DEFAULT_MODELS = {
	npc_metropolice = { 'models/police.mdl' },
	npc_combine_s = { 'models/combine_soldier.mdl' },
	npc_citizen = {
		'models/humans/group01/male_01.mdl', 'models/humans/group01/male_02.mdl',
		'models/humans/group01/male_04.mdl', 'models/humans/group01/male_07.mdl',
		'models/humans/group01/female_01.mdl', 'models/humans/group01/female_02.mdl',
	},
}

-- class -> { damage, delay, spread, num, range, clip, melee, sound, hold }
local WEAPONS = {
	weapon_pistol = { damage = 6, delay = 0.45, spread = 0.04, clip = 18, range = 2000, sound = 'Weapon_Pistol.NPC_Single', hold = 'pistol' },
	weapon_357 = { damage = 35, delay = 1.1, spread = 0.02, clip = 6, range = 2500, sound = 'Weapon_357.Single', hold = 'pistol' },
	weapon_smg1 = { damage = 4, delay = 0.1, spread = 0.07, clip = 45, range = 1800, sound = 'Weapon_SMG1.NPC_Single', hold = 'rifle' },
	weapon_ar2 = { damage = 8, delay = 0.12, spread = 0.04, clip = 30, range = 2500, sound = 'Weapon_AR2.NPC_Single', hold = 'rifle' },
	weapon_shotgun = { damage = 6, num = 7, delay = 1, spread = 0.1, clip = 6, range = 800, sound = 'Weapon_Shotgun.NPC_Single', hold = 'rifle' },
	weapon_crowbar = { damage = 20, delay = 0.8, range = 75, melee = true, sound = 'Weapon_Crowbar.Single', hold = 'melee' },
	weapon_stunstick = { damage = 15, delay = 0.8, range = 75, melee = true, sound = 'Weapon_StunStick.Melee_Hit', hold = 'melee' },
}
local DEFAULT_WEAPON = WEAPONS.weapon_pistol

-- Per WEAPON_PROFICIENCY_* (0 poor .. 4 perfect), so the wanted levels get harder step by step:
-- citizen poor, police / gangster average, civil defense good, special forces very good, special forces 2 perfect.
-- spread: multiplier of the WEAPONS spread; damage: multiplier against players only (HL2 NPCs hit a player for about
-- a third of the player's own weapon damage); reaction: seconds from spotting the enemy to the first shot.
local PROFICIENCY = {
	[0] = { spread = 2, damage = 0.3, reaction = 1.2 },
	{ spread = 1.5, damage = 0.4, reaction = 0.9 },
	{ spread = 1.2, damage = 0.45, reaction = 0.7 },
	{ spread = 1, damage = 0.5, reaction = 0.5 },
	{ spread = 0.8, damage = 0.6, reaction = 0.35 },
}
local REACQUIRE_TIME = 1 -- out of sight longer than this: the reaction delay applies again
local HAND_ATTACHMENT = 'anim_attachment_RH'
local MUZZLE_FORWARD = 10 -- hand to muzzle

-- SWEP hold type -> ACTIVITIES key; unknown gun hold types use 'rifle'
local HOLD_TYPES = {
	pistol = 'pistol', revolver = 'pistol', duel = 'pistol',
	melee = 'melee', melee2 = 'melee', knife = 'melee', fist = 'melee',
}

-- Stats of a scripted weapon from its SWEP.Primary (base GMod / TFA field names), missing fields from the pistol.
-- shortcut: ARC9 / ArcCW keep stats outside Primary and get pistol numbers, add a branch if configs use them.
local function SwepStats(primary, hold_type)
	local hold = HOLD_TYPES[hold_type] or 'rifle'
	local melee = hold == 'melee'
	local delay = primary.Delay or (primary.RPM and 60 / primary.RPM)
	local clip = primary.ClipSize
	local sound = primary.Sound
	if istable(sound) then sound = sound[1] end
	return {
		damage = primary.Damage or (melee and 20 or DEFAULT_WEAPON.damage),
		delay = delay or (melee and 0.8 or DEFAULT_WEAPON.delay),
		spread = primary.Spread or primary.Cone or DEFAULT_WEAPON.spread,
		num = primary.NumShots or primary.NumberofShots,
		clip = (not melee and clip and clip > 0) and clip or nil,
		range = melee and 75 or DEFAULT_WEAPON.range,
		melee = melee or nil,
		sound = isstring(sound) and sound or (melee and 'Weapon_Crowbar.Single' or DEFAULT_WEAPON.sound),
		hold = hold,
	}
end

if bgNPC and bgNPC.Test then
	bgNPC.Test.Add('nextbot.swep_stats', function(check)
		local s = SwepStats({ Damage = 30, RPM = 600, ClipSize = 25, Sound = { 'A.Single' } }, 'ar2')
		check(s.damage == 30 and s.delay == 0.1 and s.clip == 25 and s.sound == 'A.Single' and s.hold == 'rifle', 'tfa-style rifle')
		s = SwepStats({ ClipSize = -1 }, 'knife')
		check(s.melee and s.clip == nil and s.range == 75 and s.hold == 'melee', 'melee without clip')
		s = SwepStats({}, 'revolver')
		check(s.hold == 'pistol' and s.damage == DEFAULT_WEAPON.damage, 'empty primary falls back to pistol')
	end)
	bgNPC.Test.Add('nextbot.proficiency_ladder', function(check)
		for p = 1, 4 do
			local a, b = PROFICIENCY[p - 1], PROFICIENCY[p]
			check(b.spread < a.spread and b.damage > a.damage and b.reaction < a.reaction, 'skill ' .. p .. ' beats ' .. (p - 1))
		end
	end)
end

-- hold type -> { idle, walk, run, aim idle, attack gesture }; first activity the model has wins
-- Weaponless: some models (combine soldiers...) have no plain idle/walk/run and T-pose, so fall back to armed ones.
local UNARMED = {
	idle = { ACT_IDLE, ACT_IDLE_SMG1, ACT_IDLE_PISTOL },
	walk = { ACT_WALK, ACT_WALK_RIFLE, ACT_WALK_PISTOL },
	run = { ACT_RUN, ACT_RUN_RIFLE, ACT_RUN_PISTOL },
}
local ACTIVITIES = {
	none = UNARMED,
	pistol = {
		idle = { ACT_IDLE_PISTOL, ACT_IDLE }, walk = { ACT_WALK_PISTOL, ACT_WALK }, run = { ACT_RUN_PISTOL, ACT_RUN },
		aim = { ACT_IDLE_ANGRY_PISTOL, ACT_RANGE_ATTACK_PISTOL, ACT_IDLE_PISTOL, ACT_IDLE },
		walk_aim = { ACT_WALK_AIM_PISTOL, ACT_WALK_PISTOL, ACT_WALK }, run_aim = { ACT_RUN_AIM_PISTOL, ACT_RUN_PISTOL, ACT_RUN },
		gesture = ACT_GESTURE_RANGE_ATTACK_PISTOL,
	},
	rifle = {
		idle = { ACT_IDLE_SMG1, ACT_IDLE }, walk = { ACT_WALK_RIFLE, ACT_WALK }, run = { ACT_RUN_RIFLE, ACT_RUN },
		aim = { ACT_IDLE_ANGRY_SMG1, ACT_RANGE_ATTACK_SMG1, ACT_IDLE_SMG1, ACT_IDLE },
		walk_aim = { ACT_WALK_AIM_RIFLE, ACT_WALK_RIFLE, ACT_WALK }, run_aim = { ACT_RUN_AIM_RIFLE, ACT_RUN_RIFLE, ACT_RUN },
		gesture = ACT_GESTURE_RANGE_ATTACK_SMG1,
	},
	melee = {
		idle = { ACT_IDLE_ANGRY_MELEE, unpack(UNARMED.idle) }, walk = UNARMED.walk, run = UNARMED.run,
		gesture = ACT_GESTURE_MELEE_ATTACK1, attack = ACT_MELEE_ATTACK_SWING,
	},
}
-- in the air (a stuck jump, a fall): the walk cycle froze mid-step and the body slid
local AIR_ACTIVITIES = { ACT_GLIDE, ACT_JUMP, ACT_IDLE }

function ENT:Initialize()
	local models = DEFAULT_MODELS[self.bgn_npc_class] or DEFAULT_MODELS.npc_citizen
	-- the spawner replaces it afterwards when the actor config has models
	self:SetModel(models[math.random(#models)])

	self:SetHealth(self.bgn_health or 100)
	self:SetMaxHealth(self:Health())
	self:BGN_ResetHull()

	self.loco:SetStepHeight(18)
	self.loco:SetJumpHeight(58)
	self.loco:SetAcceleration(500)
	self.loco:SetDeceleration(900)
	self.loco:SetDesiredSpeed(WALK_SPEED)

	self.move_goal = nil
	self.move_run = false
	self.enemy = NULL
	self.alert = 'idle'
	self.next_fire = 0
	self.clip = 0
	self.proficiency = WEAPON_PROFICIENCY_AVERAGE
	self.busy_until = 0
	self.sequence_lock = false
	self.activity_cache = {}
end

-- ---------------------------------------------------------------------------
-- Interface used by NextBotBody
-- ---------------------------------------------------------------------------

function ENT:BGN_ResetHull()
	self:SetCollisionBounds(HULL_MINS, HULL_MAXS)
	self:SetSolidMask(MASK_NPCSOLID)
end

function ENT:BGN_MoveTo(pos, run)
	self.move_run = run or false
	if self.move_goal and self.move_goal:DistToSqr(pos) < 100 then return end
	self.move_goal = pos
	self.path_dirty = true
	self.progress_pos = nil -- standing before a new goal is not a lack of progress
end

function ENT:BGN_Stop()
	self.move_goal = nil
	if self.path then self.path:Invalidate() end
end

function ENT:BGN_IsMoving()
	return self.move_goal ~= nil
end

function ENT:BGN_SetEnemy(ent) self.enemy = ent or NULL end
function ENT:BGN_GetEnemy() return self.enemy end
function ENT:BGN_SetAlert(level) self.alert = level end
function ENT:BGN_IsBusy() return self.busy_until > CurTime() end

function ENT:GetWeapon(weapon_class)
	local weapon = self.weapon
	return IsValid(weapon) and weapon:GetClass() == weapon_class and weapon or NULL
end

function ENT:Give(weapon_class)
	local current = self.weapon
	if IsValid(current) then
		if current:GetClass() == weapon_class then return current end
		current:Remove()
	end

	local weapon = ents.Create(weapon_class)
	if not IsValid(weapon) then return NULL end
	weapon:SetPos(self:GetPos())
	weapon:Spawn()
	weapon:SetOwner(self)
	weapon:SetParent(self)
	weapon:AddEffects(EF_BONEMERGE)
	weapon:SetSolid(SOLID_NONE)
	weapon:SetMoveType(MOVETYPE_NONE)
	weapon.bgn_nextbot_weapon = true

	self.weapon = weapon
	self:SetNW2Entity('bgn_weapon', weapon)
	self.weapon_stats = WEAPONS[weapon_class]
		or (istable(weapon.Primary) and SwepStats(weapon.Primary, weapon:GetHoldType()))
		or DEFAULT_WEAPON
	self.clip = self.weapon_stats.clip or 0
	return weapon
end
ENT.SelectWeapon = function() end

-- Same API as HL2 NPCs, so the actor config weapon_skill applies to the bot too
function ENT:SetCurrentWeaponProficiency(proficiency) self.proficiency = proficiency end
function ENT:GetCurrentWeaponProficiency() return self.proficiency end

-- @return table|nil { Pos, Ang } of the right hand
function ENT:BGN_Hand()
	local id = self:LookupAttachment(HAND_ATTACHMENT)
	return id and id > 0 and self:GetAttachment(id) or nil
end

-- Drops the weapon as a normal world weapon (anyone can pick it up), like an HL2 NPC does on death.
function ENT:BGN_DropWeapon()
	local weapon = self.weapon
	if not IsValid(weapon) then return end
	local hand = self:BGN_Hand()
	self.weapon = nil
	self:SetNW2Entity('bgn_weapon', NULL)
	self.weapon_stats = nil

	weapon.bgn_nextbot_weapon = nil
	weapon:SetParent(NULL)
	weapon:RemoveEffects(EF_BONEMERGE)
	weapon:SetOwner(NULL)
	weapon:SetPos(hand and hand.Pos or self:WorldSpaceCenter())
	weapon:SetAngles(hand and hand.Ang or self:GetAngles())
	weapon:PhysicsInit(SOLID_VPHYSICS)
	weapon:SetMoveType(MOVETYPE_VPHYSICS)
	weapon:SetSolid(SOLID_VPHYSICS)
	weapon:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	local phys = weapon:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end
end

function ENT:BGN_RemoveWeapon()
	if IsValid(self.weapon) then self.weapon:Remove() end
	self.weapon = nil
	self:SetNW2Entity('bgn_weapon', NULL)
	self.weapon_stats = nil
end

-- Holds the body still and plays a sequence (animations of states). @return boolean
function ENT:BGN_PlaySequence(sequence)
	if not sequence or sequence < 0 then return false end
	self:BGN_Stop()
	self.sequence_lock = true
	self:ResetSequence(sequence)
	self:SetCycle(0)
	self:SetPlaybackRate(1)
	return true
end

function ENT:BGN_StopSequence()
	self.sequence_lock = false
	self.current_activity = nil
end

-- ---------------------------------------------------------------------------
-- Animation
-- ---------------------------------------------------------------------------

function ENT:HoldType()
	return self.weapon_stats and IsValid(self.weapon) and self.weapon_stats.hold or 'none'
end

-- First activity of the list the model has (cached per model).
function ENT:PickActivity(list)
	if not list then return ACT_IDLE end
	local key = self:GetModel() .. list[1]
	local act = self.activity_cache[key]
	if act then return act end

	act = list[#list]
	for _, candidate in ipairs(list) do
		local sequence = self:SelectWeightedSequence(candidate)
		-- nil: the model isn't loaded yet (just set or invalid), don't cache the fallback for it
		if sequence == nil then return act end
		if sequence > 0 then act = candidate break end
	end
	self.activity_cache[key] = act
	return act
end

function ENT:UpdateActivity()
	if self.sequence_lock then return end

	local set = ACTIVITIES[self:HoldType()] or ACTIVITIES.none
	local fighting = self.alert == 'combat' and IsValid(self.enemy)
	-- Crowd pushing and sidesteps move a bot a few units per second; a walk or run cycle slowed down to that looks like
	-- slow-motion running (people waiting in a dialogue), so only a real pace plays one, and a run needs a run pace.
	local speed_sqr = self.loco:GetVelocity():Length2DSqr()
	local moving = speed_sqr > MIN_MOVE_SPEED ^ 2
	local running = self.move_run and speed_sqr > (WALK_SPEED * 1.4) ^ 2
	local list
	if not self:IsOnGround() then
		list = AIR_ACTIVITIES
	elseif moving then
		list = running and (fighting and set.run_aim or set.run) or (fighting and set.walk_aim or set.walk)
	else
		list = fighting and set.aim or set.idle
	end

	local act = self:PickActivity(list)
	if self.current_activity ~= act then
		self.current_activity = act
		self:StartActivity(act)
	end
end

function ENT:BodyUpdate()
	if self.sequence_lock then
		self:FrameAdvance()
		return
	end
	if not self:IsOnGround() then
		self:FrameAdvance() -- BodyMoveXY plays by the ground speed, in the air it stops the cycle
		return
	end
	local velocity = self.loco:GetVelocity()
	if velocity:Length2DSqr() > 100 then
		self:SetPoseParameter('move_yaw', math.NormalizeAngle(velocity:Angle().y - self:GetAngles().y))
	end
	self:BodyMoveXY()
end

-- ---------------------------------------------------------------------------
-- Combat
-- ---------------------------------------------------------------------------

function ENT:BGN_EyePos()
	return self:GetPos() + EYE_OFFSET
end

function ENT:CanSeeEnemy(enemy)
	local tr = util.TraceLine({
		start = self:BGN_EyePos(),
		endpos = enemy:WorldSpaceCenter(),
		filter = { self, self.weapon },
		mask = MASK_SHOT,
	})
	return tr.Entity == enemy or not tr.Hit
end

-- @return boolean someone who is not an enemy stands between the bot and its target
function ENT:FriendInLineOfFire(enemy)
	local tr = util.TraceHull({
		start = self:BGN_EyePos(),
		endpos = enemy:WorldSpaceCenter(),
		mins = -LOF_HULL,
		maxs = LOF_HULL,
		filter = { self, self.weapon, enemy },
		mask = MASK_SHOT,
	})
	local ent = tr.Entity
	if not IsValid(ent) or not (ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer()) then return false end
	local actor = bgNPC.Actors.Get(self)
	return not (actor and actor:HasEnemy(ent))
end

-- Steps to the side of the line to the enemy (left or right at random) to get a clear shot
function ENT:StepOutOfLine(enemy)
	local now = CurTime()
	if now < (self.next_lof_step or 0) then return end
	self.next_lof_step = now + LOF_STEP_PERIOD
	local dir = enemy:GetPos() - self:GetPos()
	dir.z = 0
	dir:Normalize()
	local side = Vector(-dir.y, dir.x, 0) * (math.random(2) == 1 and LOF_STEP_DIST or -LOF_STEP_DIST)
	self:BGN_MoveTo(self:GetPos() + side, true)
end

function ENT:Attack(enemy, stats)
	local now = CurTime()
	local set = ACTIVITIES[stats.hold] or ACTIVITIES.none
	self.next_fire = now + stats.delay
	self.busy_until = now + math.min(stats.delay, 0.5)
	-- HL2 citizens have no melee gesture, only the full-body swing: play it as a gesture layer
	if set.gesture and (self:SelectWeightedSequence(set.gesture) or -1) > 0 then
		self:RestartGesture(set.gesture)
	elseif set.attack then
		local sequence = self:SelectWeightedSequence(set.attack) or -1
		if sequence > 0 then self:AddGestureSequence(sequence, true) end
	end
	if IsValid(self.weapon) then self.weapon:EmitSound(stats.sound) end

	if stats.melee then
		local dmg = DamageInfo()
		dmg:SetDamage(stats.damage)
		dmg:SetAttacker(self)
		dmg:SetInflictor(IsValid(self.weapon) and self.weapon or self)
		dmg:SetDamageType(DMG_CLUB)
		dmg:SetDamageForce(self:GetForward() * 2000)
		enemy:TakeDamageInfo(dmg)
		return
	end

	if stats.clip then
		self.clip = self.clip - 1
		if self.clip <= 0 then
			self.clip = stats.clip
			self.next_fire = now + 1.8
			self:RestartGesture(ACT_GESTURE_RELOAD)
		end
	end

	-- From the bot's own hand: the server doesn't bonemerge, so the weapon's muzzle attachment is wrong there
	local hand = self:BGN_Hand()
	local src = hand and hand.Pos + hand.Ang:Forward() * MUZZLE_FORWARD or self:BGN_EyePos()
	local skill = PROFICIENCY[self.proficiency] or PROFICIENCY[WEAPON_PROFICIENCY_AVERAGE]
	local spread = stats.spread * skill.spread

	self:FireBullets({
		Attacker = self,
		Src = src,
		Dir = (enemy:WorldSpaceCenter() - src):GetNormalized(),
		Spread = Vector(spread, spread, 0),
		Num = stats.num or 1,
		Damage = enemy:IsPlayer() and stats.damage * skill.damage or stats.damage,
		Tracer = 1,
		IgnoreEntity = self.weapon,
	})

	if IsValid(self.weapon) then
		local effect = EffectData()
		effect:SetEntity(self.weapon)
		effect:SetAttachment(1)
		util.Effect('MuzzleFlash', effect)
	end
end

-- Keeps the body turned to a visible enemy while the path moves it, so it shoots on the move;
-- move_yaw blends the HL2 run animation for running sideways or backwards.
function ENT:AimWhileMoving()
	local enemy = self.enemy
	if not self.enemy_visible or self.alert ~= 'combat' or not IsValid(enemy) then return end
	local yaw = (enemy:GetPos() - self:GetPos()):Angle().y
	local ang = self:GetAngles()
	self:SetAngles(Angle(0, math.ApproachAngle(ang.y, yaw, AIM_TURN_RATE * FrameTime()), 0))
end

function ENT:UpdateCombat()
	local enemy = self.enemy
	local stats = self.weapon_stats
	self.enemy_visible = false
	if self.alert ~= 'combat' or not stats or not IsValid(enemy) or not IsValid(self.weapon) then return end
	-- a player in a car: the enemy is the car (RedirectEnemyToVehicle), which mostly has no health of its own
	if (enemy:Health() <= 0 and not enemy:IsVehicle() and not enemy.IsSimfphyscar) or self.sequence_lock then return end

	local dist_sqr = self:GetPos():DistToSqr(enemy:GetPos())
	if dist_sqr > stats.range * stats.range then return end

	self.enemy_visible = self:CanSeeEnemy(enemy)
	if not self:BGN_IsMoving() then self.loco:FaceTowards(enemy:GetPos()) end
	if self.enemy_visible then
		local now = CurTime()
		if self.aim_target ~= enemy or now - (self.enemy_seen_at or 0) > REACQUIRE_TIME then
			local skill = PROFICIENCY[self.proficiency] or PROFICIENCY[WEAPON_PROFICIENCY_AVERAGE]
			self.next_fire = math.max(self.next_fire, now + skill.reaction)
			self.aim_target = enemy
		end
		self.enemy_seen_at = now
	end
	if CurTime() < self.next_fire or not self.enemy_visible then return end

	local to_enemy = (enemy:GetPos() - self:GetPos()):GetNormalized()
	if self:GetForward():Dot(to_enemy) < 0.7 then return end

	if not stats.melee and self:FriendInLineOfFire(enemy) then
		self:StepOutOfLine(enemy)
		return
	end

	self:Attack(enemy, stats)
end

-- Runs every tick (a slower think made the movement choppy); combat is checked 10 times per second.
function ENT:Think()
	local now = CurTime()
	if now >= (self.next_combat_check or 0) then
		self.next_combat_check = now + 0.1
		self:UpdateCombat()
	end
	self:UpdateActivity()
	self:NextThink(now)
	return true
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------

function ENT:OpenDoorsAhead()
	local start = self:BGN_EyePos()
	local tr = util.TraceLine({ start = start, endpos = start + self:GetForward() * 60, filter = self })
	local door = tr.Entity
	if not bgNPC.Util.CanActorOpenDoor(door) or bgNPC.Util.IsDoorOpen(door) then return end
	if bgNPC.Util.IsDoorLocked(door) then door:Fire('Unlock') end
	door:Fire('Open')
end

-- A bot teleported into a parked car or a prop stays inside it: only free spots are valid.
local function IsSpotFree(bot, spot)
	local hull = util.TraceHull({ start = spot + Vector(0, 0, 2), endpos = spot + Vector(0, 0, 2),
		mins = HULL_MINS, maxs = HULL_MAXS, mask = MASK_NPCSOLID, filter = bot })
	return not hull.StartSolid and not hull.Hit
end

-- Hops to a free nav spot a few steps away (closer to the goal when possible): the bot is wedged against a car, a prop
-- or another body and the path follower cannot get it out. Short, so it does not need the "hidden from players" rule.
-- @return boolean true if the bot was moved
function ENT:PullOut()
	local pos = self:GetPos()
	local goal = self.move_goal
	local best, best_dist
	for _, area in ipairs(navmesh.Find(pos, PULL_OUT_RADIUS, 40, 40)) do
		for _ = 1, 2 do
			local spot = area:GetRandomPoint()
			local away = spot:DistToSqr(pos)
			if away >= PULL_OUT_MIN_SQR and away <= PULL_OUT_RADIUS ^ 2 then
				local dist = goal and spot:DistToSqr(goal) or away
				if (not best_dist or dist < best_dist) and IsSpotFree(self, spot) then best, best_dist = spot, dist end
			end
		end
	end
	if not best then return false end
	self:SetPos(best + Vector(0, 0, 2))
	self.loco:ClearStuck()
	self.stuck_since, self.progress_pos, self.stalls = nil, nil, 0
	self.path_dirty = true
	return true
end

function ENT:HandleStuck(path)
	if not self.stuck_since then
		self.stuck_since = CurTime()
		if GetConVar('bgn_nextbot_jump'):GetBool() then self.loco:Jump() return end
	end

	if CurTime() - self.stuck_since < STUCK_TELEPORT_TIME then return end
	local goal = path:GetCurrentGoal()
	-- a player who sees the bot or the goal gets no far teleport: pull out nearby instead
	if goal and IsSpotFree(self, goal.pos) and bgNPC:IsHiddenSpawnPosition(goal.pos, self) then
		self:SetPos(goal.pos)
		self.loco:ClearStuck()
		self.stuck_since = nil
	elseif not self:PullOut() then
		self.stuck_since = CurTime() - STUCK_TELEPORT_TIME + 1
	end
end

-- Bots pushing into each other in a crowd never become loco:IsStuck, they just stop making progress.
-- Then the bot steps aside for a moment and repaths; still no progress after that: it is pulled out.
function ENT:CheckProgress()
	local now = CurTime()
	if now < (self.progress_check or 0) then return end
	local pos = self:GetPos()
	if self.progress_pos and pos:DistToSqr(self.progress_pos) < MIN_PROGRESS_SQR then
		self.stalls = (self.stalls or 0) + 1
		local goal = self.move_goal
		if self.stalls >= PULL_OUT_STALLS and goal and pos:DistToSqr(goal) > PULL_OUT_GOAL_SQR and self:PullOut() then return end
		self.sidestep_pos = pos + self:GetRight() * (math.random(2) == 1 and SIDESTEP_DIST or -SIDESTEP_DIST)
		self.sidestep_until = now + SIDESTEP_TIME
		self.path_dirty = true
	else
		self.stalls = 0
	end
	self.progress_pos = pos
	self.progress_check = now + PROGRESS_PERIOD
end

-- Separates touching bots that both move, so a crowd spreads instead of pushing head-on.
function ENT:OnContact(ent)
	if not ent.IsBGNNextBot or not self.move_goal then return end
	local away = self:GetPos() - ent:GetPos()
	away.z = 0
	if away:LengthSqr() < 1 then away = self:GetRight() end
	away:Normalize()
	self.loco:SetVelocity(self.loco:GetVelocity() + away * CONTACT_PUSH)
end

function ENT:RunBehaviour()
	local path = Path('Follow')
	path:SetMinLookAheadDistance(300)
	path:SetGoalTolerance(GOAL_TOLERANCE)
	self.path = path

	local next_door_check = 0

	while true do
		local goal = self.move_goal
		if goal and not IsValid(self:GetParent()) and not self:GetNW2Bool('bgn_vehicle_entered') and not self.sequence_lock then
			self.loco:SetDesiredSpeed(self.move_run and RUN_SPEED or WALK_SPEED)

			if self.path_dirty or not path:IsValid() or path:GetAge() > REPATH_PERIOD then
				self.path_dirty = false
				path:Compute(self, goal)
				if not path:IsValid() then self.move_goal = nil end
			end

			if (self.sidestep_until or 0) > CurTime() then
				self.loco:Approach(self.sidestep_pos, 1)
			elseif path:IsValid() then
				path:Update(self)
				self:AimWhileMoving()
				self:CheckProgress()
				if self.loco:IsStuck() then self:HandleStuck(path) else self.stuck_since = nil end

				if CurTime() >= next_door_check then
					next_door_check = CurTime() + DOOR_CHECK_PERIOD
					self:OpenDoorsAhead()
				end

				if self:GetPos():DistToSqr(goal) <= GOAL_TOLERANCE * GOAL_TOLERANCE then self.move_goal = nil end
			end
		end

		coroutine.yield()
	end
end

-- ---------------------------------------------------------------------------
-- Damage
-- ---------------------------------------------------------------------------

function ENT:OnKilled(dmginfo)
	hook.Run('OnNPCKilled', self, dmginfo:GetAttacker(), dmginfo:GetInflictor())
	self:BGN_DropWeapon()
	self:BecomeRagdoll(dmginfo)
end

function ENT:OnRemove()
	self:BGN_RemoveWeapon()
end

hook.Add('PlayerCanPickupWeapon', 'BGN_NextBotWeapon', function(_, weapon)
	if weapon.bgn_nextbot_weapon then return false end
end)
