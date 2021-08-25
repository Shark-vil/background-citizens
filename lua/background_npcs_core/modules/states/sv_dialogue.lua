local ASSET = {}
local dialogue_actors = {}

local function NormalizeSoundPath(sound_path, gender)
   sound_path = string.Replace(sound_path, '%gender%', gender)
   return sound_path
end

local function _EmitSound(actor, sound)
   actor:GetNPC():EmitSound(sound, 70, 100, 1, CHAN_AUTO)
end

local function _PlayAnimation(dialogue)
   if #dialogue.animations ~= 0 then
      for _, value in ipairs(dialogue.animations) do
         if value.id == dialogue.replicId then
            local actor = dialogue.interlocutors[dialogue.speaking]
            if actor:IsAlive() then
               if value.time ~= nil then
                  actor:PlayStaticSequence(value.sequence, true, value.time)
               else
                  actor:PlayStaticSequence(value.sequence)
               end
            end
            break
         end
      end
   end
end

function ASSET:SetDialogue(actor1, actor2)
   for _, value in ipairs(dialogue_actors) do
      for _, interlocutor in ipairs(value.interlocutors) do
         if interlocutor == actor1 or interlocutor == actor2 then
            return
         end
      end
   end

   local npc1_model = actor1:GetNPC():GetModel()
   local npc2_model = actor2:GetNPC():GetModel()

   local dialogue = table.RandomBySeq(bgNPC.cfg.dialogues)
   local replic = dialogue.list[1]

   if dialogue.interlocutors == nil then
      return false
   end

   local type_1 = dialogue.interlocutors[1]
   local type_2 = dialogue.interlocutors[2]
   local gender_1 = 'unknown'
   local gender_2 = 'unknown'

   if actor1:GetType() ~= type_1 or actor2:GetType() ~= type_2 then
      return false
   end

   if dialogue.gender ~= nil then
      gender_1 = dialogue.gender[1]
      gender_2 = dialogue.gender[2]

      if gender_1 == 'female' and not tobool(string.find(npc1_model, 'female_*')) then
         return false
      elseif gender_1 == 'male' and tobool(string.find(npc1_model, 'female_*')) then
         return false
      elseif gender_1 == 'any' then
         if tobool(string.find(npc1_model, 'female_*')) then
            gender_1 = 'female'
         else
            gender_1 = 'male'
         end
      end

      if gender_2 == 'female' and not tobool(string.find(npc2_model, 'female_*')) then
         return false
      elseif gender_2 == 'male' and tobool(string.find(npc2_model, 'female_*')) then
         return false
      elseif gender_2 == 'any' then
         if tobool(string.find(npc2_model, 'female_*')) then
            gender_2 = 'female'
         else
            gender_2 = 'male'
         end
      end
   end

   local index = table.insert(dialogue_actors, {
      id = tostring(CurTime()) .. tostring(RealTime()) .. actor1:GetType() .. actor2:GetType(),
      interlocutors = {
         [1] = actor1,
         [2] = actor2,
      },
      gender = {
         [1] = gender_1,
         [2] = gender_2,
      },
      data = dialogue,
      list = dialogue.list,
      animations = dialogue.animations or {},
      replic = replic,
      speaking = 1,
      replicId = 1,
      replicMax = table.Count(dialogue.list),
      soundId = 1,
      soundMax = table.Count(replic),
      switchTime = CurTime() + slib.SoundDuration('sound/' .. NormalizeSoundPath(replic[1], gender_1)) + 1,
      isIdle = false,
   })
   
   _EmitSound(actor1, NormalizeSoundPath(replic[1], gender_1))
   _PlayAnimation(dialogue_actors[index])
   
   return true
end

function ASSET:UnsetDialogue(id)
   for i = #dialogue_actors, 1, -1 do
      local dialogue = dialogue_actors[i]
      if dialogue.id == id then
         table.remove(dialogue_actors, i)
         
         local actor1 = dialogue.interlocutors[1]
         local actor2 = dialogue.interlocutors[2]

         if dialogue.data.finalAction ~= nil then
            dialogue.data.finalAction(actor1, actor2)
         else
            actor1:RandomState()
            actor2:RandomState()
         end

         break
      end
   end
end

function ASSET:GetDialogue(actor)
   for index, value in ipairs(dialogue_actors) do
      for _, interlocutor in ipairs(value.interlocutors) do
         if interlocutor == actor then
            return dialogue_actors[index]
         end
      end
   end
   return nil
end

function ASSET:SwitchDialogue(actor)
   local dialogue = self:GetDialogue(actor)
   if dialogue == nil then return end

   if dialogue.interlocutors[1] == nil or not dialogue.interlocutors[1]:IsAlive() then
      self:UnsetDialogue(dialogue.id)
      return
   elseif dialogue.interlocutors[2] == nil or not dialogue.interlocutors[2]:IsAlive() then
      self:UnsetDialogue(dialogue.id)
      return
   end

   local gender = dialogue.gender[dialogue.speaking]

   if dialogue.switchTime < CurTime() then
      if dialogue.soundId + 1 > dialogue.soundMax then
         if dialogue.replicId + 1 > dialogue.replicMax then
            self:UnsetDialogue(dialogue.id)
         else
            local newReplicId = dialogue.replicId + 1
            dialogue.replicId = newReplicId
            dialogue.replic = dialogue.list[newReplicId]
            dialogue.soundId = 1
            dialogue.soundMax = table.Count(dialogue.replic)

            if dialogue.speaking == 1 then
               dialogue.speaking = 2
            else
               dialogue.speaking = 1
            end

            gender = dialogue.gender[dialogue.speaking]

            local sound_path = NormalizeSoundPath(dialogue.replic[1], gender)
            dialogue.switchTime = CurTime() + slib.SoundDuration('sound/' .. sound_path) + 0.5
            
            local actor = dialogue.interlocutors[dialogue.speaking]
            _EmitSound(actor, sound_path)
            _PlayAnimation(dialogue)
         end
      else
         dialogue.soundId = dialogue.soundId + 1
         local sound_path = NormalizeSoundPath(dialogue.replic[dialogue.soundId], gender)
         dialogue.switchTime = CurTime() + slib.SoundDuration('sound/' .. sound_path) + 0.5

         local actor = dialogue.interlocutors[dialogue.speaking]
         _EmitSound(actor, sound_path)
         _PlayAnimation(dialogue)
      end
   end
end

function ASSET:ClearAll()
	table.Empty(dialogue_actors)
end

function ASSET:RemoveBadValues()
   for i = #dialogue_actors, 1, -1 do
      local value = dialogue_actors[i]
      local actor1 = value.interlocutors[1]
      local actor2 = value.interlocutors[2]

      if not actor1:HasState('dialogue') or not actor2:HasState('dialogue') then
         table.remove(dialogue_actors, i)
      end
   end
end

hook.Add("BGN_ActorLookAtObject", "BGN_Module_DialogueState", function(actor, ent)
   local dialogue = ASSET:GetDialogue(actor)
   if dialogue ~= nil and not dialogue.isIdle then
      local actor1 = dialogue.interlocutors[1]
      local actor2 = dialogue.interlocutors[2]

      local npc1 = actor1:GetNPC()
      local npc2 = actor2:GetNPC()

      if not IsValid(npc1) or not IsValid(npc2) then return end

      if ent == npc1 or ent == npc2 then
         if actor:GetNPC():GetPos():Distance(ent:GetPos()) <= 180 then
            dialogue.isIdle = true
         end

         if actor1:IsSequenceFinished() then
            npc1:ResetSequenceInfo()
         end

         if actor2:IsSequenceFinished() then
            npc2:ResetSequenceInfo()
         end
      end
   end
end)

list.Set('BGN_Modules', 'actors_dialogue', ASSET)