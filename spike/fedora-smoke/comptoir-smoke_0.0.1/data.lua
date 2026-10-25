-- Throwaway. If this file fails, the machine cannot load a mod and nothing else matters.
-- It adds one useless item so the data stage has something to prove.

data:extend({
  {
    type = "item",
    name = "comptoir-smoke-token",
    icon = "__base__/graphics/icons/copper-plate.png",
    icon_size = 64,
    stack_size = 100,
    subgroup = "raw-material",
    order = "z[comptoir-smoke]",
  },
})
