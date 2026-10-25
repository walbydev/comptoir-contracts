-- scripts/companies.lua — a company is born, named and given a character.
--
-- Description: creates one company per counter, once, and owns everything that makes it an entity:
--              its name, its character (type plus weights), its commercial tier read from the price
--              table, and its own random stream. It never touches a balance — `scripts/ledger.lua`
--              owns the money (design.md §1).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: creation on build, name, character, tier, Park-Miller LCG
-- Usages:      required by control.lua; called by scripts/contracts.lua (pool, draw) and by the
--              snapshot of the remote interface
-- Notes:       RANDOMNESS. `math.random` desynchronises a multiplayer game and `game.
--              create_random_generator` was never measured on 2.1.23, so the mod carries its own
--              generator: the "minimal standard" linear congruential generator, state = state *
--              16807 mod (2^31 - 1), seeded once per company and stored in `storage`.
--              Why not design.md §4's `state * 1103515245 + 12345 mod 2^31`: that product reaches
--              2.4e18, past the 2^53 a Lua 5.2 number can hold exactly, so the low bits — the only
--              ones left after a modulo — would be noise. Park-Miller's product peaks at
--              2147483646 * 16807 = 3.6e13 and every step is exact.
--              A company's name and character are drawn once, at creation, and then frozen in
--              `storage`: a reload reproduces them because nothing ever recomputes them.
--              Every iteration that writes state walks a sorted key list (design.md §4): Lua's table
--              order is not guaranteed, and that is how a mod desynchronises without `math.random`.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")
local catalogue = require("__comptoir-contracts__/config/companies")
local prices = require("__comptoir-contracts__/data/prices")
local ledger = require("__comptoir-contracts__/scripts/ledger")

local M = {}

M.API_VERSION = 1

-- Park-Miller: 2^31 - 1 is prime, 16807 is a primitive root of it, and the state never leaves
-- [1, 2^31 - 2].
M.LCG_MODULUS = 2147483647
M.LCG_MULTIPLIER = 16807

M.NAME_ATTEMPTS = catalogue.name_attempts

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

-- One step of the generator. The modulus is prime and greater than the multiplier, so a state in
-- [1, m - 1] always maps to another state in [1, m - 1]: zero is unreachable and is not special-cased.
function M.lcg_next(state)
  if not is_integer(state) or state < 1 or state > M.LCG_MODULUS - 1 then
    error(
      "[comptoir] companies.lcg_next: state must be an integer in [1, " .. (M.LCG_MODULUS - 1) .. "], got "
        .. tostring(state),
      2
    )
  end
  return (state * M.LCG_MULTIPLIER) % M.LCG_MODULUS
end

-- One draw in [1, n], returned with the advanced state.
function M.lcg_index(state, n)
  if not is_integer(n) or n < 1 then
    error("[comptoir] companies.lcg_index: n must be a positive integer, got " .. tostring(n), 2)
  end
  local advanced = M.lcg_next(state)
  return advanced, math.floor(advanced * n / M.LCG_MODULUS) + 1
end

-- A weighted pick over `keys` (an array, already sorted by the caller) with `weights[key]`.
-- Returns the advanced state and the chosen key.
function M.lcg_pick(state, keys, weights)
  if #keys == 0 then
    error("[comptoir] companies.lcg_pick: no candidate", 2)
  end
  local total = 0
  for index = 1, #keys do
    local weight = weights[keys[index]] or 1
    if not is_integer(weight) or weight < 0 then
      error("[comptoir] companies.lcg_pick: weight of " .. tostring(keys[index]) .. " must be a non-negative integer", 2)
    end
    total = total + weight
  end
  if total <= 0 then
    error("[comptoir] companies.lcg_pick: every candidate has weight zero", 2)
  end

  local advanced, draw = M.lcg_index(state, total)
  local cursor = 0
  for index = 1, #keys do
    cursor = cursor + (weights[keys[index]] or 1)
    if draw <= cursor then
      return advanced, keys[index]
    end
  end
  error("[comptoir] companies.lcg_pick: draw " .. draw .. " fell outside the weight range", 2)
end

-- The seed of a company. The three inputs are reduced before multiplying so every intermediate value
-- stays an exact integer: tick can be large, and `tick * 2654435761` would otherwise lose its low bits.
function M.seed(force_index, unit_number, tick)
  local function part(name, value)
    if not is_integer(value) or value < 0 then
      error("[comptoir] companies.seed: " .. name .. " must be a non-negative integer, got " .. tostring(value), 3)
    end
    return value % 100003
  end
  local mixed = part("tick", tick) * 2654435761 + part("unit_number", unit_number) * 40503
    + part("force_index", force_index) * 7919
  return mixed % (M.LCG_MODULUS - 1) + 1
end

-- The character: one dominant group, one second, and a weight vector over all of them (ADR 0022).
-- Returns the advanced state, the type (the dominant group) and the weights.
function M.character(state)
  local groups = catalogue.groups
  local after_primary, primary_index = M.lcg_index(state, #groups)
  local primary = groups[primary_index]

  local others = {}
  for index = 1, #groups do
    if groups[index] ~= primary then
      others[#others + 1] = groups[index]
    end
  end
  local after_secondary, secondary_index = M.lcg_index(after_primary, #others)
  local secondary = others[secondary_index]

  local weights = {}
  for index = 1, #groups do
    local group = groups[index]
    if group == primary then
      weights[group] = catalogue.weights.primary
    elseif group == secondary then
      weights[group] = catalogue.weights.secondary
    else
      weights[group] = catalogue.weights.other
    end
  end
  return after_secondary, primary, weights
end

-- A name that no company of the force already holds. `taken` is a set of names.
-- Returns the advanced state, the name (nil when every attempt drew a duplicate) and the last
-- candidate drawn, so the caller can still build a unique name.
function M.name(state, taken)
  local first_names = catalogue.first_names
  local last_names = catalogue.last_names
  local candidate = nil
  for _ = 1, M.NAME_ATTEMPTS do
    local after_first, first_index = M.lcg_index(state, #first_names)
    local after_last, last_index = M.lcg_index(after_first, #last_names)
    candidate = first_names[first_index] .. " " .. last_names[last_index]
    if taken[candidate] == nil then
      return after_last, candidate, candidate
    end
    state = after_last
  end
  return state, nil, candidate
end

-- Whether the force may currently build `item`: its recipe exists and is enabled. This is the only
-- gate that matters (A18, ADR 0034 §1) — an item the player cannot craft is a stolen escrow.
function M.is_unlocked(force, item)
  local recipe = force.recipes[item]
  if recipe == nil then
    return false
  end
  return recipe.enabled == true
end

-- The commercial tier of a force: the deepest tier it can actually build. Tiers come from the price
-- table (oil-chain depth, measured), never from the technology tree (ADR 0034 §2).
function M.unlocked_tier(force)
  local tier = 1
  local names = sorted_keys(prices.items)
  for _, item in ipairs(names) do
    local entry = prices.items[item]
    if entry.tier > tier and M.is_unlocked(force, item) then
      tier = entry.tier
    end
  end
  return tier
end

-- The economy record of a force, created on first use with the endowment (D28).
function M.force_state(storage, force_index)
  if storage.forces == nil then
    error("[comptoir] companies.force_state: storage has no `forces` table — was storage.version migrated?", 2)
  end
  local state = storage.forces[force_index]
  if state == nil then
    state = ledger.new_force(balance.economy.endowment)
    storage.forces[force_index] = state
    log(
      "[comptoir] economy created for force " .. force_index .. ": endowment " .. balance.economy.endowment
        .. " credits issued to the cooperative, federation at " .. state.federation
    )
  end
  return state
end

function M.company_for_hub(storage, unit_number)
  local hub = storage.hubs[unit_number]
  if hub == nil then
    return nil
  end
  local state = storage.forces[hub.force_index]
  if state == nil then
    error("[comptoir] companies.company_for_hub: hub " .. unit_number .. " points at force " .. hub.force_index
      .. ", which has no economy", 2)
  end
  return state.companies[hub.company_id]
end

-- The company of a counter, created if this counter has none yet. Idempotent: raising the build
-- event twice for the same entity returns the same company and creates nothing (a6's exit check).
function M.create_for_hub(storage, force, entity, tick)
  if entity == nil or entity.valid == false then
    error("[comptoir] companies.create_for_hub: no valid entity", 2)
  end
  if entity.name ~= "comptoir-counter" then
    error("[comptoir] companies.create_for_hub: " .. tostring(entity.name) .. " is not a counter", 2)
  end
  local unit_number = entity.unit_number
  if not is_integer(unit_number) then
    error("[comptoir] companies.create_for_hub: entity has no unit number", 2)
  end
  if storage.hubs == nil then
    error("[comptoir] companies.create_for_hub: storage has no `hubs` table — was storage.version migrated?", 2)
  end

  local existing = M.company_for_hub(storage, unit_number)
  if existing ~= nil then
    return existing, false
  end

  local state = M.force_state(storage, force.index)
  local id = state.next_company_id
  if not is_integer(id) or id < 1 then
    error("[comptoir] companies.create_for_hub: next_company_id is not a positive integer", 2)
  end

  local taken = {}
  for _, other_id in ipairs(sorted_keys(state.companies)) do
    taken[state.companies[other_id].name] = true
  end

  local state_after_character, character_type, weights = M.character(M.seed(force.index, unit_number, tick))
  local state_after_name, name, last_candidate = M.name(state_after_character, taken)
  if name == nil then
    -- 40 duplicate draws over 100 combinations: the force holds a lot of counters. The suffix keeps the
    -- name unique without ever reusing one, and stays deterministic.
    name = last_candidate .. " #" .. id
  end

  local company = {
    id = id,
    name = name,
    type = character_type,
    tier = M.unlocked_tier(force),
    balance = 0,
    rng = state_after_name,
    weights = weights,
    contracts = {},
    next_contract_id = 1,
    created_tick = tick,
  }

  ledger.register_company(state, company)
  state.next_company_id = id + 1
  storage.hubs[unit_number] = { force_index = force.index, company_id = id }
  ledger.assert_conservation(state, "create_for_hub " .. unit_number)

  log(
    "[comptoir] company " .. id .. " " .. name .. " (" .. character_type .. ", tier " .. company.tier
      .. ") created for counter " .. unit_number .. " on force " .. force.index .. " at tick " .. tick
  )
  return company, true
end

-- Read-only view for the remote interface (design.md §5): plain numbers and strings only, so the
-- caller cannot hold a reference into `storage` and mutate the economy from outside.
function M.snapshot(storage, force_index)
  local out = {
    api_version = M.API_VERSION,
    storage_version = storage.version,
    force_index = force_index,
    exists = false,
    endowment = balance.economy.endowment,
    cooperative = 0,
    federation = 0,
    reserved = 0,
    available = 0,
    total = 0,
    supply = 0,
    companies = {},
    hubs = {},
  }

  local state = storage.forces and storage.forces[force_index]
  if state ~= nil then
    ledger.assert_conservation(state, "snapshot force " .. tostring(force_index))
    out.exists = true
    out.cooperative = state.cooperative
    out.federation = state.federation
    out.reserved = state.reserved
    out.available = ledger.available(state)
    out.total = ledger.total(state)
    out.supply = state.supply

    for _, id in ipairs(sorted_keys(state.companies)) do
      local company = state.companies[id]
      local contracts = {}
      for _, contract_id in ipairs(sorted_keys(company.contracts)) do
        local contract = company.contracts[contract_id]
        contracts[#contracts + 1] = {
          id = contract_id,
          kind = contract.kind,
          item = contract.item,
          quantity = contract.quantity,
          payout = contract.payout,
          reserve = contract.reserve,
          deadline_tick = contract.deadline_tick,
          state = contract.state,
          settled = contract.settled,
        }
      end
      local weights = {}
      for _, group in ipairs(sorted_keys(company.weights)) do
        weights[group] = company.weights[group]
      end
      out.companies[#out.companies + 1] = {
        id = company.id,
        name = company.name,
        type = company.type,
        tier = company.tier,
        balance = company.balance,
        rng = company.rng,
        contract_count = #contracts,
        contracts = contracts,
        weights = weights,
      }
    end
  end

  for _, unit_number in ipairs(sorted_keys(storage.hubs or {})) do
    local hub = storage.hubs[unit_number]
    out.hubs[#out.hubs + 1] = {
      unit_number = unit_number,
      force_index = hub.force_index,
      company_id = hub.company_id,
    }
  end

  return out
end

return M
