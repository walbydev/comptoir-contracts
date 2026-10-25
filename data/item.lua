-- data/item.lua — the mod's own items and the subgroup that shows them.
--
-- Description: the counter is an entity, so it needs an item to be crafted and placed: this file
--              defines that item, its icon (the mod's own 64 px icon, drawn by
--              tools/make_counter_sprite.py) and the item-subgroup that keeps the mod's icon row
--              apart from the base storage row. No new item-subgroup is derived from a base one; the
--              group `logistics` is reused.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: item-subgroup `comptoir` and item `comptoir-counter`
--              2026-10-25 — the item's own icon (ADR 0056 §1): `graphics/counter/counter-icon.png`,
--                           64 x 64, replaces the base chest's tinted icon. One `icon` and one
--                           `icon_size`, not an `icons` list: the item has exactly one icon
-- Usages:      required by data.lua; `place_result` points at data/counter.lua
-- Notes:       v0.1 has exactly one item (docs/arborescence.md). A second one is a decision, not a
--              convenience: every item shipped is an icon the player has to learn.
--              `icon_size = 64` is the native size of the file — the icon is never rescaled, and the
--              engine's own default is 64, so the number is written out rather than assumed.
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
    icon = "__comptoir-contracts__/graphics/counter/counter-icon.png",
    icon_size = 64,
    subgroup = "comptoir",
    order = "a[comptoir-counter]",
    place_result = "comptoir-counter",
    stack_size = 20,
  },
})
