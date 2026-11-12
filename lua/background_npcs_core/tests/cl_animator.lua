bgNPC.Test.Add('animator.appearance', function(check)
  local env = setmetatable({
    SERVER = false,
    CLIENT = true
  }, {
    __index = _G
  })

  local receivers, copies, think = {}, {}, nil
  local now = 100
  env.CurTime = function() return now end
  local function Entity()
    local e = {
      valid = true,
      submaterials = {},
      scale = 1
    }

    function e:Remove()
      self.valid = false
    end

    function e:GetPos()
      return Vector()
    end

    function e:GetAngles()
      return Angle()
    end

    function e:GetModel()
      return 'model'
    end

    function e:GetSkin()
      return 2
    end

    function e:GetBodyGroups()
      return {
        {
          id = 1
        }
      }
    end

    function e:GetBodygroup()
      return 3
    end

    function e:GetColor()
      return self.color
    end

    function e:GetMaterial()
      return self.material
    end

    function e:GetModelScale()
      return self.scale
    end

    function e:GetMaterials()
      return {'a', 'b'}
    end

    function e:GetSubMaterial(i)
      return self.submaterials[i]
    end

    function e:SetColor(v)
      self.color = v
    end

    function e:SetMaterial(v)
      self.material = v
    end

    function e:SetModelScale(v)
      self.scale = v
    end

    function e:SetSubMaterial(i, v)
      self.submaterials[i] = v
    end

    function e:SetSkin(v)
      self.skin = v
    end

    function e:SetBodygroup(i, v)
      self.bodygroup = {i, v}
    end

    function e:SetNoDraw(v)
      self.hidden = v
    end

    function e:LookupBone()
      return 1
    end

    for _, method in ipairs({'SetPos', 'SetAngles', 'SetParent', 'AddEffects'}) do
      e[method] = function() end
    end
    return e
  end

  env.IsValid = function(e) return type(e) == 'table' and e.valid == true end
  env.hook = {
    Add = function(_, _, f) think = f end,
    Run = function() end
  }

  env.ClientsideModel = function()
    local e = Entity()
    copies[#copies + 1] = e
    return e
  end

  env.bgNPC = {
    Net = {
      Receive = function(name, f) receivers[name] = f end
    }
  }

  setfenv(CompileFile('background_npcs_core/core/sh_animator.lua'), env)()
  local npc, donor, weapon = Entity(), Entity(), Entity()
  npc.color, npc.material, npc.scale, npc.submaterials[1] = Color(10, 20, 30, 100), 'custom', 1.5, 'override'
  npc.GetActiveWeapon = function() return weapon end
  local original = function() end
  npc.RenderOverride = original
  receivers['bgn.anim_start'](nil, npc, donor, 'dance', 1, 0)
  local copy = copies[1]
  check(copy.color == npc.color and copy.material == 'custom' and copy.scale == 1.5, 'copy preserves color, material and scale')
  check(copy.submaterials[1] == 'override' and copy.skin == 2 and copy.bodygroup[2] == 3, 'copy preserves submaterials, skin and bodygroups')
  check(weapon.hidden and npc.RenderOverride ~= original, 'original visuals are hidden')
  receivers['bgn.anim_stop'](nil, npc)
  check(not copy.valid and not copies[2].valid and not weapon.hidden and npc.RenderOverride == original, 'stop removes copies and restores rendering')
  receivers['bgn.anim_start'](nil, npc, donor, 'dance', 1, 105)
  now = 105
  think()
  check(not env.bgNPC.Animator.IsPlaying(npc) and npc.RenderOverride == original and not weapon.hidden, 'deadline restores visuals without a stop message')
  receivers['bgn.anim_start'](nil, npc, donor, 'dance', 1, 104)
  check(not env.bgNPC.Animator.IsPlaying(npc), 'expired start is ignored')
end)
