--[[
	CustomProvider: our own node graph, saved in data/background_npcs/graph/<map>.dat.
	Old route files (data/background_npcs/nodes/<map>.dat|.json, still shipped by map packs)
	are converted and saved in the current format when no valid new graph exists.
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
	local load_error

	if HasData(path) then
		local graph, err = NodeGraph.Deserialize(file.Read(path, 'DATA'))
		if graph then
			self.graph = graph
			self.source = 'file'
			return true
		end
		load_error = 'broken graph file ' .. path .. ': ' .. tostring(err)
	end

	if bgNPC.LegacyNodes.Exists() then
		local graph, err = bgNPC.LegacyNodes.Convert()
		if not graph then return false, 'old route file: ' .. tostring(err) end
		self.graph = graph
		return self:Save()
	end
	if load_error then return false, load_error end

	self.graph = NodeGraph()
	self.source = 'empty'
	return true
end

-- @return boolean saved
function CustomProvider:Save(map_name)
	file.CreateDir('background_npcs/graph')
	local path, data = GraphPath(map_name), self.graph:Serialize()
	file.Write(path, data)
	if file.Read(path, 'DATA') ~= data then return false, 'could not save graph ' .. path end
	self.source = 'file'
	return true
end

function CustomProvider:GetInfo()
	local info = Nav.GraphProvider.GetInfo(self)
	info.source = self.source
	return info
end

Nav.RegisterProvider('custom', CustomProvider)
