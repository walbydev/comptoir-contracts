-- data/counter.lua — the counter: the building the player places.
--
-- Description: a clone of the base steel chest, because `container` is the one prototype type whose
--              inventory is a single general slot pool: inserters and logistics robots fill and empty
--              it with no script at all (ADR 0016). Nothing of `base` is modified — the clone is a
--              new prototype with its own name.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial prototype: inventory size from config/balance.lua
--              2026-10-25 — power note removed: the counter draws nothing (D75, ADR 0046)
-- Usages:      required by data.lua; place_result of the item defined in data/item.lua
-- Notes:       POWER. The counter consumes no energy at all (D75, ADR 0045/0046): a `container` has no
--              energy model — measured 2026-10-25 on 2.1.23, an `energy_source` key is dropped
--              silently at the data stage, the runtime prototype has none, the entity has no
--              `electric_energy_source_prototype` and `energy_usage` is nil. So there is no pole to
--              place, no network to connect to, and no "unpowered" state to display.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")

local counter = table.deepcopy(data.raw["container"]["steel-chest"])

counter.name = "comptoir-counter"
counter.inventory_size = balance.counter.inventory_size
counter.minable = { mining_time = 0.5, result = "comptoir-counter" }

-- The picture is the base chest's, tinted: v0.1 ships placeholders (docs/00-cadrage.md, non-goals).
for _, layer in pairs(counter.picture.layers) do
  if not layer.draw_as_shadow then
    layer.tint = { r = 0.55, g = 1.0, b = 0.65, a = 0.85 }
  end
end

data:extend({ counter })
