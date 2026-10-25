-- data/counter.lua — the counter: the building the player places.
--
-- Description: a clone of the base steel chest, because `container` is the one prototype type whose
--              inventory is a single general slot pool: inserters and logistics robots fill and empty
--              it with no script at all (ADR 0016). Nothing of `base` is modified — the clone is a
--              new prototype with its own name. The picture, the collision box and the selection box
--              are the mod's own: a 9 x 9 building drawn from graphics/counter/counter.png.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial prototype: inventory size from config/balance.lua
--              2026-10-25 — power note removed: the counter draws nothing (D75, ADR 0046)
--              2026-10-25 — the 9 x 9 sprite (ADR 0056 §1): the base chest's tinted picture is gone,
--                           the picture is `graphics/counter/counter.png` at scale 1 (288 px = 9
--                           tiles at 32 px), and the collision/selection boxes are the halves of
--                           `balance.counter.footprint_tiles`. The base prototype is still the source
--                           of everything else (inventory, mask, render order)
-- Usages:      required by data.lua; place_result of the item defined in data/item.lua
-- Notes:       POWER. The counter consumes no energy at all (D75, ADR 0045/0046): a `container` has no
--              energy model — measured 2026-10-25 on 2.1.23, an `energy_source` key is dropped
--              silently at the data stage, the runtime prototype has none, the entity has no
--              `electric_energy_source_prototype` and `energy_usage` is nil. So there is no pole to
--              place, no network to connect to, and no "unpowered" state to display.
--              THE SIZE IS ONE NUMBER. 288 px at 32 px per tile is 9 tiles, so the boxes are
--              `{-4.5, -4.5}, {4.5, 4.5}`; both are computed from `balance.counter.footprint_tiles`
--              so the art and the footprint cannot drift apart in silence. The sprite is NEVER
--              scaled: `scale = 1`, and the file is drawn at its native size.
--              ONE PICTURE FOR THE FOUR DIRECTIONS. A container's `picture` is a Sprite — measured
--              2026-10-25 on 2.1.23: the runtime prototype of `steel-chest` carries `layers`, not a
--              4-way sheet — and the counter's art is symmetric, so north/east/south/west would be
--              the same file four times.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")

local counter = table.deepcopy(data.raw["container"]["steel-chest"])

counter.name = "comptoir-counter"
counter.inventory_size = balance.counter.inventory_size
counter.minable = { mining_time = 0.5, result = "comptoir-counter" }

-- The footprint: 9 tiles, half of it on each side of the centre. The two boxes are the same square,
-- because what the player can click and what the player cannot walk through are the same building.
local half = balance.counter.footprint_tiles / 2
counter.collision_box = { { -half, -half }, { half, half } }
counter.selection_box = { { -half, -half }, { half, half } }

-- The art: nine tiles of 32 px, one layer, native size. No shadow layer, no tint — the file is the
-- colour (tools/make_counter_sprite.py is the only thing that paints it).
counter.picture = {
  layers = {
    {
      filename = "__comptoir-contracts__/graphics/counter/counter.png",
      width = 288,
      height = 288,
      scale = 1,
      shift = { 0, 0 },
    },
  },
}

data:extend({ counter })
