-- scripts/contracts.lua — the life of a contract, from an offer to a paid trip.
--
-- Description: builds the pool a company may ask from, draws one item from it with the company's own
--              random stream, derives the quantity, the payout, the escrow and the deadline from the
--              measured price table, and then owns the four transitions of a contract: `accept`
--              (escrow held), `dispatch` (goods leave in the car), `pay` (on the car's return) and
--              `expire` (deadline passed, escrow forfeited). One file for one object, as design.md §1
--              asks: generation and settlement share the same fields, so they share the same module.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: pool, weighted draw, payout band, deadline with the elevator cycle
--              2026-10-25 — a8: accept, dispatch, pay, expire and lazy settlement (ADR 0043)
--              2026-10-25 — ADR 0047: quantity floor 1 (was 30), deadline `max(4 min, qty x machine_s
--                           / 2 x 1.5) + cycle`, `target_payout` read from config/balance.lua only
-- Usages:      required by control.lua; called by the remote interface and by the settle pass
-- Notes:       THE POOL IS A GATE, NOT A NUANCE (A18, ADR 0034 §1): an item enters the pool only if
--              its recipe is enabled for the force AND its tier is within what the force can build. A
--              contract asking for a processing unit from a player without a refinery is not a hard
--              contract, it is a stolen escrow — the escrow was decided before the offer was drawn.
--              THE DEADLINE ALWAYS EXCEEDS THE CYCLE (A30, ADR 0047): `max(4 min, quantity x
--              machine_seconds / 2 x 1.5) + elevator_cycle`. The floor is a floor on the *production*
--              leg of one cheap item; the cycle is added on top of it, never absorbed into it.
--              PAYMENT WAITS FOR THE CAR (F7, ADR 0043). Dispatch removes the goods and moves nothing
--              else: the escrow stays held, the cooperative is untouched. The payout is credited by
--              the settle pass that sees the elevator come back down, and a contract that already
--              settled at that tick is never paid twice (`settled` plus the state machine).
--              LAZY, NEVER ON A CLOCK (design.md §3). Nothing here runs on tick: `settle` walks the
--              trips and the deadlines whenever something reads the economy — the interface, the
--              remote API, a dispatch. A save that is loaded after a week settles the moment it is
--              looked at, in one pass, with the same amounts.
--              IDEMPOTENT EXPIRY (A13). `expire` writes `state = "expired"` and `settled = true`
--              before anything can look again, so a second pass over the same contract finds a state
--              that is no longer `accepted` and does nothing at all.
--              A company that cannot pay is not silently forgiven: the payment is retried on the next
--              settle pass, once per contract, with one log line — the `poor` dial of ADR 0015 is
--              supposed to produce exactly that, and hiding it would make the dial look broken.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")
local catalogue = require("__comptoir-contracts__/config/companies")
local prices = require("__comptoir-contracts__/data/prices")
local companies = require("__comptoir-contracts__/scripts/companies")
local elevator = require("__comptoir-contracts__/scripts/elevator")
local ledger = require("__comptoir-contracts__/scripts/ledger")

local M = {}

M.API_VERSION = 1

-- v1 ships one kind of contract only (ADR 0019/0025): a fixed payout for a fixed quantity, once.
M.KIND = "fixed"

-- The five states a contract can be in. `offered` -> `accepted` -> `in_flight` -> `done`, or
-- `expired` from any of the first three (ADR 0043, ADR 0027).
M.OFFERED = "offered"
M.ACCEPTED = "accepted"
M.IN_FLIGHT = "in_flight"
M.DONE = "done"
M.EXPIRED = "expired"

local function is_integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function sorted_keys(table_)
  local keys = {}
  for key in pairs(table_) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
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

-- round(target_payout / payout(item)), clamped to [min_quantity, max_quantity] (ADR 0047 §Defect 2).
-- Integer arithmetic: the +payout/2 term is the "round half up" of a division that has no exact
-- double representation. The floor is 1 — a processing unit is one unit and 1 975 credits — and the
-- ceiling is 500, the counter's own inventory, so a contract always fits where it is delivered.
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

-- `max(4 min, quantity x machine_seconds / 2 x 1.5) + cycle`, in seconds (ADR 0047).
-- The slack is applied to the production leg only: the elevator's round trip is a fact, not an
-- estimate, so it is added as it is.
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
  local config = balance.contracts
  local production = quantity * machine_seconds / config.machines * config.production_slack
  return math.max(config.min_deadline_seconds, production) + balance.elevator.cycle_seconds
end

-- The absolute tick a contract dies at. Rounded up so that a fractional second never shortens a
-- deadline the player was promised.
function M.deadline_ticks(seconds, tick)
  return tick + math.ceil(seconds * 60)
end

-- How many contracts the company currently offers (state `offered`).
function M.count_offers(company)
  local count = 0
  for _, id in ipairs(sorted_keys(company.contracts)) do
    if company.contracts[id].state == M.OFFERED then
      count = count + 1
    end
  end
  return count
end

-- Draw one contract for `company` and store it on the company. The company's random state advances
-- here and nowhere else, so the same save proposes the same contracts forever (ADR 0034 §5).
-- The deadline is fixed at generation so the offer shows a real number, and re-based on acceptance
-- (`accept`), because the clock that matters is the one that starts when the escrow is held.
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

  local deadline_seconds = M.deadline_seconds(quantity, entry.seconds)

  local contract = {
    id = id,
    kind = M.KIND,
    item = item,
    quantity = quantity,
    payout = payout,
    reserve = M.reserve(payout),
    deadline_seconds = deadline_seconds,
    deadline_tick = M.deadline_ticks(deadline_seconds, tick),
    state = M.OFFERED,
    settled = false,
    offered_tick = tick,
  }

  company.contracts[id] = contract
  company.next_contract_id = id + 1
  return contract, nil
end

-- Fill the free slots of a company, up to `offer_slots` (F3). Returns how many were generated.
-- A slot that cannot be filled (empty pool) is not an error: a force that cannot craft anything the
-- catalogue knows simply has nothing to offer.
function M.refill(force, company, tick)
  local generated = 0
  local wanted = balance.contracts.offer_slots - M.count_offers(company)
  for _ = 1, wanted do
    local contract, reason = M.generate(force, company, tick)
    if contract == nil then
      if reason ~= "empty_pool" then
        error("[comptoir] contracts.refill: generation failed: " .. tostring(reason), 2)
      end
      break
    end
    generated = generated + 1
  end
  return generated
end

-- The hub a company works for: a company is born with exactly one counter (a6), so the lookup is a
-- walk over the sorted hub table and never a guess.
function M.hub_for_company(storage, force_index, company_id)
  for _, unit_number in ipairs(sorted_keys(storage.hubs or {})) do
    local hub = storage.hubs[unit_number]
    if hub.force_index == force_index and hub.company_id == company_id then
      return hub, unit_number
    end
  end
  return nil, nil
end

-- A contract already in the air for this hub, if any. One flight at a time (F6): the elevator state
-- enforces it, and this is the second lock, for the case where a save is edited.
local function flight_of(state, company)
  for _, id in ipairs(sorted_keys(company.contracts)) do
    local contract = company.contracts[id]
    if contract.state == M.IN_FLIGHT and contract.settled ~= true then
      return contract
    end
  end
  return nil
end

-- Accept an offer: the escrow is held against the cooperative's available credits (D47, ADR 0027) and
-- the deadline starts now. Nothing else moves — the player has promised, not paid.
-- Returns ok, reason, contract.
function M.accept(state, force, company, contract_id, tick)
  if state == nil or force == nil or company == nil then
    error("[comptoir] contracts.accept: state, force and company are required", 2)
  end
  local contract = company.contracts[contract_id]
  if contract == nil then
    return false, "unknown_contract", nil
  end
  if contract.state ~= M.OFFERED then
    return false, "not_offered", contract
  end

  local ok = pcall(ledger.hold, state, contract.reserve)
  if not ok then
    return false, "escrow_unavailable", contract
  end

  contract.state = M.ACCEPTED
  contract.accepted_tick = tick
  contract.deadline_tick = M.deadline_ticks(contract.deadline_seconds, tick)

  -- The slot refills immediately (ADR 0035: an offer is not a scarce resource, the choice is).
  M.refill(force, company, tick)
  ledger.assert_conservation(state, "accept " .. tostring(contract_id))
  return true, nil, contract
end

-- Dispatch an accepted contract: the goods leave the counter and enter the car. Nothing is paid here
-- (F7): the escrow stays held, the cooperative is untouched, the contract is `in_flight` until the
-- elevator is down again.
-- Returns ok, reason, contract.
function M.dispatch(state, storage, force_index, company, contract_id, tick)
  if state == nil or storage == nil or company == nil then
    error("[comptoir] contracts.dispatch: state, storage and company are required", 2)
  end
  local contract = company.contracts[contract_id]
  if contract == nil then
    return false, "unknown_contract", nil
  end
  if contract.state ~= M.ACCEPTED then
    return false, "not_accepted", contract
  end

  local hub, unit_number = M.hub_for_company(storage, force_index, company.id)
  if hub == nil then
    return false, "no_hub", contract
  end
  if elevator.can_send(hub) ~= true then
    return false, "elevator_" .. elevator.state_of(hub), contract
  end
  if flight_of(state, company) ~= nil then
    return false, "flight_in_progress", contract
  end

  local entity = companies.hub_entity(hub)
  if entity == nil then
    return false, "no_entity", contract
  end
  local inventory = entity.get_inventory(defines.inventory.chest)
  if inventory == nil then
    return false, "no_inventory", contract
  end
  local stock = inventory.get_item_count(contract.item)
  if stock < contract.quantity then
    return false, "not_enough_stock", contract
  end

  local removed = inventory.remove({ name = contract.item, count = contract.quantity })
  if removed ~= contract.quantity then
    -- Put back what was taken: a half-removal must not eat the player's goods.
    if removed > 0 then
      inventory.insert({ name = contract.item, count = removed })
    end
    return false, "stock_changed", contract
  end

  local sent = elevator.send(hub, tick)
  if not sent then
    inventory.insert({ name = contract.item, count = contract.quantity })
    return false, "elevator_" .. elevator.state_of(hub), contract
  end

  contract.state = M.IN_FLIGHT
  contract.dispatched_tick = tick
  contract.return_tick = hub.elevator.return_tick
  return true, nil, contract
end

-- The car is back: the company pays the payout to the cooperative and the escrow is released. Called
-- once per trip by `settle`; `contract.settled` is the belt to the state machine's braces.
-- Returns true when the money moved.
function M.pay(state, company, contract, tick)
  if contract.settled == true then
    return false
  end
  local ok = pcall(ledger.transfer, state, ledger.company(company.id), ledger.COOPERATIVE, contract.payout)
  if not ok then
    -- The `poor` dial: a company without a line cannot pay. Retried on the next pass, logged once.
    if contract.payment_failed ~= true then
      contract.payment_failed = true
      log(
        "[comptoir] contracts.pay: company " .. company.id .. " cannot pay " .. contract.payout
          .. " credits for contract " .. contract.id .. " — the solvency dial is \"poor\"?"
      )
    end
    return false
  end
  ledger.release(state, contract.reserve)
  contract.state = M.DONE
  contract.settled = true
  contract.settled_tick = tick
  contract.payment_failed = nil
  contract.paid_payout = contract.payout
  return true
end

-- The deadline passed: the escrow becomes real money for the company that offered the contract
-- (A13, ADR 0027). Applies to `accepted` and `in_flight` (an expiry in the air still forfeits, ADR
-- 0043): the goods are lost with the car, the money is the company's.
-- Idempotent: a contract that already expired is not `accepted`/`in_flight` any more.
-- Returns true when money moved.
function M.expire(state, company, contract, tick)
  if contract.settled == true then
    return false
  end
  if contract.state ~= M.ACCEPTED and contract.state ~= M.IN_FLIGHT then
    return false
  end
  if tick <= contract.deadline_tick then
    return false
  end
  ledger.forfeit(state, contract.reserve, company.id)
  contract.state = M.EXPIRED
  contract.settled = true
  contract.settled_tick = tick
  return true
end

-- One lazy pass over everything that is due on a force: the trips that came back, the deadlines that
-- passed, and the slots that need a new offer. Returns a report, never nil.
--
-- `force` is the LuaForce (the pool needs its recipes); `storage` is the whole mod storage; `tick` is
-- the tick of the read that triggered the pass.
function M.settle(storage, force, tick)
  local report = { paid = 0, expired = 0, generated = 0, hubs = 0, contracts = 0 }
  if storage == nil or force == nil or storage.forces == nil then
    return report
  end
  local force_index = force.index
  local state = storage.forces[force_index]
  if state == nil then
    return report
  end

  for _, unit_number in ipairs(sorted_keys(storage.hubs or {})) do
    local hub = storage.hubs[unit_number]
    if hub.force_index == force_index then
      report.hubs = report.hubs + 1
      local arrived = elevator.advance(hub, tick)
      local company = state.companies[hub.company_id]
      if company ~= nil then
        for _, id in ipairs(sorted_keys(company.contracts)) do
          local contract = company.contracts[id]
          report.contracts = report.contracts + 1
          if arrived and contract.state == M.IN_FLIGHT then
            if M.pay(state, company, contract, tick) then
              report.paid = report.paid + 1
            end
          end
          if M.expire(state, company, contract, tick) then
            report.expired = report.expired + 1
          end
        end
        report.generated = report.generated + M.refill(force, company, tick)
      end
    end
  end

  ledger.assert_conservation(state, "settle force " .. tostring(force_index) .. " at tick " .. tick)
  return report
end

return M
