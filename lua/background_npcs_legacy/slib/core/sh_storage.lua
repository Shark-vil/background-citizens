function slib.GetStorage(storage_name)
	return slib.Storage[storage_name]
end

function slib.SetStorage(storage_name, data)
	slib.Storage[storage_name] = data
end