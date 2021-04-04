bgNPC.cfg.sit_chairs = {
   {
      models = {
         'models/props_c17/chair02a.mdl',
         'models/nseven/chair02a.mdl',
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetRight() * -5) + (chair:GetForward() * 2) - (chair:GetUp() * 13)
      end,
      offsetAngle = function(npc, chair, default_offset)
         return default_offset
      end,
   },
   {
      models = { 'models/props_c17/FurnitureChair001a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -15) - (chair:GetUp() * 20)
      end,
      offsetAngle = function(npc, chair, default_offset)
         return default_offset
      end,
   },
   {
      models = {
         'models/props_trainstation/bench_indoor001a.mdl',
         'models/nseven/bench_indoor001a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -14) - (chair:GetUp() * 20)
      end,
   },
   {
      models = {
         'models/props_trainstation/BenchOutdoor01a.mdl',
         'models/nseven/benchoutdoor01a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -17) - (chair:GetUp() * 13)
      end,
   },
   {
      models = { 'models/props_wasteland/cafeteria_bench001a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -17) - (chair:GetUp() * 5)
      end,
   },
   {
      models = {
         'models/props_wasteland/controlroom_chair001a.mdl',
         'models/nseven/controlroom_chair001a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 18)
      end,
   },
   {
      models = {
         'models/props_interiors/Furniture_chair03a.mdl',
         'models/nseven/furniture_chair03a.mdl',
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -13) - (chair:GetUp() * 15)
      end,
   },
   {
      models = { 'models/props_interiors/Furniture_chair01a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -16) - (chair:GetUp() * 15)
      end,
   },
   {
      models = { 
         'models/props_interiors/Furniture_Couch01a.mdl',
         'models/props_interiors/Furniture_Couch02a.mdl',
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 21)
      end,
   },
   {
      models = { 
         'models/props_c17/FurnitureCouch001a.mdl',
         'models/nseven/furniturecouch001a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 15)
      end,
   },
   {
      models = { 
         'models/props_c17/FurnitureCouch002a.mdl',
         'models/nseven/furniturecouch002a.mdl'
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -10) - (chair:GetUp() * 20)
      end,
   },
   {
      models = { 'models/props_c17/bench01a.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -12) - (chair:GetUp() * 17)
      end,
   },
   {
      models = { 'models/props_trainstation/traincar_seats001.mdl' },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -12) + (chair:GetUp() * 2)
      end,
   },
   {
      models = { 
         'models/props_combine/breenchair.mdl',
         'models/nseven/breenchair.mdl' 
      },
      offsetPosition = function(npc, chair, default_offset)
         return default_offset + (chair:GetForward() * -12)
      end,
   },
}