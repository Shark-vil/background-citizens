local SysTime = SysTime
local table_insert = table.insert
--

function slib.ProfilerCreate()
	local obj = {}
	obj.lastTick = 0
	obj.ticks = {}

	function obj:Start()
		self.lastTick = SysTime()
	end

	function obj:End()
		table_insert(self.ticks, SysTime() - self.lastTick)
	end

	function obj:Complete()
		local summ = 0
		local ticks = self.ticks
		local ticks_count = #ticks

		for i = 1, ticks_count do
			summ = summ + ticks[ i ]
		end

		return summ / ticks_count
	end

	return obj
end