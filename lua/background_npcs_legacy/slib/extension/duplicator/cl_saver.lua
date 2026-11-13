local saveDupesQueue = {}

function slib.SaveDupe(identifier, stringOrTableData, picture)
	if not isstring(identifier) then return end
	if not isstring(stringOrTableData) and not istable(stringOrTableData) then return end

	table.insert(saveDupesQueue, {
		id = identifier,
		data = stringOrTableData,
		picture = picture
	})
end

hook.Add('PostRender', 'Slib.CustomDupe.Saver', function()
	local queueCount = #saveDupesQueue
	if queueCount == 0 then return end

	for i = queueCount, 1, -1 do
		local entry = saveDupesQueue[i]
		table.remove(saveDupesQueue, i)

		local dupe = {}
		dupe.id = entry.id

		local data
		if isstring(entry.data) then
			data = entry.data
		elseif istable(entry.data) then
			data = entry.data
		else
			continue
		end

		if data then
			dupe.data = data
			dupe.slibrary = true

			local picture
			if isstring(entry.picture) then
				picture = entry.picture
			elseif istable(entry.picture) then
				picture = render.Capture(entry.picture)
			else
				picture = render.Capture({
					format = 'jpg',
					x = 0,
					y = 0,
					w = 512,
					h = 512
				})
			end

			local compressed_dupe = util.Compress(util.TableToJSON(dupe))
			if compressed_dupe then
				engine.WriteDupe(compressed_dupe, picture)
				notification.AddLegacy('Duplication "' .. dupe.id .. '" saved!', NOTIFY_GENERIC, 4)
			end
		end
	end
end)