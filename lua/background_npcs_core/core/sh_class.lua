--[[
	Minimal class system.

		local Animal = bgNPC.Class('Animal')
		function Animal:Init(name) self.name = name end

		local Dog = bgNPC.Class('Dog', Animal)
		function Dog:Init(name)
			Animal.Init(self, name) -- explicit super call
		end

		local dog = Dog('Rex')          -- or Dog.New('Rex')
		bgNPC.IsInstanceOf(dog, Animal) -- true
--]]

--

function bgNPC.Class(name, base)
	local cls = {}
	cls.__index = cls
	cls.ClassName = name
	cls.Super = base

	-- Every class gets its own constructor, so subclasses never build base instances.
	function cls.New(...)
		local obj = setmetatable({}, cls)
		if obj.Init then obj:Init(...) end
		return obj
	end

	return setmetatable(cls, {
		__index = base,
		__call = function(_, ...) return cls.New(...) end,
	})
end

function bgNPC.IsInstanceOf(obj, cls)
	if not istable(obj) then return false end

	local mt = getmetatable(obj)
	while mt do
		if mt == cls then return true end
		mt = mt.Super
	end

	return false
end
