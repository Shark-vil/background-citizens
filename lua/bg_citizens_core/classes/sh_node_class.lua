BGN_NODE = {}

function BGN_NODE:Instance(position, parents)
   local obj = {}
   obj.position = position
   obj.parents = parents

   return obj
end