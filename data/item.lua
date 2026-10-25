-- data/item.lua — the mod's own items and the subgroup that shows them.
--
-- Description: the counter is an entity, so it needs an item to be crafted and placed: this file
--              defines that item, its icon (the base chest's, tinted like the entity) and the
--              item-subgroup that keeps the mod's icon row apart from the base storage row. No new
--              item-subgroup is derived from a base one; the group `logistics` is reused.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: item-subgroup `comptoir` and item `comptoir-counter`
-- Usages:      required by data.lua; `place_result` points at data/counter.lua
-- Notes:       v0.1 has exactly one item (docs/arborescence.md). A second one is a decision, not a
--              convenience: every item shipped is an icon the player has to learn.
-- Licence:     MIT (see LICENSE)

data:extend({
  {
    type = "item-subgroup",
    name = "comptoir",
    group = "logistics",
    order = "z[comptoir]",
  },
  {
    type = "item",
    name = "comptoir-counter",
    icons = {
      { icon = "__base__/graphics/icons/steel-chest.png", icon_size = 64,
        tint = { r = 0.55, g = 1.0, b = 0.65, a = 0.85 } },
    },
    subgroup = "comptoir",
    order = "a[comptoir-counter]",
    place_result = "comptoir-counter",
    stack_size = 20,
  },
})
