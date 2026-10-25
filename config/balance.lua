-- config/balance.lua — the hand-set numbers of the mod, in one file.
--
-- Description: every number a balancing pass may want to change, and nothing else. Derived prices
--              are not here: `data/prices.lua` is generated from the game's recipes by
--              `tools/cost_table.py` (`make prices`).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: counter size and spacing
--              2026-10-25 — economy, contract generation and elevator sections (a5, a6, a7)
--              2026-10-25 — ADR 0047 applied: quantity floor 1 (not 30), production slack 1.5, deadline
--                           floor 4 min (not 10 min); `target_payout` is read from here and nowhere else
--              2026-10-25 — solvency dial (ADR 0015 D29): the company credit line, three profiles
--              2026-10-25 — elevator phases (8 s / 104 s / 8 s), summing to the cycle of ADR 0043
-- Usages:      required by the data files (prototypes), by the control-stage modules and by settings.lua
-- Notes:       AGENTS.md requires these numbers in one data file so they can be tuned without
--              touching logic. A comment explains each value; a value nobody can justify is a bug.
--              No energy number: the counter draws nothing (D75, ADR 0045/0046).
--              The load-time guard at the bottom is part of the file: a set of numbers that does
--              not add up must fail at load, with a line number, not at the ninth contract.
-- Licence:     MIT (see LICENSE)

local M = {
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

    -- Escrow rate, taken from the payout on acceptance (D47). Kept as an integer percentage so the
    -- whole calculation stays in integers: `floor((payout * 20 + 99) / 100)` never asks how a double
    -- rounds. Measured 2026-10-25: `ceil(payout * 0.2)` agrees with that for every payout up to
    -- 200 000, so this is a robustness choice rather than a repair — but it no longer depends on luck.
    escrow_percent = 20,
  },

  -- The solvency dial (D29, ADR 0015): the credit line a company is born with, drawn on the
  -- federation at creation. `poor` is a company that can only spend what it earns — and, in v1,
  -- what it earns is only what expired contracts forfeit to it, so its first contract is unpayable;
  -- that is the dial working as decided, not a bug. `rich` is the default because a fresh save must
  -- honour its first contract (A1). `unlimited` is the sandbox: I1/I2 are void, the mod says so on
  -- screen and in the log, and the number below is "no bound any game will reach" rather than a
  -- mathematical infinity, because every balance in the ledger is an integer (D7).
  solvency = {
    default = "rich",
    profiles = {
      poor = 0,
      rich = 100000,
      unlimited = 1000000000,
    },
  },

  contracts = {
    -- The payout a generated contract aims at, in credits (ADR 0047 §Defect 2). A contract asks for
    -- `round(target_payout / payout(item))` units, so cheap goods are asked by the hundred and dear
    -- ones by the handful. This number lives here and is read by `scripts/contracts.lua`; it is never
    -- written a second time in code. 2 500 reproduces the canonical first contract of
    -- docs/05-price-table.md §7: 208 iron plates, 208 x 12 = 2 496 credits.
    target_payout = 2500,

    -- The band the quantity is clamped to (ADR 0047 §Defect 2). The floor is **1**, not 30: a
    -- processing-unit contract is one unit that pays 1 975 with a 395 reserve — small in tonnage,
    -- large in money, and affordable from the first hour. The ceiling is 500, what one steel chest
    -- holds, so a contract can never exceed the counter's own inventory.
    min_quantity = 1,
    max_quantity = 500,

    -- Floor of the deadline, in seconds (ADR 0047: `max(4 min, production) + cycle`). It catches the
    -- cheap fast items only — copper cable, a processing unit — and never swallows the formula.
    min_deadline_seconds = 240,

    -- Machines assumed dedicated to a contract (ADR 0034 §4: `quantity x machine_seconds / 2`).
    machines = 2,

    -- Slack on the production leg (ADR 0047: `x 1.5`). A deadline that assumes two perfect machines
    -- and no belt is a deadline for a spreadsheet, not for a factory.
    production_slack = 1.5,

    -- How many contracts a company offers at once (F3: one to three). Three slots give the player the
    -- scheduling decision ADR 0043 asks for; the generator stops when the pool is empty.
    offer_slots = 3,
  },

  elevator = {
    -- The three animated phases of a round trip, in seconds (ADR 0043). Only `down` sends, so the
    -- whole cycle is the natural lower bound of a contract's deadline.
    rise_seconds = 8,
    away_seconds = 104,
    descend_seconds = 8,

    -- A full round trip of the elevator car, in seconds (ADR 0043). Added to every deadline: a
    -- contract whose goods cannot come back up in time is a contract that expires in the air. Kept
    -- as its own number because the deadline formula names it, and guarded against the three phases.
    cycle_seconds = 120,
  },
}

-- Load-time guards: numbers that do not add up fail here, once, instead of mid-game.
do
  local elevator = M.elevator
  local phases = elevator.rise_seconds + elevator.away_seconds + elevator.descend_seconds
  if phases ~= elevator.cycle_seconds then
    error(
      "[comptoir] config/balance: the elevator phases ("
        .. phases
        .. " s) do not sum to cycle_seconds ("
        .. elevator.cycle_seconds
        .. " s)"
    )
  end

  local contracts = M.contracts
  if contracts.min_quantity < 1 or contracts.max_quantity < contracts.min_quantity then
    error("[comptoir] config/balance: the quantity band is empty or inverted")
  end
  if contracts.machines < 1 or contracts.production_slack < 1 then
    error("[comptoir] config/balance: machines and production_slack must be at least 1")
  end
  if contracts.target_payout < 1 then
    error("[comptoir] config/balance: target_payout must be positive")
  end

  local solvency = M.solvency
  if solvency.profiles[solvency.default] == nil then
    error("[comptoir] config/balance: solvency.default \"" .. tostring(solvency.default) .. "\" is not a profile")
  end
  for name, line in pairs(solvency.profiles) do
    if type(line) ~= "number" or line % 1 ~= 0 or line < 0 then
      error("[comptoir] config/balance: solvency profile \"" .. name .. "\" must be a non-negative integer")
    end
  end
end

return M
