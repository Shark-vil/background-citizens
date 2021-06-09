local function AutoCreatePoints(startPos, endPos)
	local points = {}
	local dist = startPos:Distance(endPos)
	local max = math.floor(dist / 100)
	local limit = 1 / max

	if max >= 1 then
		for i = 1, max do
			local fraction = limit * i
			local output = LerpVector(fraction, startPos, endPos)
			table.insert(points, output)
		end
	end

	return points
end

local function ConstructParent(node, set_max_pass, yield)
	local node_pos = node:GetPos()
	local max_pass = set_max_pass or 70
	local current_pass = 0

	for _, anotherNode in ipairs(BGN_NODE:GetNodeMap()) do
		if anotherNode ~= node then
			local pos = anotherNode:GetPos()
			local points = AutoCreatePoints(node_pos, pos, yield)

			for i = 1, #points do
				local tr = util.TraceLine({
					start = points[i],
					endpos = points[i] - Vector(0, 0, 10),
					filter = function(ent)
						if ent:IsWorld() then
							return true
						end
					end
				})

				if not tr.Hit then
					goto skip
				end
			end

			if not anotherNode:HasParent(node) and node:CheckDistanceLimitToNode(pos) 
				and node:CheckHeightLimitToNode(pos) and node:CheckTraceSuccessToNode(pos)
			then
				anotherNode:AddParentNode(node)
				anotherNode:AddLink(node, 'walk')
			end
		end

		::skip::

		current_pass = current_pass + 1
		if current_pass == max_pass then
			current_pass = 0
			yield()
		end
	end
end

slib:RegisterGlobalCommand('bgn_generate_navmesh', nil, function(ply, cmd, args)
	local old_progress = -1

	async.Add('bgn_generate_navmesh', function(yield)
		if not navmesh.IsLoaded() then
			snet.Invoke('bgn_generate_navmesh_not_exists', ply)
			return
		end

		BGN_NODE:ClearNodeMap()

		local navmesh_map = navmesh.GetAllNavAreas()
		local max = #navmesh_map

		for i = 1, max do
			local area = navmesh_map[i]

			local pos = area:GetRandomPoint()
			local tr = util.TraceLine({
				start = pos,
				endpos = pos - Vector(0, 0, 10),
				filter = function(ent)
					if ent:IsWorld() then
						return true
					end
				end
			})

			if tr.Hit then
				local node = BGN_NODE:Instance(area:GetCenter())
				ConstructParent(node, args[1], yield)
				BGN_NODE:AddNodeToMap(node)
			end

			local new_progress = math.Round((i / max) * 100)
			if new_progress ~= old_progress then
				snet.Invoke('bgn_generate_navmesh_progress', ply, new_progress)
				old_progress = new_progress
			end

			::skip::
		end

		snet.Create('bgn_movement_mesh_load_from_client_cl')
			.BigData(BGN_NODE:MapToJson(), nil, 'Loading mesh from server')
			.Invoke(ply)

		snet.Invoke('bgn_generate_navmesh_progress_kill', ply)
	end)
end)

if CLIENT then
	snet.RegisterCallback('bgn_generate_navmesh_progress', function(ply, percent)
		notification.AddProgress('bgn_generate_navmesh', 'Generated by: ' .. percent .. '%', percent / 100)
	end)

	snet.RegisterCallback('bgn_generate_navmesh_progress_kill', function(ply)
		notification.Kill('bgn_generate_navmesh')
	end)

	snet.RegisterCallback('bgn_generate_navmesh_not_exists', function(ply)
		notification.AddLegacy('The map does not have a navigation mesh. Generation is not possible.', NOTIFY_ERROR, 4)
	end)
end