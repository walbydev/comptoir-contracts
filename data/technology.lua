-- data/technology.lua — the one technology of v1, and the recipe it unlocks.
--
-- Description: the counter must be reachable before oil, because the whole loop (contract, delivery,
--              shop) is supposed to exist before the refinery does (ADR 0033). So the recipe of the
--              counter contains no fluid-derived item, and the technology costs red and green science
--              only. `steam-power` is a prerequisite because the recipe consumes pipes, which that
--              technology unlocks; the engine does not check that, a reviewer does.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: recipe + technology `comptoir-counter`
-- Usages:      required by data.lua
-- Notes:       The ingredient list is the only place a fluid-derived item could slip in, and it is
--              the one line the A16 static check reads (docs/09-tests.md). Recipe cost: 50 steel
--              plates + 100 circuits + 50 stone bricks + 10 pipes = 610 raw units, i.e. ~6 100
--              credits at the scale of docs/05-price-table.md — an early-game decision, not a
--              formality. The recipe declares `categories` (a list), the 2.1 field; the technology
--              icon is base's steel-processing sprite, a 256 px technology asset, as a placeholder.
--              Icons are not loaded by a headless build, so this box can only prove the load.
-- Licence:     MIT (see LICENSE)

data:extend({
  {
    type = "recipe",
    name = "comptoir-counter",
    enabled = false,
    categories = { "crafting" },
    energy_required = 5,
    ingredients = {
      { type = "item", name = "steel-plate", amount = 50 },
      { type = "item", name = "electronic-circuit", amount = 100 },
      { type = "item", name = "stone-brick", amount = 50 },
      { type = "item", name = "pipe", amount = 10 },
    },
    results = { { type = "item", name = "comptoir-counter", amount = 1 } },
  },
  {
    type = "technology",
    name = "comptoir-counter",
    icon = "__base__/graphics/technology/steel-processing.png",
    icon_size = 256,
    prerequisites = { "steel-processing", "electronics", "steam-power" },
    unit = {
      count = 50,
      time = 30,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
    },
    effects = { { type = "unlock-recipe", recipe = "comptoir-counter" } },
  },
})
