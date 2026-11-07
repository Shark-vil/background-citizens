-- Debug: draws the chunk (grid cell) the local player stands in.
-- The grid is uniform, so the client computes cells from the synced "bgn_chunk_size".
if SERVER then return end

local cvar_bgn_debug = GetConVar('bgn_debug')
local cvar_bgn_cl_draw_chunks = GetConVar('bgn_cl_draw_chunks')
local angle_zero = Angle()
local color_box_line = Color(255, 255, 255)
local color_box = Color(236, 154, 243, 50)
local grid

hook.Add('PostDrawTranslucentRenderables', 'BGN_Nodes_ChunkRenderer', function()
	if not cvar_bgn_debug:GetBool() or not cvar_bgn_cl_draw_chunks:GetBool() then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local size = bgNPC.Util.IsInfinityMap() and 10000 or GetConVar('bgn_chunk_size'):GetInt()
	if not grid or grid.size ~= size then grid = bgNPC.SpatialGrid(size) end

	local chunk = grid:GetCell(ply:GetPos())
	local center = chunk.center_pos
	local mins = WorldToLocal(chunk.start_pos, angle_zero, center, angle_zero)
	local maxs = WorldToLocal(chunk.end_pos, angle_zero, center, angle_zero)

	render.SetColorMaterial()
	render.DrawWireframeBox(center, angle_zero, mins, maxs, color_box_line)
	render.DrawBox(center, angle_zero, mins, maxs, color_box)
end)
