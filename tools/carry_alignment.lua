-- Opt-in CLIENT render-frame checks for the stock carry models in an isolated single-player lab.
assert(CLIENT and game.SinglePlayer(), 'run on the client in an isolated SP lab')
local report = { cases = {}, errors = {}, phase = BGNCarryAlignmentPhase or 'idle' }
BGNCarryAlignment = report
local function World(pos, ang, scale, point)
 return pos + ang:Forward() * point.x * scale.x - ang:Right() * point.y * scale.y + ang:Up() * point.z * scale.z
end
local Carry = bgNPC.CarryItems
local function Check(actor, self)
 local n = self:GetParent()
 if not IsValid(n) or n:GetNoDraw() then return end
 n:SetupBones()
 -- Sample the actual draw transform in a render hook, including models outside the camera frustum.
 self.RenderOverride(self)
 local pos, ang = self:GetRenderOrigin(), self:GetRenderAngles()
 if not pos or not ang then return end
  local ok, result = xpcall(function()
   local entry = { id = n:EntIndex(), model = n:GetModel(), kind = actor.carry_visual,
    sequence = n:GetSequenceName(n:GetSequence()), phase = report.phase }
   if report.phase == 'walk' and not entry.sequence:lower():find('walk', 1, true) then return end
   if entry.kind == 'newspaper' then
    local rm = n:GetBoneMatrix(n:LookupBone('ValveBiped.Bip01_R_Finger12'))
    local lm = n:GetBoneMatrix(n:LookupBone('ValveBiped.Bip01_L_Finger12'))
    if not rm or not lm then return end
    local r, l = rm:GetTranslation(), lm:GetTranslation()
    local mins, maxs = self:GetModelBounds()
    local width = math.Clamp(math.abs((l - r):Dot(-n:GetRight())) + 4, 14, 26)
    local scale = Vector(.65, width / 24, .2)
    local grip = World(pos, ang, scale, Vector(maxs.x - 2 / scale.x, (mins.y + maxs.y) * .5, (mins.z + maxs.z) * .5))
    entry.error = grip:Distance((r + l) * .5)
    entry.tilt = math.deg(math.asin(-ang:Up().z))
    assert(entry.error < .1, 'newspaper lower grip must follow the fingertips')
    assert(math.abs(entry.tilt - 15) < .1, 'newspaper top leans 15 degrees away from the face')
   else
    local fm = n:GetBoneMatrix(n:LookupBone('ValveBiped.Bip01_R_Finger11'))
    if not fm then return end
    local finger = fm:GetTranslation()
    entry.error = World(pos, ang, Vector(1, 1, 1), Vector(0, 0, 7.5)):Distance(finger)
    assert(entry.error < .1, 'briefcase handle follows the finger grip')
    assert(ang:Up().z > .999, 'briefcase hangs upright while the wrist rotates')
   end
   entry.passed = true
   return entry
  end, debug.traceback)
  if ok and result then report.cases[tostring(n:EntIndex())] = result elseif not ok then report.errors[tostring(n:EntIndex())] = result end
  if (report.next_write or 0) > CurTime() then return end
  report.next_write = CurTime() + .1
  file.CreateDir('bgn_paper_lab')
  file.Write('bgn_paper_lab/alignment-' .. report.phase .. '.json', util.TableToJSON(report, true))
end
hook.Add('PostDrawOpaqueRenderables', 'BGNCarryAlignment', function()
 for actor, prop in pairs(Carry.visuals) do if IsValid(prop) then Check(actor, prop) end end
end)
return true
