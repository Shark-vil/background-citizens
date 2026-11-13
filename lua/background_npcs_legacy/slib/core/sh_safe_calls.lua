local xpcall = xpcall
local debug_traceback = debug.traceback
--

function slib.def(methods)
	local try = methods.try or methods.exec
	if try then
		xpcall(try, function(ex)
			local catch = methods.catch or methods.error
			if not catch then return end
			catch(debug_traceback(ex))
		end)
	end

	local finally = methods.finally or methods.done
	if finally then
		finally()
	end
end