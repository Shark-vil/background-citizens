-- Standing together and talking: systems/dialogue/sv_conversation.lua runs the conversation, this state holds them.
local Conv = bgNPC.Conversation
bgNPC.States.Register('dialogue', 'calm', {
  validator = function(actor) return actor.conversation ~= nil or Conv.TryStart(actor) end,
  update = function(actor) if not actor.conversation then actor:RandomState() end end,
  stop = function(actor)
    local conv = actor.conversation
    if conv then
      actor.conversation = nil -- the others notice it on the next tick and go back to their business
      if conv.phase == 'talk' then actor:StopWalk() end
    end
  end,
})
