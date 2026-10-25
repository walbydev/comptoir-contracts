-- Throwaway spike. Two questions:
--  1. can a resource carry a custom category and an autoplace entry?
--  2. can a NON mining-drill entity declare resource_categories to force placement
--     on that resource only? (pumpjack proves mining-drill can; nothing proves others can)

data:extend({ { type = "resource-category", name = "hub-site" } })

local site = table.deepcopy(data.raw.resource["iron-ore"])
site.name = "hub-site"
site.category = "hub-site"
site.infinite = true
site.minimum = 1000
site.normal = 1000
site.autoplace = nil          -- placement restriction only, generation is not the point here
site.map_color = { r = 0.2, g = 1, b = 0.6 }

-- variant B: a mining-drill (the only entity type whose resource_categories the engine honours)
local anchor_b = table.deepcopy(data.raw["mining-drill"]["electric-mining-drill"])
anchor_b.name = "hub-anchor-b"
anchor_b.resource_categories = { "hub-site" }
anchor_b.mining_speed = 0.001
anchor_b.icon = "__base__/graphics/icons/steel-chest.png"

-- variant A: a plain container (NOT a mining drill) - does the engine honour it too?
local anchor_a = table.deepcopy(data.raw.container["steel-chest"])
anchor_a.name = "hub-anchor-a"
anchor_a.resource_categories = { "hub-site" }
anchor_a.icon = "__base__/graphics/icons/steel-chest.png"

data:extend({ site, anchor_a, anchor_b })
