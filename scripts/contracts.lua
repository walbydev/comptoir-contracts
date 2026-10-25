-- scripts/contracts.lua — generation of the contracts a counter offers.
--
-- Description: builds the pool a company may ask from, draws one item from it with the company's own
--              random stream, and derives the quantity, the payout, the escrow and the deadline from
--              the measured price table. Generation only: accept, dispatch, pay and expire belong to
--              the next task (a8) and share this file (design.md §1).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: pool, weighted draw, payout band, deadline with the elevator cycle
-- Usages:      required by control.lua; called by whatever fills a free slot
-- Notes:       THE POOL IS A GATE, NOT A NUANCE (A18, ADR 0034 §1): an item enters the pool only if
--              its recipe is enabled for the force AND its tier is within what the force can build. A
--              contract asking for a processing unit from a player without a refinery is not a hard
--              contract, it is a stolen escrow — the escrow was decided before the offer was drawn.
--              THE DEADLINE ALWAYS EXCEEDS THE CYCLE (A30, D58): `max(10 min, quantity x machine_seconds
--              / 2) + elevator_cycle`. The floor of 10 minutes is a floor on the *production* leg; the
--              cycle is added on top of it, never absorbed into it. Quantity, machine seconds and
--              cycle all come from data, so a recipe change moves the deadline with it.
--              INTEGERS ONLY (D7): the quantity, the payout, the escrow and the deadline in ticks are
--              all integers. The rounding is done with integer arithmetic — `quantity * 20 / 100`
--              rather than `quantity * 0.2` — so no step depends on how a double rounds. Measured
--              2026-10-25: the two agree for every payout up to 200 000, so the integer form is a
--              robustness choice, not a repair of an observed error.
--              The quantity is clamped to [30, 500] (ADR 0034 §4): below 30 units a trip is not worth
--              the escrow, above 500 the goods no longer fit in the counter's one chest.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")
local catalogue = require("__comptoir-contracts__/config/companies")
local prices = require("__comptoir-contracts__/data/prices")
local companies = require("__comptoir-contracts__/scripts/companies")

local M = {}

M.API_VERSION = 1

-- v1 ships one kind of contract only (ADR 0019/0025): a fixed payout for a fixed quantity, once.
M.KIND = "fixed"

local function is_integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

-- The catalogue, sorted: every draw must walk the same order on every client (design.md §4).
function M.catalogue_items()
  local names = {}
  for name in pairs(prices.items) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

-- The items a company of this force may ask for: in the catalogue, unlocked by research, within the
-- force's tier. Returned as an array kept in catalogue order.
function M.pool(force, tier)
  if not is_integer(tier) or tier < 1 then
    error("[comptoir] contracts.pool: tier must be a positive integer, got " .. tostring(tier), 2)
  end
  local pool = {}
  for _, item in ipairs(M.catalogue_items()) do
    local entry = prices.items[item]
    if entry.tier <= tier and companies.is_unlocked(force, item) then
      pool[#pool + 1] = item
    end
  end
  return pool
end

-- round(target_payout / payout(item)), clamped to the band. Integer arithmetic: the +payout/2 term is
-- the "round half up" of a division that has no exact double representation.
function M.quantity(payout)
  if not is_integer(payout) or payout < 1 then
    error("[comptoir] contracts.quantity: payout must be a positive integer, got " .. tostring(payout), 2)
  end
  local config = balance.contracts
  local quantity = math.floor((2 * config.target_payout + payout) / (2 * payout))
  if quantity < config.min_quantity then
    quantity = config.min_quantity
  elseif quantity > config.max_quantity then
    quantity = config.max_quantity
  end
  return quantity
end

-- The escrow of a contract: `ceil(payout x rate)`, with the rate held as a percentage so the product
-- stays exact.
function M.reserve(payout)
  if not is_integer(payout) or payout < 0 then
    error("[comptoir] contracts.reserve: payout must be a non-negative integer, got " .. tostring(payout), 2)
  end
  local percent = balance.economy.escrow_percent
  return math.floor((payout * percent + 99) / 100)
end

-- `max(10 min, quantity x machine_seconds / 2) + cycle`, in seconds. A30 asserts the result is at
-- least the cycle; with the 10-minute floor it always is, and the test proves it over 1 000 draws.
function M.deadline_seconds(quantity, machine_seconds)
  if not is_integer(quantity) or quantity < 1 then
    error("[comptoir] contracts.deadline_seconds: quantity must be a positive integer, got " .. tostring(quantity), 2)
  end
  if type(machine_seconds) ~= "number" or machine_seconds <= 0 then
    error(
      "[comptoir] contracts.deadline_seconds: machine_seconds must be a positive number, got " .. tostring(machine_seconds),
      2
    )
  end
  local production = quantity * machine_seconds / balance.contracts.machines
  return math.max(balance.contracts.min_deadline_seconds, production) + balance.elevator.cycle_seconds
end

-- The absolute tick a contract dies at. Rounded up so that a fractional second never shortens a
-- deadline the player was promised.
function M.deadline_ticks(seconds, tick)
  return tick + math.ceil(seconds * 60)
end

-- Draw one contract for `company` and store it on the company. The company's random state advances
-- here and nowhere else, so the same save proposes the same contracts forever (ADR 0034 §5).
-- Returns the contract, or nil and a reason when there is nothing to offer.
function M.generate(force, company, tick)
  if force == nil or company == nil then
    error("[comptoir] contracts.generate: force and company are required", 2)
  end
  if not is_integer(tick) or tick < 0 then
    error("[comptoir] contracts.generate: tick must be a non-negative integer, got " .. tostring(tick), 2)
  end

  local pool = M.pool(force, company.tier)
  if #pool == 0 then
    return nil, "empty_pool"
  end

  local weights = {}
  for _, item in ipairs(pool) do
    local group = catalogue.items[item]
    weights[item] = company.weights[group]
  end

  local rng, item = companies.lcg_pick(company.rng, pool, weights)
  company.rng = rng

  local entry = prices.items[item]
  local quantity = M.quantity(entry.payout)
  local payout = quantity * entry.payout
  local id = company.next_contract_id
  if not is_integer(id) or id < 1 then
    error("[comptoir] contracts.generate: next_contract_id is not a positive integer", 2)
  end

  local contract = {
    id = id,
    kind = M.KIND,
    item = item,
    quantity = quantity,
    payout = payout,
    reserve = M.reserve(payout),
    deadline_tick = M.deadline_ticks(M.deadline_seconds(quantity, entry.seconds), tick),
    state = "offered",
    settled = false,
    offered_tick = tick,
  }

  company.contracts[id] = contract
  company.next_contract_id = id + 1
  return contract, nil
end

return M
