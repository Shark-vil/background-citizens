-- Rendering is owned by cl_actor_visuals.lua. Remove legacy passes on reload.
hook.Remove('PostDrawHUD', 'BGN_Debug_RenderTargetsPath')
hook.Remove('HUDPaint', 'BGN_Debug_RenderTargetsPath')
hook.Remove('PostDrawOpaqueRenderables', 'BGN_Debug_RenderTargetsPath')
hook.Remove('PostDrawTranslucentRenderables', 'BGN_Debug_RenderTargetsPath')
