-- config/balance.lua — the hand-set numbers of the mod, in one file.
--
-- Description: every number a balancing pass may want to change, and nothing else. Derived prices
--              are not here: `data/prices.lua` is generated from the game's recipes by
--              `tools/cost_table.py` (`make prices`).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: counter size and spacing
-- Usages:      required by the data files (prototypes) and by the control-stage modules
-- Notes:       AGENTS.md requires these numbers in one data file so they can be tuned without
--              touching logic. A comment explains each value; a value nobody can justify is a bug.
-- Licence:     MIT (see LICENSE)

return {
  counter = {
    -- Slots of the counter's own inventory. It is a `container`, so this is the whole stock: goods
    -- for up to three contracts (a few stacks each) plus what the player parks here. 48 is one
    -- steel chest, a size every player already knows.
    inventory_size = 48,

    -- Tiles between two counters, centre to centre. The hub is a spaceport, not a chest: two of them
    -- in the same logistic footprint would make the choice of a site meaningless (ADR 0014). 150
    -- tiles is ~4.7 chunks, wider than a base's first bus and narrower than a radar's reach.
    min_distance = 150,
  },
}
