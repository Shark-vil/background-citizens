-- overhead lines (actor/cl_actor_text_say.lua), drawn in 3D2D at a small scale: big sizes stay sharp
surface.CreateFont('BGN_SpeakingFont', {
  font = 'Roboto',
  extended = true,
  size = 28,
  weight = 500,
  antialias = true,
})

surface.CreateFont('BGN_SpeakingName', {
  font = 'Roboto',
  extended = true,
  size = 20,
  weight = 800,
  antialias = true,
})
