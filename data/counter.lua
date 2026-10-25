-- data/counter.lua — the counter: the building the player places.
--
-- Description: a clone of the base steel chest, because `container` is the one prototype type whose
--              inventory is a single general slot pool: inserters and logistics robots fill and empty
--              it with no script at all (ADR 0016). Nothing of `base` is modified — the clone is a
--              new prototype with its own name.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial prototype: inventory size from config/balance.lua
-- Usages:      required by data.lua; place_result of the item defined in data/item.lua
-- Notes:       POWER. ADR 0030 asks for a small electric draw on this building. Measured 2026-10-25
--              on 2.1.23: a `container` accepts an `energy_source` key in the data stage and drops
--              it silently — at runtime the prototype has no `energy_source`, the entity has no
--              `electric_energy_source_prototype`, and `energy_usage` is nil. A container cannot
--              carry power. That is a framing conflict (0030 vs 0016), not an oversight: it needs an
--              ADR, and until then this prototype has no power field rather than a decorative one.
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
