-- Rendering is owned by cl_actor_visuals.lua. Remove legacy passes on reload.
hook.Remove('PostDrawHUD', 'BGN_Debug_MovementPathRender')
hook.Remove('HUDPaint', 'BGN_Debug_MovementPathRender')
hook.Remove('PostDrawOpaqueRenderables', 'BGN_Debug_MovementPathRender')
hook.Remove('PostDrawTranslucentRenderables', 'BGN_Debug_MovementPathRender')
