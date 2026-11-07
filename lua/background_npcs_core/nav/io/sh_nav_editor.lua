--[[
	Route editing between an admin client (point editor tool) and the server.

	Client:
		bgNPC.NavEditor.graph                 the graph being edited (bgNPC.NodeGraph)
		bgNPC.NavEditor.RequestGraph()        loads the server's graph into the editor
		bgNPC.NavEditor.SaveGraph()           saves the editor graph on the server (custom provider)
		bgNPC.NavEditor.RequestPath(a, b, cb) asks the server for an actor path (debug tool)
	Hooks (client): BGN_NavEditorGraphLoaded(graph), OUTDATED: BGN_LoadingClientRoutes(graph)

	The editor gets the custom graph, or the nodegraph points when the map uses them (to start from),
	or an empty graph on navmesh maps.
--]]

local NavEditor = bgNPC.NavEditor or {}
bgNPC.NavEditor = NavEditor

local NodeGraph = bgNPC.NodeGraph
local Net = bgNPC.Net

NavEditor.LINK_DISTANCE = 500

-- Can two points be linked automatically (distance, height limit, no wall).
function NavEditor.CanAutoLink(a, b)
	if a:DistToSqr(b) > NavEditor.LINK_DISTANCE ^ 2 then return false end

	local z_limit = GetConVar('bgn_point_z_limit')
	if z_limit and math.abs(a.z - b.z) > z_limit:GetFloat() then return false end

	local up = Vector(0, 0, 10)
	local tr = util.TraceLine({ start = a + up, endpos = b + up, mask = MASK_NPCWORLDSTATIC })
	return not tr.Hit
end

-- Links id with every node it can reach. @param walk boolean also add the "walk" type
function NavEditor.AutoLink(graph, id, walk)
	local pos = graph:GetPos(id)
	graph:ForEachInRadius(pos, NavEditor.LINK_DISTANCE, function(other, other_pos)
		if other ~= id and not graph:IsLinked(id, other) and NavEditor.CanAutoLink(pos, other_pos) then
			graph:Link(id, other, walk and 'walk' or nil)
		end
	end)
end

if SERVER then
	local function EditorGraph()
		local provider = bgNPC.Nav.GetProvider()
		if provider.GetGraph then return provider:GetGraph() end
		return NodeGraph()
	end

	Net.Receive('bgn_nav_editor_request', function(ply)
		Net.Send('bgn_nav_editor_graph', ply, util.Base64Encode(EditorGraph():Serialize(), true))
	end, { admin = true })

	Net.Receive('bgn_nav_editor_save', function(ply, data)
		local graph, err = NodeGraph.Deserialize(isstring(data) and util.Base64Decode(data) or nil)
		if not graph then
			bgNPC.Util.Notify(ply, 'Route was not saved: ' .. tostring(err), NOTIFY_ERROR)
			return
		end

		file.CreateDir('background_npcs/graph')
		file.Write(bgNPC.Nav.CustomProvider.GraphPath(), graph:Serialize())
		bgNPC.Nav.Load('custom')
		bgNPC.Util.Notify(ply, 'Route saved: ' .. graph:Count() .. ' points', NOTIFY_GENERIC)
	end, { admin = true })

	Net.Receive('bgn_nav_editor_remove', function(ply)
		local path = bgNPC.Nav.CustomProvider.GraphPath()
		if file.Exists(path, 'DATA') then file.Delete(path) end
		bgNPC.Nav.Load()
		bgNPC.Util.Notify(ply, 'Route file removed, navigation: ' .. bgNPC.Nav.GetName(), NOTIFY_GENERIC)
	end, { admin = true })

	Net.Receive('bgn_nav_debug_path', function(ply, start_pos, end_pos)
		if not isvector(start_pos) or not isvector(end_pos) then return end
		Net.Send('bgn_nav_debug_path', ply, bgNPC.Points.FindPath(start_pos, end_pos, nil, 'walk'))
	end, { admin = true })

	return
end

-- ---------------------------------------------------------------------------
-- Client
-- ---------------------------------------------------------------------------

NavEditor.graph = NavEditor.graph or NodeGraph()

function NavEditor.RequestGraph()
	Net.SendToServer('bgn_nav_editor_request')
end

function NavEditor.SaveGraph()
	Net.SendToServer('bgn_nav_editor_save', util.Base64Encode(NavEditor.graph:Serialize(), true))
end

function NavEditor.ClearGraph()
	NavEditor.graph = NodeGraph()
	hook.Run('BGN_NavEditorGraphLoaded', NavEditor.graph)
end

Net.Receive('bgn_nav_editor_graph', function(_, data)
	local graph = NodeGraph.Deserialize(util.Base64Decode(data or ''))
	NavEditor.graph = graph or NodeGraph()
	notification.AddLegacy('[Background NPCs] Loaded ' .. NavEditor.graph:Count() .. ' points', NOTIFY_GENERIC, 4)
	hook.Run('BGN_NavEditorGraphLoaded', NavEditor.graph)
	hook.Run('BGN_LoadingClientRoutes', NavEditor.graph) -- OUTDATED
end, { admin = true })

local path_callback
function NavEditor.RequestPath(start_pos, end_pos, callback)
	path_callback = callback
	Net.SendToServer('bgn_nav_debug_path', start_pos, end_pos)
end

Net.Receive('bgn_nav_debug_path', function(_, path)
	if path_callback then path_callback(path or {}) end
end, { admin = true })

local function IsAdmin()
	local ply = LocalPlayer()
	return ply:IsAdmin() or ply:IsSuperAdmin()
end

concommand.Add('cl_citizens_load_route_from_client', function()
	if IsAdmin() then NavEditor.RequestGraph() end
end, nil, 'Loads the server route into the point editor.')

concommand.Add('cl_citizens_save_route', function()
	if not IsAdmin() then return end
	if NavEditor.graph:Count() == 0 then
		Derma_Query('Save an EMPTY route? The route file on the server will be replaced.', 'Background NPCs',
			'Save', NavEditor.SaveGraph, 'Cancel')
		return
	end
	NavEditor.SaveGraph()
end, nil, 'Saves the point editor route on the server.')

concommand.Add('cl_citizens_remove_route', function(_, _, args)
	if not IsAdmin() then return end
	if args[1] ~= 'yes' then
		MsgN('[Background NPCs] Confirm with: cl_citizens_remove_route yes')
		return
	end
	Net.SendToServer('bgn_nav_editor_remove')
end, nil, 'Removes the saved route file of the current map from the server.')

concommand.Add('cl_bgn_clear_tool_points', function()
	NavEditor.ClearGraph()
end, nil, 'Clears the point editor (client only, the server file is kept).')

-- OUTDATED console commands from the old route system
concommand.Add('cl_citizens_load_route', function() RunConsoleCommand('bgn_nav_reload') end)
concommand.Add('cl_citizens_clear_route', function() NavEditor.ClearGraph() end)
concommand.Add('cl_citizens_get_load_info_route', function() RunConsoleCommand('bgn_nav_info') end)
