-- config/balance.lua — the hand-set numbers of the mod, in one file.
--
-- Description: every number a balancing pass may want to change, and nothing else. Derived prices
--              are not here: `data/prices.lua` is generated from the game's recipes by
--              `tools/cost_table.py` (`make prices`).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: counter size and spacing
--              2026-10-25 — economy, contract generation and elevator sections (a5, a6, a7)
-- Usages:      required by the data files (prototypes) and by the control-stage modules
-- Notes:       AGENTS.md requires these numbers in one data file so they can be tuned without
--              touching logic. A comment explains each value; a value nobody can justify is a bug.
--              No energy number: the counter draws nothing (D75, ADR 0045/0046).
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

  economy = {
    -- Credits issued once, to the cooperative, when a force's economy is born (D28, ADR 0036).
    -- The federation's account starts at minus this amount and stays negative: it is the issuer, and
    -- the only holder allowed below zero. 3 000 covers six escrows and still buys a stack
    -- (docs/05-price-table.md §4).
    endowment = 3000,

    -- Escrow rate, taken from the payout on acceptance (D47). Stored as a percentage of integer
    -- credits rather than as 0.2, because `ceil(payout * 0.2)` is not exact in IEEE 754: 2500 * 0.2
    -- is 500.00000000000006, which would round up to a 501-credit reserve. `payout * 20 / 100` is.
    escrow_percent = 20,
  },

  contracts = {
    -- The payout a generated contract aims at, in credits. A contract asks for
    -- `round(target_payout / payout(item))` units, so cheap goods are asked by the hundred and dear
    -- ones by the handful (ADR 0034 §4). 2 500 reproduces the canonical first contract of
    -- docs/05-price-table.md §7: 208 iron plates, 208 x 12 = 2 496 credits. The exact figure is not
    -- stated in any document; 2 500 is the round value inside [2 490, 2 502], the only interval that
    -- yields 208.
    target_payout = 2500,

    -- The band the quantity is clamped to (ADR 0034 §4). 30 is the smallest run worth a trip; 500 is
    -- what one steel chest holds, so a contract can never exceed the counter's own inventory.
    min_quantity = 30,
    max_quantity = 500,

    -- Floor of the deadline, in seconds (D58: `max(10 min, ...)`). A contract that expires before the
    -- player can organise is not a contract, it is a stolen escrow.
    min_deadline_seconds = 600,

    -- Machines assumed dedicated to a contract (ADR 0034 §4: `quantity x machine_seconds / 2`).
    machines = 2,
  },

  elevator = {
    -- A full round trip of the elevator car, in seconds (ADR 0043). Added to every deadline: a
    -- contract whose goods cannot come back up in time is a contract that expires in the air.
    cycle_seconds = 120,
  },
}
