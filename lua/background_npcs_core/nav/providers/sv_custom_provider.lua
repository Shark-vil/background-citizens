--[[
	CustomProvider: our own node graph, saved in data/background_npcs/graph/<map>.dat.
	Old route files (data/background_npcs/nodes/<map>.dat|.json, still shipped by map packs)
	are converted in memory when no new file exists.
--]]

local Nav = bgNPC.Nav
local NodeGraph = bgNPC.NodeGraph

local CustomProvider = bgNPC.Class('BGN_CustomProvider', Nav.GraphProvider)
Nav.CustomProvider = CustomProvider

local function GraphPath(map_name)
	return 'background_npcs/graph/' .. (map_name or game.GetMap()) .. '.dat'
end
CustomProvider.GraphPath = GraphPath

local function HasData(path)
	return file.Exists(path, 'DATA') and file.Size(path, 'DATA') > 0
end

function CustomProvider.IsAvailable()
	return true
end

function CustomProvider.HasSavedRoute()
	return HasData(GraphPath()) or bgNPC.LegacyNodes.Exists()
end

function CustomProvider:Load()
	local path = GraphPath()

	if HasData(path) then
		local graph, err = NodeGraph.Deserialize(file.Read(path, 'DATA'))
		if not graph then return false, 'broken graph file ' .. path .. ': ' .. tostring(err) end
		self.graph = graph
		self.source = 'file'
		return true
	end

	if bgNPC.LegacyNodes.Exists() then
		local graph, err = bgNPC.LegacyNodes.Convert()
		if not graph then return false, 'old route file: ' .. tostring(err) end
		self.graph = graph
		self.source = 'legacy'
		return true
	end

	self.graph = NodeGraph()
	self.source = 'empty'
	return true
end

-- @return boolean saved
function CustomProvider:Save()
	file.CreateDir('background_npcs/graph')
	file.Write(GraphPath(), self.graph:Serialize())
	self.source = 'file'
	return true
end

function CustomProvider:GetInfo()
	local info = Nav.GraphProvider.GetInfo(self)
	info.source = self.source
	return info
end

Nav.RegisterProvider('custom', CustomProvider)
