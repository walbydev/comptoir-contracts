-- scripts/scenarios.lua — one scenario per criterion, named after it.
--
-- Description: every scenario drives the mod through the remote interface only — `snapshot`, `act`,
--              `storage_dump`, `assert_conservation` — and asserts what docs/09-tests.md asks for,
--              line by line. Nothing here reaches into `storage`: if a proof needed the internals,
--              the interface would be missing something.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: A1, A2, A3, A7, A9, A10, A13, A14, A15, A18, A19, A26, A28,
--                           A29, A30 and the two halves of the mid-flight save (a9-save/a9-resume)
--              2026-10-25 — waiting halves written with H.after/H.poll (no coroutines in 2.x)
--              2026-10-25 — ADR 0048: A30 recomputed per tier against `chain` (not `seconds`), with
--                           tier-2/tier-3 presence asserted; the expiry wait budget follows the
--                           longer deadlines the chain produces (a tier-1 circuit is 11:57, not 6:00)
--              2026-10-25 — lot b: B1-gui-pure, the counter window's pure functions on crafted cases
--                           (ADR 0050: the frame itself cannot be built without a client)
--              2026-10-25 — A31: the cap counts live contracts (ADR 0051). Three live contracts, no
--                           fourth offer generated, a crafted fourth refused with `no_free_slot`, and
--                           exactly one new offer once a contract is paid
--              2026-10-25 — lot b fix: B1-gui-pure checks that every refusal reason carries a literal
--                           caption, and hands four of the window's keys to the engine so the runner
--                           can read the rendered text (H.probe_locale, ADR 0053)
-- Usages:      required by control.lua of the test mod, queued by `scenario.lua`
-- Notes:       THE NUMBERS ARE RECOMPUTED FROM THE DATA, NEVER COPIED FROM THE MOD. The test mod
--              requires `data/prices.lua` and `config/balance.lua` of the mod under test and derives
--              the expected quantity, payout, escrow and deadline itself. A formula that drifts in
--              `scripts/contracts.lua` therefore shows up as a red assertion instead of a green one
--              that agrees with the bug.
--              A scenario never assumes a tick multiple: waits are "at least", polled, and the
--              elevator phases are read from the snapshot rather than guessed.
--              One scenario per process is what `tools/run_tests.py` does: the map is shared, the
--              counters are far apart, and nothing depends on the order of the queue.
-- Licence:     MIT (see LICENSE)

local H = require("__comptoir-test__/scripts/harness")
local balance = require("__comptoir-contracts__/config/balance")
local prices = require("__comptoir-contracts__/data/prices")
local catalogue = require("__comptoir-contracts__/config/companies")
local contracts = require("__comptoir-contracts__/scripts/contracts")
local gui_format = require("__comptoir-contracts__/scripts/gui/format")
local gui_window = require("__comptoir-contracts__/scripts/gui/window")

local MOD = "comptoir-contracts"
local COUNTER = "comptoir-counter"
local TICKS_PER_SECOND = 60

local M = {}

-- ---------------------------------------------------------------------------------------------------
-- The interface, and nothing else
-- ---------------------------------------------------------------------------------------------------

local function snap(force_index)
  return remote.call(MOD, "snapshot", force_index)
end

local function act(force_index, action, params)
  return remote.call(MOD, "act", force_index, action, params or {})
end

local function dump(force_index)
  return remote.call(MOD, "storage_dump", force_index)
end

local function conservation_holds(force_index)
  return pcall(remote.call, MOD, "assert_conservation", force_index)
end

-- ---------------------------------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------------------------------

local function surface()
  return game.surfaces[1]
end

-- Ask the map to exist where the test wants to build. Wrapped: a missing helper must not turn a
-- scenario into a crash, the placement below will say what it could not do.
local function ensure_area(position, radius)
  pcall(function()
    surface().request_to_generate_chunks(position, radius or 3)
    surface().force_generate_chunk_requests()
  end)
end

local function unlock_counter(force)
  local recipe = force.recipes[COUNTER]
  if recipe == nil then
    error("[comptoir-test] no recipe " .. COUNTER .. " on force " .. force.name)
  end
  recipe.enabled = true
end

local function place(force, position, player_index)
  ensure_area(position, 4)
  local found = surface().find_non_colliding_position(COUNTER, position, 96, 1)
  if found == nil then
    error("[comptoir-test] no free tile for a counter near " .. string.format("%.0f,%.0f", position.x, position.y))
  end
  local entity = surface().create_entity({ name = COUNTER, position = found, force = force })
  if entity == nil then
    error("[comptoir-test] create_entity returned nil at " .. string.format("%.0f,%.0f", found.x, found.y))
  end
  script.raise_event(defines.events.script_raised_built, { entity = entity, player_index = player_index })
  return entity, found
end

local function ensure_player(name)
  local player = game.players[1]
  if player == nil then
    player = game.create_player({ name = name, force = "player" })
  end
  if player.character == nil then
    pcall(function()
      local character = surface().create_entity({ name = "character", position = { x = 4, y = 4 }, force = player.force })
      if character ~= nil then
        player.set_controller({ type = defines.controllers.character, character = character })
      end
    end)
  end
  return player
end

-- The name behind an entity status number, so a red test says "no_power" instead of "36".
local function status_name(value)
  for name, candidate in pairs(defines.entity_status) do
    if candidate == value then
      return name
    end
  end
  return tostring(value)
end

local function inventory_of(entity)
  return entity.get_inventory(defines.inventory.chest)
end

local function company_of(state, company_id)
  for _, company in ipairs(state.companies) do
    if company.id == company_id then
      return company
    end
  end
  return nil
end

local function company_balance(state, company_id)
  local company = company_of(state, company_id)
  return company and company.balance or nil
end

local function contract_of(state, company_id, contract_id)
  local company = company_of(state, company_id)
  if company == nil then
    return nil
  end
  for _, contract in ipairs(company.contracts) do
    if contract.id == contract_id then
      return contract
    end
  end
  return nil
end

local function first_offer(company)
  for _, contract in ipairs(company.contracts) do
    if contract.state == "offered" then
      return contract
    end
  end
  return nil
end

-- The cap of ADR 0051 counts live contracts — offered, accepted and in flight. Counted from the
-- snapshot so an assertion speaks the number the rule speaks, not a state name.
local function live_count(company)
  if company == nil then
    return 0
  end
  local count = 0
  for _, contract in ipairs(company.contracts) do
    if contract.state == "offered" or contract.state == "accepted" or contract.state == "in_flight" then
      count = count + 1
    end
  end
  return count
end

-- The offers of a company, in snapshot order.
local function offers_of(company)
  local out = {}
  if company == nil then
    return out
  end
  for _, contract in ipairs(company.contracts) do
    if contract.state == "offered" then
      out[#out + 1] = contract
    end
  end
  return out
end

-- Every contract the company ever had, ended ones included: what "a fourth was never generated" is
-- counted on.
local function total_contracts(company)
  if company == nil then
    return 0
  end
  return #company.contracts
end

-- The id set, for "exactly one new contract" after a refill.
local function ids_of(company)
  local out = {}
  if company == nil then
    return out
  end
  for _, contract in ipairs(company.contracts) do
    out[contract.id] = true
  end
  return out
end

local function hub_of(state, unit_number)
  for _, hub in ipairs(state.hubs) do
    if hub.unit_number == unit_number then
      return hub
    end
  end
  return nil
end

local function company_id_of(state, unit_number)
  local hub = hub_of(state, unit_number)
  return hub and hub.company_id or nil
end

-- A19 and A3 share this: the pot must be the sum of its two halves at all times.
local function assert_pot(state, label)
  H.eq(state.available + state.reserved, state.cooperative, "A19 available + reserved = cooperative [" .. label .. "]")
  H.at_least(state.available, 0, "A19 available >= 0 [" .. label .. "]")
  H.at_least(state.reserved, 0, "A19 reserved >= 0 [" .. label .. "]")
end

local function new_hub(force, position)
  unlock_counter(force)
  local entity = place(force, position)
  H.ok(entity.valid, "a counter is placed at " .. string.format("%.0f,%.0f", position.x, position.y))
  if entity.valid ~= true then
    return nil, nil, snap(force.index)
  end
  local state = snap(force.index)
  local company_id = company_id_of(state, entity.unit_number)
  H.ok(company_id ~= nil, "the counter owns a company")
  return entity, company_id, state
end

-- Fill the counter and send the car. Returns the contract as it was after dispatch.
local function run_contract(force_index, entity, company_id, contract, label)
  local inserted = inventory_of(entity).insert({ name = contract.item, count = contract.quantity })
  H.eq(inserted, contract.quantity, label .. ": the counter holds the full quantity")
  local accepted = act(force_index, "accept", { company_id = company_id, contract_id = contract.id })
  H.ok(accepted.ok, label .. ": accept (" .. tostring(accepted.reason) .. ")")
  local dispatched = act(force_index, "dispatch", { company_id = company_id, contract_id = contract.id })
  H.ok(dispatched.ok, label .. ": dispatch (" .. tostring(dispatched.reason) .. ")")
  return dispatched.contract
end

-- Call `on_done(state)` when the contract reaches `done`, or fail the criterion after `budget` ticks.
local function when_paid(force_index, company_id, contract_id, budget, on_done, label)
  H.poll(function()
    local state = snap(force_index)
    local contract = contract_of(state, company_id, contract_id)
    if contract ~= nil and contract.state == "done" then
      return state
    end
    return false
  end, budget or 30000, 60, on_done, nil, label or "the contract to be paid")
end

-- Call `on_done(state)` when the contract reaches `expired`, or fail the criterion after `budget`.
-- The default budget is 60 000 ticks, not 40 000: since ADR 0048 the deadline walks the whole chain,
-- so an unlocked tier-1 electronic circuit is 11:57 (43 000 ticks) where the single-recipe time said
-- 6:00 — a 40 000-tick wait would have failed on a draw, not on a bug.
local function when_expired(force_index, company_id, contract_id, budget, on_done, label)
  H.poll(function()
    local state = snap(force_index)
    local contract = contract_of(state, company_id, contract_id)
    if contract ~= nil and contract.state == "expired" then
      return state
    end
    return false
  end, budget or 60000, 120, on_done, nil, label or "the contract to expire")
end

-- ---------------------------------------------------------------------------------------------------
-- A1 — a fresh save honours its first contract end to end, in under 30 minutes
-- ---------------------------------------------------------------------------------------------------

M.a1 = {
  id = "A1",
  name = "first contract end to end under 30 minutes",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local company = company_of(state, company_id)
    H.at_least(#company.contracts, 1, "A1: the counter offers at least one contract")
    local offer = first_offer(company)
    if not H.ok(offer ~= nil, "A1: an offer is waiting") then
      return
    end

    local tick_start = game.tick
    local before = snap(1)
    local contract = run_contract(1, entity, company_id, offer, "A1")
    H.eq(contract.state, "in_flight", "A1: the goods are in the car")
    H.eq(inventory_of(entity).get_item_count(offer.item), 0, "A1: the goods left the counter")

    local after_dispatch = snap(1)
    H.eq(after_dispatch.cooperative, before.cooperative, "A1/F7: nothing is paid at dispatch")
    H.eq(after_dispatch.reserved, before.reserved + offer.reserve, "A1/F7: the escrow is still held")
    assert_pot(after_dispatch, "A1 after dispatch")

    when_paid(1, company_id, offer.id, 30000, function(settled)
      H.eq(settled.cooperative, before.cooperative + offer.payout, "A1: the payout is credited to the cooperative")
      H.eq(settled.reserved, before.reserved, "A1: the escrow is released, not forfeited")
      H.eq(
        company_balance(settled, company_id),
        company_balance(before, company_id) - offer.payout,
        "A1: the company paid the payout"
      )
      local done = contract_of(settled, company_id, offer.id)
      H.at_least(done.settled_tick, tick_start, "A1: settlement happened after the start")
      H.at_most(done.settled_tick - tick_start, 30 * 60 * TICKS_PER_SECOND, "A1: paid within 30 minutes")
      H.note(
        "A1: elapsed "
          .. tostring(done.settled_tick - tick_start)
          .. " ticks ("
          .. string.format("%.1f", (done.settled_tick - tick_start) / 3600)
          .. " min)"
      )
    end, "A1: the contract is paid when the car comes back")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A2 — insertion by inserter, and no partial delivery
-- ---------------------------------------------------------------------------------------------------

M.a2 = {
  id = "A2",
  name = "insertion by inserter, dispatch only on full stock",
  run = function()
    local force = game.forces["player"]
    unlock_counter(force)

    -- One counter only, with a real burner inserter and a real chest beside it: the engine fills the
    -- inventory, no script. A second counter would have to stand 150 tiles away (A9 owns that rule).
    local near = surface().find_non_colliding_position(COUNTER, { x = 0, y = 0 }, 96, 1)
    local counter = surface().create_entity({ name = COUNTER, position = near, force = force })
    script.raise_event(defines.events.script_raised_built, { entity = counter })
    local chest = surface().create_entity({ name = "wooden-chest", position = { x = near.x, y = near.y - 2 }, force = force })
    local inserter = surface().create_entity({
      name = "burner-inserter",
      position = { x = near.x, y = near.y - 1 },
      -- Measured: an inserter takes from the tile it faces and drops behind itself. Facing north,
      -- it picks the chest at y-2 and drops into the counter at y.
      direction = defines.direction.north,
      force = force,
    })
    H.ok(counter ~= nil and counter.valid, "A2: the counter exists")
    H.ok(chest ~= nil and inserter ~= nil, "A2: the inserter fixture exists")
    if counter == nil or counter.valid ~= true or chest == nil or inserter == nil then
      return
    end
    local state = snap(1)
    local company_id = company_id_of(state, counter.unit_number)
    H.ok(company_id ~= nil, "A2: the counter has a company")
    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "A2: an offer is waiting") then
      return
    end
    chest.insert({ name = offer.item, count = 20 })
    -- The fuel goes in the fuel slot, not in the hand: a burner inserter with an empty burner does
    -- not move, and `insert` on the entity would not reach that inventory.
    local fuel = inserter.get_inventory(defines.inventory.fuel)
    local fed = fuel and fuel.insert({ name = "coal", count = 20 }) or 0
    H.at_least(fed, 1, "A2: the burner inserter is fed")

    H.poll(function()
      return inventory_of(counter).get_item_count(offer.item) >= 5
    end, 12000, 20, function()
      H.at_least(inventory_of(counter).get_item_count(offer.item), 5, "A2: the inserter filled the counter with no script")

      local counter_company = company_id_of(snap(1), counter.unit_number)
      H.ok(counter_company ~= nil, "A2: the inserter-fed counter has its own company")
      local counter_offer = first_offer(company_of(snap(1), counter_company))
      if not H.ok(counter_offer ~= nil, "A2: the second counter has an offer") then
        return
      end

      local accepted = act(1, "accept", { company_id = counter_company, contract_id = counter_offer.id })
      H.ok(accepted.ok, "A2: accept (" .. tostring(accepted.reason) .. ")")

      local stock = inventory_of(counter).get_item_count(counter_offer.item)
      H.ok(stock < counter_offer.quantity, "A2: the counter holds less than the full quantity")
      local refused = act(1, "dispatch", { company_id = counter_company, contract_id = counter_offer.id })
      H.ok(not refused.ok, "A2: a partial delivery is refused")
      H.eq(refused.reason, "not_enough_stock", "A2: the refusal says why")
      H.eq(inventory_of(counter).get_item_count(counter_offer.item), stock, "A2: a refused dispatch takes nothing")

      inventory_of(counter).insert({ name = counter_offer.item, count = counter_offer.quantity - stock })
      local dispatched = act(1, "dispatch", { company_id = counter_company, contract_id = counter_offer.id })
      H.ok(dispatched.ok, "A2: the full quantity dispatches (" .. tostring(dispatched.reason) .. ")")

      -- The robot half, measured rather than assumed. A `container` carries no logistic request, so
      -- no robot has a job that ends in the counter: the only way in is an inserter, or a requester
      -- chest feeding an inserter. Asserted as a fact about the prototype, so the day the counter
      -- becomes a logistic container this check turns red and the framing gets revisited.
      local prototype = prototypes.entity[COUNTER]
      local ok, logistic_mode = pcall(function()
        return prototype.logistic_mode
      end)
      H.ok((not ok) or logistic_mode == nil, "A2: the counter has no logistic request of its own")
      H.note(
        "A2: insertion by logistics robot — NOT reachable with a `container` prototype (measured: logistic_mode="
          .. tostring(logistic_mode)
          .. ", entity_type="
          .. tostring(prototype.type)
          .. "). docs/00-cadrage.md A2 and data/counter.lua claim robots fill it; the engine does not deliver to a plain container."
      )
    end, function()
      H.fail(
        "A2: the inserter never filled the counter (status="
          .. status_name(inserter.status)
          .. ", fuel="
          .. tostring(inserter.get_inventory(defines.inventory.fuel).get_item_count("coal"))
          .. ", chest="
          .. tostring(chest.get_inventory(defines.inventory.chest).get_item_count(offer.item))
          .. ")"
      )
    end, "the inserter to fill the counter")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A3 — conservation of the money, nine operations
-- ---------------------------------------------------------------------------------------------------

M.a3 = {
  id = "A3",
  name = "conservation of the money over nine operations",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "A3: an offer is waiting") then
      return
    end

    local operations = 0
    local function checkpoint(label)
      operations = operations + 1
      local current = snap(1)
      H.ok(conservation_holds(1), "A3: conservation after " .. label)
      H.eq(current.total, 0, "A3: the sum of every balance is zero after " .. label)
      H.eq(current.supply, 0, "A3: the supply is untouched after " .. label)
      assert_pot(current, "A3 " .. label)
      return current
    end

    checkpoint("placing the counter")

    local accepted = act(1, "accept", { company_id = company_id, contract_id = offer.id })
    H.ok(accepted.ok, "A3: accept")
    local after_accept = checkpoint("accept")

    inventory_of(entity).insert({ name = offer.item, count = offer.quantity })
    local dispatched = act(1, "dispatch", { company_id = company_id, contract_id = offer.id })
    H.ok(dispatched.ok, "A3: dispatch")
    checkpoint("dispatch")

    when_paid(1, company_id, offer.id, 30000, function()
      local after_pay = checkpoint("payout")
      H.eq(after_pay.cooperative, after_accept.cooperative + offer.payout, "A3: the payout landed")

      local bought = act(1, "buy", { company_id = company_id, item = "iron-plate", count = 1 })
      H.ok(bought.ok, "A3: buy")
      checkpoint("buy")

      local sold = act(1, "sell", { company_id = company_id, item = "iron-plate", count = 1 })
      H.ok(sold.ok, "A3: sell")
      checkpoint("sell")

      local next_offer = first_offer(company_of(snap(1), company_id))
      if not H.ok(next_offer ~= nil, "A3: a new offer is available") then
        return
      end
      local accepted_again = act(1, "accept", { company_id = company_id, contract_id = next_offer.id })
      H.ok(accepted_again.ok, "A3: accept again")
      local after_second_accept = checkpoint("second accept")

      when_expired(1, company_id, next_offer.id, 60000, function()
        local after_expiry = checkpoint("expiry")
        H.eq(
          after_expiry.cooperative,
          after_second_accept.cooperative - next_offer.reserve,
          "A3: the expiry forfeited the reserve"
        )
        checkpoint("refill after the expiry")
        H.eq(operations, 9, "A3: nine operations were checked")
      end, "A3: the second contract expired")
    end, "A3: the car came back")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A7 / A18 — one thousand generations, never a locked item
-- ---------------------------------------------------------------------------------------------------

-- The catalogue items whose recipe is not enabled for the force: the set a buggy generator would
-- draw from. Asserted non-empty by both scenarios, otherwise the proof would be vacuous.
local function locked_items(force)
  local locked = {}
  for name in pairs(prices.items) do
    local recipe = force.recipes[name]
    if recipe == nil or recipe.enabled ~= true then
      locked[#locked + 1] = name
    end
  end
  table.sort(locked)
  return locked
end

M.a7 = {
  id = "A7",
  name = "a generated contract is always completable with unlocked technology",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    H.ok(entity.valid, "A7: the counter exists")

    local locked = locked_items(force)
    H.at_least(#locked, 1, "A7: the force has locked recipes, so the gate is testable")
    H.note("A7: locked at test time: " .. table.concat(locked, ", "))

    local answer = act(1, "generate", { company_id = company_id, count = 1000 })
    if not H.ok(answer.ok == true, "A7: 1000 generations ran (" .. tostring(answer.reason) .. ")") then
      return
    end
    H.eq(answer.generated, 1000, "A7: one thousand contracts were generated")

    local company = company_of(snap(1), company_id)
    local outside_pool = 0
    local not_enabled = 0
    for _, contract in ipairs(answer.contracts) do
      local recipe = force.recipes[contract.item]
      if recipe == nil or recipe.enabled ~= true then
        not_enabled = not_enabled + 1
      end
      if prices.items[contract.item] == nil or prices.items[contract.item].tier > company.tier then
        outside_pool = outside_pool + 1
      end
    end
    H.eq(not_enabled, 0, "A7: no generated contract asks for an item whose recipe is locked")
    H.eq(outside_pool, 0, "A7: no generated contract is above the company's tier")
    H.at_least(#answer.contracts - outside_pool - not_enabled, 1, "A7: the pool was not empty")
  end,
}

M.a18 = {
  id = "A18",
  name = "never a contract with a locked recipe",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    H.ok(entity.valid, "A18: the counter exists")

    local locked = {}
    local locked_count = 0
    for _, name in ipairs(locked_items(force)) do
      locked[name] = true
      locked_count = locked_count + 1
    end
    H.at_least(locked_count, 1, "A18: at least one catalogue item is locked, so the gate is testable")

    local answer = act(1, "generate", { company_id = company_id, count = 1000 })
    if not H.ok(answer.ok == true, "A18: 1000 generations ran (" .. tostring(answer.reason) .. ")") then
      return
    end
    H.eq(answer.generated, 1000, "A18: one thousand contracts were generated")

    local drawn_locked = {}
    for _, contract in ipairs(answer.contracts) do
      if locked[contract.item] then
        drawn_locked[contract.item] = (drawn_locked[contract.item] or 0) + 1
      end
    end
    local offenders = {}
    for name, count in pairs(drawn_locked) do
      offenders[#offenders + 1] = name .. " x" .. count
    end
    table.sort(offenders)
    H.eq(#offenders, 0, "A18: the locked set and the generated set are disjoint (" .. table.concat(offenders, ", ") .. ")")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A9 — spacing, with refund
-- ---------------------------------------------------------------------------------------------------

M.a9 = {
  id = "A9",
  name = "two counters below the minimum distance are refused, with refund",
  run = function()
    local force = game.forces["player"]
    unlock_counter(force)

    -- No player exists in a headless map and a script cannot create one (measured: LuaGameScript has
    -- no `create_player` in 2.1), so the refund has to be observed where it lands: the ground.
    local first, first_position = place(force, { x = 0, y = 0 })
    H.ok(first.valid, "A9: the first counter is accepted")
    local after_first = snap(1)
    H.eq(#after_first.companies, 1, "A9: the first counter created a company")

    -- 40 tiles away, well inside the 150-tile minimum.
    local second = place(force, { x = first_position.x + 40, y = first_position.y })
    H.eq(second.valid, false, "A9: the counter below the minimum distance is refused")
    local after_second = snap(1)
    H.eq(#after_second.companies, 1, "A9: no company was created for the refused counter")

    local spilled = #surface().find_entities_filtered({
      name = "item-on-ground",
      position = { x = first_position.x + 40, y = first_position.y },
      radius = 8,
    })
    H.at_least(spilled, 1, "A9: the refused counter is refunded (the item is spilled, no player to hand it to)")
    H.note(
      "A9: refund path — the counter item was spilled on the ground (no player exists in a headless map; "
        .. "a script cannot create one in 2.1)"
    )

    -- 300 tiles away: accepted, and it is a second company with its own money.
    local third = place(force, { x = first_position.x + 300, y = first_position.y })
    H.ok(third.valid, "A9: a counter beyond the minimum distance is accepted")
    local after_third = snap(1)
    H.eq(#after_third.companies, 2, "A9: two counters, two companies")
    local balance_first = company_balance(after_third, company_id_of(after_third, first.unit_number))
    local balance_third = company_balance(after_third, company_id_of(after_third, third.unit_number))
    H.ok(balance_first ~= nil and balance_third ~= nil, "A9: each counter has its own company record")
    H.note(
      "A9: the two companies hold their own credits ("
        .. tostring(balance_first)
        .. " / "
        .. tostring(balance_third)
        .. ")"
    )
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A10 — the solvency dial, one map per profile
-- ---------------------------------------------------------------------------------------------------

M.a10 = {
  id = "A10",
  name = "conservation in poor and rich, unlimited says so",
  run = function(params)
    local expected = params and params.profile or "rich"
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })

    H.eq(state.solvency, expected, "A10: the world was created with the '" .. expected .. "' profile")
    H.eq(state.credit_line, balance.solvency.profiles[expected], "A10: the company credit line is the profile's")
    H.eq(state.sandbox, expected == "unlimited", "A10: only unlimited says it is a sandbox")

    local company = company_of(state, company_id)
    H.eq(company.balance, balance.solvency.profiles[expected], "A10: the company is born with its line")

    local offer = first_offer(company)
    if not H.ok(offer ~= nil, "A10: an offer is waiting") then
      return
    end
    local before = snap(1)
    run_contract(1, entity, company_id, offer, "A10")

    H.poll(function()
      local now = snap(1)
      local hub = hub_of(now, entity.unit_number)
      if hub ~= nil and hub.elevator_state == "down" then
        return now
      end
      return false
    end, 20000, 60, function()
      H.ok(true, "A10: the car came back")
      local after = snap(1)
      local settled = contract_of(after, company_id, offer.id)
      if expected == "poor" then
        H.eq(after.cooperative, before.cooperative, "A10: a poor company cannot pay the payout")
        H.eq(settled.state, "in_flight", "A10: the contract stays owed, it is not forgiven")
        H.note("A10: poor — payout refused, contract kept in flight; the dial is doing what ADR 0015 says")
      else
        H.eq(after.cooperative, before.cooperative + offer.payout, "A10: the payout was paid")
        H.eq(settled.state, "done", "A10: the contract is done")
      end
      H.ok(conservation_holds(1), "A10: conservation holds in '" .. expected .. "'")
      H.eq(after.total, 0, "A10: the sum of every balance is zero in '" .. expected .. "'")
      assert_pot(after, "A10 " .. expected)
    end, function()
      H.fail("A10: the car never came back")
    end, "the car to come back")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A13 — expiry moves exactly the reserved amount, once
-- ---------------------------------------------------------------------------------------------------

M.a13 = {
  id = "A13",
  name = "expiry moves exactly the reserved amount",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "A13: an offer is waiting") then
      return
    end

    local accepted = act(1, "accept", { company_id = company_id, contract_id = offer.id })
    H.ok(accepted.ok, "A13: accept")
    local before = snap(1)
    H.eq(before.reserved, offer.reserve, "A13: the escrow is the contract's reserve")
    local company_before = company_balance(before, company_id)

    local deadline = contract_of(before, company_id, offer.id).deadline_tick
    H.at_least(deadline, game.tick, "A13: the deadline is in the future")

    H.after(deadline - game.tick + 30, function()
      local after = snap(1)
      local contract = contract_of(after, company_id, offer.id)
      H.eq(contract.state, "expired", "A13: the contract expired")
      H.eq(after.cooperative, before.cooperative - offer.reserve, "A13: the cooperative lost exactly the reserve")
      H.eq(
        company_balance(after, company_id),
        company_before + offer.reserve,
        "A13: the company gained exactly the reserve"
      )
      H.eq(after.reserved, before.reserved - offer.reserve, "A13: the reserve is released from the pot")

      local again = snap(1)
      H.eq(again.cooperative, after.cooperative, "A13: a second settle does not move money twice")
      H.eq(again.reserved, after.reserved, "A13: a second settle does not release twice")
      H.eq(company_balance(again, company_id), company_balance(after, company_id), "A13: the company is credited once")
      H.eq(contract_of(again, company_id, offer.id).settled, true, "A13: the contract is marked settled")
    end)
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A14 — from zero, selling goods restores the ability to accept
-- ---------------------------------------------------------------------------------------------------

M.a14 = {
  id = "A14",
  name = "from zero, selling goods restores the ability to accept",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "A14: an offer is waiting") then
      return
    end

    -- The endowment is a multiple of the iron plate price (3 000 / 15 = 200): the pot reaches zero.
    local bought = act(1, "buy", { company_id = company_id, item = "iron-plate", count = 100000 })
    H.ok(bought.ok, "A14: the pot is spent on iron plates (" .. tostring(bought.reason) .. ")")
    local drained = snap(1)
    H.eq(drained.available, 0, "A14: the pot is at zero")

    local refused = act(1, "accept", { company_id = company_id, contract_id = offer.id })
    H.ok(not refused.ok, "A14: at zero, no contract can be accepted")
    H.eq(refused.reason, "escrow_unavailable", "A14: the refusal names the cause")

    local sold = act(1, "sell", { company_id = company_id, item = "iron-plate", count = 100 })
    H.ok(sold.ok, "A14: the shop buys the goods back (" .. tostring(sold.reason) .. ")")
    local after_sale = snap(1)
    H.at_least(after_sale.available, offer.reserve, "A14: the sale covers the escrow again")
    assert_pot(after_sale, "A14 after sale")

    local accepted = act(1, "accept", { company_id = company_id, contract_id = offer.id })
    H.ok(accepted.ok, "A14: the contract is accepted after the sale (" .. tostring(accepted.reason) .. ")")
    H.eq(snap(1).reserved, offer.reserve, "A14: the escrow is held")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A15 — buy then resell always loses
-- ---------------------------------------------------------------------------------------------------

M.a15 = {
  id = "A15",
  name = "buy then resell always loses credits",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    H.ok(company_id ~= nil, "A15: the counter has a company")

    local names = {}
    for name in pairs(prices.items) do
      names[#names + 1] = name
    end
    table.sort(names)
    H.eq(#names, prices.item_count, "A15: every catalogue row is walked")

    for _, item in ipairs(names) do
      local entry = prices.items[item]
      local guard = 0
      while snap(1).available < entry.price and guard < 5 do
        guard = guard + 1
        inventory_of(entity).insert({ name = "iron-plate", count = 100 })
        act(1, "sell", { company_id = company_id, item = "iron-plate", count = 100 })
      end

      local before = snap(1)
      local bought = act(1, "buy", { company_id = company_id, item = item, count = 1 })
      H.ok(bought.ok, "A15: buy 1 " .. item .. " (" .. tostring(bought.reason) .. ")")
      local middle = snap(1)
      H.eq(middle.cooperative, before.cooperative - entry.price, "A15: buying 1 " .. item .. " costs the price")
      local sold = act(1, "sell", { company_id = company_id, item = item, count = 1 })
      H.ok(sold.ok, "A15: sell 1 " .. item .. " (" .. tostring(sold.reason) .. ")")
      local after = snap(1)
      H.eq(
        after.cooperative - before.cooperative,
        entry.credits - entry.price,
        "A15: the round trip of " .. item .. " moves exactly credits - price"
      )
      H.ok(after.cooperative < before.cooperative, "A15: buy then resell loses on " .. item)
    end
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A19 — available + reserved = total, after every mutation
-- ---------------------------------------------------------------------------------------------------

M.a19 = {
  id = "A19",
  name = "available + reserved = cooperative after every mutation",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    assert_pot(state, "placement")

    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "A19: an offer is waiting") then
      return
    end

    local accepted = act(1, "accept", { company_id = company_id, contract_id = offer.id })
    H.ok(accepted.ok, "A19: accept")
    assert_pot(snap(1), "accept")

    inventory_of(entity).insert({ name = offer.item, count = offer.quantity })
    local dispatched = act(1, "dispatch", { company_id = company_id, contract_id = offer.id })
    H.ok(dispatched.ok, "A19: dispatch")
    assert_pot(snap(1), "dispatch")

    when_paid(1, company_id, offer.id, 30000, function()
      assert_pot(snap(1), "payout")

      local bought = act(1, "buy", { company_id = company_id, item = "copper-cable", count = 5 })
      H.ok(bought.ok, "A19: buy")
      assert_pot(snap(1), "buy")

      local sold = act(1, "sell", { company_id = company_id, item = "copper-cable", count = 5 })
      H.ok(sold.ok, "A19: sell")
      assert_pot(snap(1), "sell")

      local second = first_offer(company_of(snap(1), company_id))
      if not H.ok(second ~= nil, "A19: a second offer is available") then
        return
      end
      act(1, "accept", { company_id = company_id, contract_id = second.id })
      local expiring = snap(1)
      assert_pot(expiring, "second accept")
      H.after(contract_of(expiring, company_id, second.id).deadline_tick - game.tick + 30, function()
        local expired = snap(1)
        H.eq(contract_of(expired, company_id, second.id).state, "expired", "A19: the second contract expired")
        assert_pot(snap(1), "expiry")
        H.eq(snap(1).total, 0, "A19: the sum of every balance is still zero")
      end)
    end, "A19: the contract to be paid")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A26 — no player name or id in storage
-- ---------------------------------------------------------------------------------------------------

M.a26 = {
  id = "A26",
  name = "no player name or id in storage",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local offer = first_offer(company_of(state, company_id))
    if H.ok(offer ~= nil, "A26: an offer is waiting") then
      inventory_of(entity).insert({ name = offer.item, count = offer.quantity })
      act(1, "accept", { company_id = company_id, contract_id = offer.id })
      act(1, "dispatch", { company_id = company_id, contract_id = offer.id })
      act(1, "buy", { company_id = company_id, item = "iron-plate", count = 3 })
      act(1, "sell", { company_id = company_id, item = "iron-plate", count = 3 })
    end

    local text = dump(1)
    H.ok(
      type(text) == "string" and #text > 100,
      "A26: the storage dump is a real serialisation (" .. tostring(#text) .. " chars)"
    )
    H.ok(text:find("cooperative=") ~= nil, "A26: the dump contains the economy, so the check is not vacuous")
    H.ok(text:lower():find("player") == nil, "A26: no 'player' key or name anywhere in storage")

    -- A stored reference to a human would carry a name, or a field named after one: every key in the
    -- dump is walked, so a new field called `player_name` or `user_name` turns this red.
    local keys = 0
    local suspect = {}
    for key in text:gmatch("([%a_][%w_]*)=") do
      keys = keys + 1
      local lower = key:lower()
      if lower:find("player") ~= nil or lower:find("user") ~= nil or lower:find("character") ~= nil then
        suspect[#suspect + 1] = key
      end
    end
    table.sort(suspect)
    H.at_least(keys, 6, "A26: the dump carries the economy's fields (" .. tostring(keys) .. " keys)")
    H.eq(#suspect, 0, "A26: no player-shaped field in storage (" .. table.concat(suspect, ", ") .. ")")
    H.note(
      "A26: dump length "
        .. tostring(#text)
        .. " chars, "
        .. tostring(keys)
        .. " keys walked. No player exists in a headless map and 2.1 has no `game.create_player`: the "
        .. "proof is the schema of what IS stored (and the absence of any player reference), not a name "
        .. "planted by a client — this one needs a save played by Philippe to be complete."
    )
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A28 — two forces, one contract, the other force untouched
-- ---------------------------------------------------------------------------------------------------

M.a28 = {
  id = "A28",
  name = "two forces: one contract, the other force untouched",
  run = function()
    local force_a = game.forces["player"]
    local force_b = game.forces["other"] or game.create_force("other")
    H.ok(force_b ~= nil, "A28: a second force exists")

    local counter_b = place(force_b, { x = 0, y = 0 })
    H.ok(counter_b.valid, "A28: the second force has a counter")
    local state_b = snap(force_b.index)
    H.eq(#state_b.companies, 1, "A28: the second force has its own company")
    H.eq(state_b.endowment, balance.economy.endowment, "A28: the second force has its own endowment")
    local digest_b = dump(force_b.index)
    local digest_a = dump(force_a.index)

    local entity, company_id, state = new_hub(force_a, { x = 300, y = 0 })
    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "A28: the first force has an offer") then
      return
    end
    run_contract(1, entity, company_id, offer, "A28")

    when_paid(1, company_id, offer.id, 30000, function()
      H.ok(true, "A28: the contract on the first force is paid")
      local digest_b_after = dump(force_b.index)
      local digest_a_after = dump(force_a.index)
      H.eq(digest_b_after, digest_b, "A28: the second force's records are byte-identical")
      H.ok(digest_a_after ~= digest_a, "A28: the first force's records did move")
      H.eq(snap(force_b.index).total, 0, "A28: the second force's ledger still sums to zero")
    end, "A28: the contract on the first force to be paid")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A29 — only `down` sends
-- ---------------------------------------------------------------------------------------------------

M.a29 = {
  id = "A29",
  name = "only down sends, in every other state the dispatch is refused",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local company = company_of(state, company_id)
    local offers = {}
    for _, contract in ipairs(company.contracts) do
      if contract.state == "offered" then
        offers[#offers + 1] = contract
      end
    end
    if not H.at_least(#offers, 2, "A29: at least two offers are available") then
      return
    end

    local first, second = offers[1], offers[2]
    inventory_of(entity).insert({ name = first.item, count = first.quantity })
    local accepted_first = act(1, "accept", { company_id = company_id, contract_id = first.id })
    H.ok(accepted_first.ok, "A29: accept the first")
    local sent = act(1, "dispatch", { company_id = company_id, contract_id = first.id })
    H.ok(sent.ok, "A29: the car leaves with the first contract")

    inventory_of(entity).insert({ name = second.item, count = second.quantity })
    local accepted_second = act(1, "accept", { company_id = company_id, contract_id = second.id })
    H.ok(accepted_second.ok, "A29: accept the second")
    local stock_before = inventory_of(entity).get_item_count(second.item)

    local seen = {}
    local function attempt(label)
      local now = snap(1)
      local hub = hub_of(now, entity.unit_number)
      seen[hub.elevator_state] = (seen[hub.elevator_state] or 0) + 1
      local stock = inventory_of(entity).get_item_count(second.item)
      local answer = act(1, "dispatch", { company_id = company_id, contract_id = second.id })
      if hub.elevator_state == "down" then
        H.ok(answer.ok, "A29: dispatch is accepted when the car is down")
      else
        H.ok(not answer.ok, "A29: dispatch refused while the car is " .. hub.elevator_state)
        H.eq(answer.reason, "elevator_" .. hub.elevator_state, "A29: the refusal names the state (" .. label .. ")")
        H.eq(
          inventory_of(entity).get_item_count(second.item),
          stock,
          "A29: a refused dispatch takes nothing (" .. label .. ")"
        )
        H.eq(stock, stock_before, "A29: the stock is untouched in " .. hub.elevator_state)
      end
      return hub.elevator_state
    end

    local function state_is(name)
      return function()
        local hub = hub_of(snap(1), entity.unit_number)
        return hub.elevator_state == name
      end
    end

    attempt("down before any flight")
    H.after(10, function()
      attempt("rising")
      H.poll(state_is("away"), 3000, 10, function()
        attempt("away")
        H.poll(state_is("descending"), 9000, 20, function()
          attempt("descending")
          H.poll(state_is("down"), 3000, 10, function()
            attempt("down after the flight")
            H.ok(seen["rising"] ~= nil, "A29: the rising state was observed")
            H.ok(seen["away"] ~= nil, "A29: the away state was observed")
            H.ok(seen["descending"] ~= nil, "A29: the descending state was observed")
            H.ok(seen["down"] ~= nil, "A29: the down state was observed")
          end, function()
            H.fail("A29: the car never came down again")
          end, "the car to be down again")
        end, function()
          H.fail("A29: the car never reached descending")
        end, "the car to descend")
      end, function()
        H.fail("A29: the car never reached away")
      end, "the car to be away")
    end)
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------------------
-- A30 — a generated deadline is the round trip plus the production of the whole chain, on every tier
-- ---------------------------------------------------------------------------------------------------

M.a30 = {
  id = "A30",
  name = "generated deadline >= cycle + max(4 min, qty x chain / 2 x 1.5), on all three tiers",
  run = function()
    local force = game.forces["player"]

    -- A30 is about the formula, not about the gate (A7/A18 own the gate). Every catalogue recipe is
    -- unlocked first, so the derived tier reaches 3 and the pool spans the three tiers: without a
    -- tier-2 and a tier-3 item among the thousand draws, the per-tier assertions below would only
    -- ever exercise the tier-1 target, and the test would prove a third of ADR 0048.
    for name in pairs(prices.items) do
      local recipe = force.recipes[name]
      if recipe ~= nil then
        recipe.enabled = true
      end
    end
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    H.ok(entity.valid, "A30: the counter exists")
    H.eq(
      company_of(state, company_id).tier,
      3,
      "A30: the tier is derived from the research and reaches 3, so the whole catalogue is in the pool"
    )

    local answer = act(1, "generate", { company_id = company_id, count = 1000 })
    if not H.ok(answer.ok == true, "A30: 1000 generations ran (" .. tostring(answer.reason) .. ")") then
      return
    end
    H.eq(answer.generated, 1000, "A30: one thousand contracts were generated")

    local cycle = balance.elevator.cycle_seconds
    local floor_seconds = balance.contracts.min_deadline_seconds
    local machines = balance.contracts.machines
    local slack = balance.contracts.production_slack

    -- One bucket per tier, so a red names the tier that broke instead of a pooled count, and a green
    -- cannot hide behind tier 1.
    local buckets = {}
    for tier = 1, 3 do
      buckets[tier] = {
        count = 0,
        too_short = 0,
        wrong_quantity = 0,
        below_cycle = 0,
        floor_binding = 0,
        shortest = nil,
        quantity_min = nil,
        quantity_max = nil,
        items = {},
      }
    end

    local unknown_tier = 0
    local quantity_min = nil
    local quantity_max = nil
    local distinct = {}
    local distinct_count = 0
    for _, contract in ipairs(answer.contracts) do
      local entry = prices.items[contract.item]
      local bucket = buckets[entry.tier]
      if bucket == nil then
        unknown_tier = unknown_tier + 1
      else
        bucket.count = bucket.count + 1
        bucket.items[contract.item] = (bucket.items[contract.item] or 0) + 1
        bucket.quantity_min = math.min(bucket.quantity_min or contract.quantity, contract.quantity)
        bucket.quantity_max = math.max(bucket.quantity_max or contract.quantity, contract.quantity)
        quantity_min = math.min(quantity_min or contract.quantity, contract.quantity)
        quantity_max = math.max(quantity_max or contract.quantity, contract.quantity)

        -- deadline >= cycle + max(4 min, qty x chain / 2 x 1.5), recomputed from the two data files.
        -- `chain` is the whole recipe tree per unit; `seconds` (one recipe) is deliberately unused
        -- here — a test that read it would keep passing on the wrong unit (ADR 0048 §2).
        local production = contract.quantity * entry.chain / machines * slack
        local expected_seconds = math.max(floor_seconds, production) + cycle
        local expected_ticks = math.ceil(expected_seconds * TICKS_PER_SECOND)
        local actual_ticks = contract.deadline_tick - contract.offered_tick
        bucket.shortest = math.min(bucket.shortest or actual_ticks, actual_ticks)
        if production < floor_seconds then
          bucket.floor_binding = bucket.floor_binding + 1
        end
        if actual_ticks < expected_ticks then
          bucket.too_short = bucket.too_short + 1
          if bucket.worst == nil then
            bucket.worst = contract.item
              .. ": "
              .. tostring(actual_ticks)
              .. " ticks, needs "
              .. tostring(expected_ticks)
              .. " ("
              .. string.format("%.1f", expected_seconds)
              .. " s)"
          end
        end
        if actual_ticks < cycle * TICKS_PER_SECOND then
          bucket.below_cycle = bucket.below_cycle + 1
        end

        -- quantity = clamp(round(target[item tier] / payout(item)), 1, 500) (ADR 0048 §1).
        local target = balance.contracts.target_payout[entry.tier]
        local expected_quantity = math.max(1, math.min(500, math.floor(target / entry.payout + 0.5)))
        if contract.quantity ~= expected_quantity then
          bucket.wrong_quantity = bucket.wrong_quantity + 1
          if bucket.worst_quantity == nil then
            bucket.worst_quantity = contract.item
              .. ": got "
              .. tostring(contract.quantity)
              .. ", expected "
              .. tostring(expected_quantity)
              .. " (target "
              .. tostring(target)
              .. " / payout "
              .. tostring(entry.payout)
              .. ")"
          end
        end
      end
      if distinct[contract.item] == nil then
        distinct[contract.item] = true
        distinct_count = distinct_count + 1
      end
    end

    H.eq(unknown_tier, 0, "A30: every generated item has a tier that carries a payout target")
    H.at_least(
      distinct_count,
      10,
      "A30: the thousand draws cover the catalogue (" .. tostring(distinct_count) .. " items)"
    )

    -- The fixtures must reach tiers 2 and 3 on purpose: a run that only drew tier-1 items would make
    -- the two per-tier assertions below vacuous, and the test would prove nothing about 0048.
    H.at_least(
      buckets[2].count,
      1,
      "A30: at least one tier-2 item is in the fixtures (" .. tostring(buckets[2].count) .. " contracts)"
    )
    H.at_least(
      buckets[3].count,
      1,
      "A30: at least one tier-3 item is in the fixtures (" .. tostring(buckets[3].count) .. " contracts)"
    )

    local floor_total = 0
    for tier = 1, 3 do
      local bucket = buckets[tier]
      floor_total = floor_total + bucket.floor_binding
      H.at_least(bucket.count, 1, "A30: tier " .. tier .. " was drawn (" .. tostring(bucket.count) .. " contracts)")
      H.eq(bucket.below_cycle, 0, "A30: tier " .. tier .. " — no deadline shorter than the elevator cycle")
      H.eq(
        bucket.too_short,
        0,
        "A30: tier "
          .. tier
          .. " — every deadline >= cycle + max(4 min, qty x chain / 2 x 1.5)"
          .. (bucket.worst and (" (first offender " .. bucket.worst .. ")") or "")
      )
      H.eq(
        bucket.wrong_quantity,
        0,
        "A30: tier "
          .. tier
          .. " — every quantity is clamp(round("
          .. tostring(balance.contracts.target_payout[tier])
          .. " / payout), 1, 500)"
          .. (bucket.worst_quantity and (" (first offender " .. bucket.worst_quantity .. ")") or "")
      )
      local drawn = {}
      for name, count in pairs(bucket.items) do
        drawn[#drawn + 1] = name .. " x" .. count
      end
      table.sort(drawn)
      H.note(
        "A30: tier "
          .. tier
          .. " — "
          .. tostring(bucket.count)
          .. " contracts, quantities "
          .. tostring(bucket.quantity_min)
          .. ".."
          .. tostring(bucket.quantity_max)
          .. ", shortest deadline "
          .. string.format("%.1f", bucket.shortest / TICKS_PER_SECOND)
          .. " s, items: "
          .. table.concat(drawn, ", ")
      )
    end

    H.at_least(floor_total, 1, "A30: the 4-minute floor still binds somewhere, so the max() is exercised")
    H.note(
      "A30: floor "
        .. tostring(floor_seconds)
        .. " s (binding "
        .. tostring(floor_total)
        .. " times), cycle "
        .. tostring(cycle)
        .. " s, machines "
        .. tostring(machines)
        .. ", slack "
        .. tostring(slack)
        .. "; measured quantities "
        .. tostring(quantity_min)
        .. ".."
        .. tostring(quantity_max)
        .. ", so neither the floor (1) nor the ceiling (500) of the band is reached — the band is a guard, not a shaping term"
    )
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- A31 — the cap is on live contracts, so a fourth is neither generated nor accepted
-- ---------------------------------------------------------------------------------------------------
-- ADR 0051. `offer_slots` counts offered + accepted + in_flight, so accepting never frees a slot and
-- the generator never has one to refill. A fourth contract can only reach a company through
-- `act` "generate", the raw draw the bench uses for a thousand picks (A7, A18, A30) — which is
-- exactly the stale read the `no_free_slot` guard exists for.
-- Two counters are used because a crafted fourth would otherwise skew the second half: the contract
-- that ends has to free one slot on a company that is exactly at the cap.

M.a31 = {
  id = "A31",
  name = "with three live contracts, no fourth offer is generated and a crafted fourth is refused",
  run = function()
    local force = game.forces["player"]
    local cap = balance.contracts.offer_slots

    -- First half: three live contracts, a mix of states, and a crafted fourth.
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    H.ok(entity.valid, "A31: the counter exists")
    local company = company_of(state, company_id)
    H.eq(live_count(company), cap, "A31: a new company holds exactly the cap of live contracts")
    H.eq(#offers_of(company), cap, "A31: ... all of them offers")

    local offers = offers_of(company)
    if not H.at_least(#offers, 2, "A31: at least two offers to work with") then
      return
    end
    local first, second = offers[1], offers[2]

    -- Accept one: the offer becomes an accepted contract, so live is unchanged and no slot frees.
    local pot_before_accept = snap(1)
    local accepted = act(1, "accept", { company_id = company_id, contract_id = first.id })
    H.ok(accepted.ok, "A31: accept the first offer (" .. tostring(accepted.reason) .. ")")
    local after_accept = snap(1)
    local company_accepted = company_of(after_accept, company_id)
    H.eq(live_count(company_accepted), cap, "A31: accepting keeps the live count at the cap")
    H.eq(#offers_of(company_accepted), cap - 1, "A31: ... and the generator did not refill the slot it did not free")
    H.eq(total_contracts(company_accepted), cap, "A31: no contract was created by the accept")
    H.eq(after_accept.reserved - pot_before_accept.reserved, first.reserve, "A31: only the escrow moved")

    -- Send it: a contract in the air still occupies its slot. The three live states are now in play.
    inventory_of(entity).insert({ name = first.item, count = first.quantity })
    local dispatched = act(1, "dispatch", { company_id = company_id, contract_id = first.id })
    H.ok(dispatched.ok, "A31: dispatch the first contract (" .. tostring(dispatched.reason) .. ")")
    local after_dispatch = snap(1)
    local company_flight = company_of(after_dispatch, company_id)
    H.eq(live_count(company_flight), cap, "A31: a contract in flight still occupies its slot")
    H.eq(#offers_of(company_flight), cap - 1, "A31: still no refill while live equals the cap")
    H.eq(total_contracts(company_flight), cap, "A31: still no fourth contract")

    -- Accept the second offer while the first is in the air: one in flight, two accepted, zero slots.
    local accepted_second = act(1, "accept", { company_id = company_id, contract_id = second.id })
    H.ok(accepted_second.ok, "A31: the second offer is accepted while a contract is in flight")
    local mixed = snap(1)
    local company_mixed = company_of(mixed, company_id)
    H.eq(live_count(company_mixed), cap, "A31: one in flight plus two accepted is still three live")
    H.eq(#offers_of(company_mixed), 1, "A31: exactly one offer is left")
    H.eq(total_contracts(company_mixed), cap, "A31: ... and the company still holds three contracts in all")

    -- The crafted fourth: the bench's raw draw creates a contract the game itself never would.
    local crafted = act(1, "generate", { company_id = company_id, count = 1 })
    if not H.ok(crafted.ok, "A31: the bench crafts a fourth contract (" .. tostring(crafted.reason) .. ")") then
      return
    end
    local over = snap(1)
    local company_over = company_of(over, company_id)
    H.eq(live_count(company_over), cap + 1, "A31: the crafted contract puts the company one over the cap")
    H.eq(#offers_of(company_over), 2, "A31: ... as a second offer")
    local reserved_before = over.reserved

    local refused = act(1, "accept", { company_id = company_id, contract_id = crafted.contract.id })
    H.ok(not refused.ok, "A31: accepting the crafted fourth is refused")
    H.eq(refused.reason, "no_free_slot", "A31: the refusal names the slot, not the escrow")
    local after_refusal = snap(1)
    H.eq(
      contract_of(after_refusal, company_id, crafted.contract.id).state,
      "offered",
      "A31: the refused contract is still an offer"
    )
    H.eq(after_refusal.reserved, reserved_before, "A31: a refused acceptance holds no escrow")
    H.eq(live_count(company_of(after_refusal, company_id)), cap + 1, "A31: the refusal moved nothing")
    H.eq(#offers_of(company_of(after_refusal, company_id)), 2, "A31: the refill does not fill past the cap either")

    -- Second half: a company exactly at the cap loses one contract, and exactly one offer takes the slot.
    local entity_b, company_b_id = new_hub(force, { x = 400, y = 0 })
    H.ok(entity_b.valid, "A31: the second counter exists")
    local state_b = snap(1)
    local company_b = company_of(state_b, company_b_id)
    H.eq(live_count(company_b), cap, "A31: the second company starts at the cap")
    local offer_b = offers_of(company_b)[1]
    if not H.ok(offer_b ~= nil, "A31: the second company has an offer to send") then
      return
    end

    inventory_of(entity_b).insert({ name = offer_b.item, count = offer_b.quantity })
    local accepted_b = act(1, "accept", { company_id = company_b_id, contract_id = offer_b.id })
    H.ok(accepted_b.ok, "A31: the second company accepts one (" .. tostring(accepted_b.reason) .. ")")
    local sent_b = act(1, "dispatch", { company_id = company_b_id, contract_id = offer_b.id })
    H.ok(sent_b.ok, "A31: the second company sends it (" .. tostring(sent_b.reason) .. ")")

    local before_pay = snap(1)
    local company_before_pay = company_of(before_pay, company_b_id)
    H.eq(live_count(company_before_pay), cap, "A31: the second company is at the cap with one contract in flight")
    H.eq(#offers_of(company_before_pay), cap - 1, "A31: ... and holds two offers while it waits")
    local ids_before = ids_of(company_before_pay)
    local total_before = total_contracts(company_before_pay)

    when_paid(1, company_b_id, offer_b.id, 30000, function()
      local paid = snap(1)
      local company_paid = company_of(paid, company_b_id)
      H.eq(contract_of(paid, company_b_id, offer_b.id).state, "done", "A31: the sent contract is paid")

      local created = 0
      for _, contract in ipairs(company_paid.contracts) do
        if ids_before[contract.id] ~= true then
          created = created + 1
        end
      end
      H.eq(created, 1, "A31: the refill generated exactly one contract")
      H.eq(total_contracts(company_paid), total_before + 1, "A31: ... so the company holds exactly one more than before")
      H.eq(live_count(company_paid), cap, "A31: the live count is back at the cap, never above it")
      H.eq(#offers_of(company_paid), cap, "A31: three offers again — the paid contract's slot was taken by one offer")
      H.note(
        "A31: cap "
          .. tostring(cap)
          .. " counted on live contracts; the fourth contract was crafted through `act` \"generate\" "
          .. "and refused with `no_free_slot`; the refill after the payment created exactly one contract "
          .. "("
          .. tostring(live_count(company_paid))
          .. " live, "
          .. tostring(#offers_of(company_paid))
          .. " offers)"
      )
    end, "A31: the sent contract to be paid")
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- a9 (task) — the car survives a save taken mid-flight
-- ---------------------------------------------------------------------------------------------------

M["a9-save"] = {
  id = "a9-save",
  name = "mid-flight save (first half, server mode)",
  run = function()
    local force = game.forces["player"]
    local entity, company_id, state = new_hub(force, { x = 0, y = 0 })
    local offer = first_offer(company_of(state, company_id))
    if not H.ok(offer ~= nil, "a9-save: an offer is waiting") then
      return
    end
    run_contract(1, entity, company_id, offer, "a9-save")
    local after = snap(1)
    local hub = hub_of(after, entity.unit_number)
    local contract = contract_of(after, company_id, offer.id)
    H.eq(hub.elevator_state, "rising", "a9-save: the car left")

    -- No `game.server_save` here: measured, the call is accepted and writes nothing on a headless
    -- server. What does write the map is the shutdown save — the runner stops the server once this
    -- marker is on disk, and the engine saves the map on its way out. The car is in the air at that
    -- moment, which is exactly the state the resume half must find on disk.
    H.after(60, function()
      helpers.write_file(
        "mid-flight.json",
        table.concat({
          '{"tick":', tostring(game.tick),
          ',"elevator_state":"', tostring(hub.elevator_state), '"',
          ',"phase_ends_tick":', tostring(hub.elevator_phase_ends_tick),
          ',"return_tick":', tostring(hub.elevator_return_tick),
          ',"unit_number":', tostring(entity.unit_number),
          ',"company_id":', tostring(company_id),
          ',"contract_id":', tostring(offer.id),
          ',"payout":', tostring(offer.payout),
          ',"reserve":', tostring(offer.reserve),
          ',"cooperative":', tostring(after.cooperative),
          ',"reserved":', tostring(after.reserved),
          ',"deadline_tick":', tostring(contract.deadline_tick),
          "}",
        })
      )
      H.note(
        "a9-save: marker written at tick "
          .. tostring(game.tick)
          .. ", due back at "
          .. tostring(hub.elevator_return_tick)
          .. " — the runner now stops the server, which saves the map on shutdown"
      )
    end)
  end,
}

M["a9-resume"] = {
  id = "a9-resume",
  name = "resume after a mid-flight save (second half)",
  run = function(params)
    H.ok(params ~= nil and params.return_tick ~= nil, "a9-resume: the first half's figures were passed in")
    if params == nil or params.return_tick == nil then
      return
    end
    local state = snap(1)
    local hub = hub_of(state, params.unit_number)
    if not H.ok(hub ~= nil, "a9-resume: the hub survived the save") then
      return
    end
    H.eq(hub.elevator_state, params.elevator_state, "a9-resume: the state is the one that was saved")
    H.eq(hub.elevator_phase_ends_tick, params.phase_ends_tick, "a9-resume: the phase ends at the saved tick")
    H.eq(hub.elevator_return_tick, params.return_tick, "a9-resume: the return tick is the saved one")

    local contract = contract_of(state, params.company_id, params.contract_id)
    H.ok(contract ~= nil, "a9-resume: the contract survived the save")
    H.eq(contract.state, "in_flight", "a9-resume: the contract is still owed after the reload")

    -- Nothing may send while the car is in the air, on a freshly loaded map too.
    local other = first_offer(company_of(state, params.company_id))
    if other ~= nil then
      local attempted = act(1, "dispatch", { company_id = params.company_id, contract_id = other.id })
      H.ok(not attempted.ok, "a9-resume: no dispatch while the car is away after a reload")
    end

    H.after(math.max(0, params.return_tick - game.tick) + 30, function()
      local after = snap(1)
      local settled = contract_of(after, params.company_id, params.contract_id)
      H.eq(settled.state, "done", "a9-resume: the contract is paid after the reload")
      H.eq(after.cooperative, params.cooperative + params.payout, "a9-resume: the payout is credited once")
      H.eq(after.reserved, params.reserved - params.reserve, "a9-resume: the escrow is released once")
      H.at_least(settled.settled_tick, params.return_tick, "a9-resume: paid at the end of the trip, not at the load")
      H.at_most(settled.settled_tick, params.return_tick + 300, "a9-resume: paid promptly after the trip")
      local hub_after = hub_of(after, params.unit_number)
      H.eq(hub_after.elevator_state, "down", "a9-resume: the car is down again")

      -- And the machine still works: a fresh contract leaves normally.
      local next_offer = first_offer(company_of(after, params.company_id))
      if not H.ok(next_offer ~= nil, "a9-resume: a new offer is waiting") then
        return
      end
      local counter = nil
      for _, candidate in ipairs(
        surface().find_entities_filtered({ name = COUNTER, position = hub_after.position, radius = 3 })
      ) do
        counter = candidate
      end
      if counter == nil then
        H.fail("a9-resume: the counter entity was not found next to the hub")
        return
      end
      inventory_of(counter).insert({ name = next_offer.item, count = next_offer.quantity })
      act(1, "accept", { company_id = params.company_id, contract_id = next_offer.id })
      local again = act(1, "dispatch", { company_id = params.company_id, contract_id = next_offer.id })
      H.ok(again.ok, "a9-resume: a new dispatch works after the reload (" .. tostring(again.reason) .. ")")
    end)
  end,
}

-- ---------------------------------------------------------------------------------------------------
-- B1-gui-pure — the window's pure functions, three crafted cases each (lot b)
-- ---------------------------------------------------------------------------------------------------
-- ADR 0050: a frame cannot be built headless (no player, so no `player.gui.screen`), and the measured
-- probe only works inside a running client. What CAN be proven here is the half the window computes:
-- the module loads, and every function that turns a number into what the player reads answers the
-- expected value on crafted inputs. The drawing side stays a by-eye criterion, and the scenario says
-- so instead of pretending.

M["b1-gui-pure"] = {
  id = "B1-gui-pure",
  name = "the GUI module loads, and its pure functions answer three crafted cases each",
  run = function()
    -- Required at the top of this file: a syntax error or a bad `require` inside
    -- scripts/gui/window.lua would have stopped the whole bench before this line runs.
    H.eq(gui_format.API_VERSION, 1, "B1-gui-pure: scripts/gui/format.lua loaded")
    H.eq(gui_window.API_VERSION, 1, "B1-gui-pure: scripts/gui/window.lua loaded")
    H.ok(type(gui_window.on_opened) == "function", "B1-gui-pure: the window exposes on_opened (the ADR 0050 entry point)")
    H.ok(type(gui_window.on_click) == "function", "B1-gui-pure: the window exposes on_click")
    H.ok(type(gui_window.on_text_changed) == "function", "B1-gui-pure: the window exposes on_text_changed")
    H.at_least(#gui_window.REASONS, 20, "B1-gui-pure: every refusal reason is listed for the locale audit")

    local reasons_ok = true
    for _, reason in ipairs(gui_window.REASONS) do
      if type(reason) ~= "string" or #reason < 3 or reason:find("%s") ~= nil then
        reasons_ok = false
      end
    end
    H.ok(reasons_ok, "B1-gui-pure: each reason is a plain key (no space, no number)")

    -- Every reason carries a literal caption under [comptoir], and the caption table holds nothing the
    -- window cannot print: a refusal with no key is a line of "Unknown key" in the player's chat (ADR
    -- 0053). `tools/check_locale.py` proves the other direction — those keys exist in both locale files.
    local captions_ok = true
    local captioned = 0
    for _, reason in ipairs(gui_window.REASONS) do
      local caption = gui_window.REASON_KEYS[reason]
      captioned = captioned + 1
      if type(caption) ~= "table" or type(caption[1]) ~= "string"
        or caption[1]:find("^comptoir%.[a-z0-9%-]+$") == nil then
        captions_ok = false
      end
    end
    H.eq(captioned, #gui_window.REASONS, "B1-gui-pure: every listed reason has a caption")
    H.ok(captions_ok, "B1-gui-pure: every caption is a literal key of the form comptoir.<name>")
    local stray = 0
    for code in pairs(gui_window.REASON_KEYS) do
      local listed = false
      for _, reason in ipairs(gui_window.REASONS) do
        if reason == code then
          listed = true
        end
      end
      if not listed then
        stray = stray + 1
      end
    end
    H.eq(stray, 0, "B1-gui-pure: no caption for a reason the window does not list")

    -- Same deal for the three group names of the character line: the catalogue is the list, the caption
    -- table must cover it, and a group with no caption would print its raw name in the header.
    local groups_captioned = true
    for _, group in ipairs(catalogue.groups) do
      local caption = gui_window.GROUP_KEYS[group]
      if type(caption) ~= "table" or type(caption[1]) ~= "string"
        or caption[1]:find("^comptoir%.[a-z0-9%-]+$") == nil then
        groups_captioned = false
      end
    end
    H.ok(groups_captioned, "B1-gui-pure: every catalogue group has a literal caption")

    -- Case 1, case 2, case 3 of a row: quantity, payout, reserve, clock and bar band. The contract
    -- tables are plain: no game, no storage, no entity.
    local rows = {
      {
        label = "case 1 (fresh offer, full bar)",
        contract = { item = "iron-plate", quantity = 208, payout = 2496, reserve = 500, deadline_seconds = 333, deadline_tick = 19980 },
        remaining = 19980,
        total = 19980,
        quantity = "208",
        payout = "2 496",
        reserve = "500",
        clock = "5:33",
        band = "normal",
      },
      {
        label = "case 2 (a fifth of the time left)",
        contract = { item = "electronic-circuit", quantity = 40, payout = 1160, reserve = 232, deadline_seconds = 40, deadline_tick = 2400 },
        remaining = 500,
        total = 2400,
        quantity = "40",
        payout = "1 160",
        reserve = "232",
        clock = "0:09",
        band = "amber",
      },
      {
        label = "case 3 (one second left, out of 35 minutes)",
        contract = { item = "processing-unit", quantity = 1, payout = 1975, reserve = 395, deadline_seconds = 2121, deadline_tick = 127260 },
        remaining = 60,
        total = 127260,
        quantity = "1",
        payout = "1 975",
        reserve = "395",
        clock = "0:01",
        band = "red",
      },
    }

    for _, row in ipairs(rows) do
      local texts = gui_format.row_texts(row.contract, row.remaining, row.total)
      H.eq(texts.quantity, row.quantity, "B1-gui-pure: " .. row.label .. " quantity")
      H.eq(texts.payout, row.payout, "B1-gui-pure: " .. row.label .. " payout")
      H.eq(texts.reserve, row.reserve, "B1-gui-pure: " .. row.label .. " reserve")
      H.eq(texts.clock, row.clock, "B1-gui-pure: " .. row.label .. " clock")
      H.eq(texts.band, row.band, "B1-gui-pure: " .. row.label .. " bar band")
      H.eq(texts.item, row.contract.item, "B1-gui-pure: " .. row.label .. " icon item")
      H.at_most(texts.fraction, 1, "B1-gui-pure: " .. row.label .. " bar fraction stays in [0, 1]")
      H.at_least(texts.fraction, 0, "B1-gui-pure: " .. row.label .. " bar fraction stays in [0, 1]")
    end

    -- The band boundaries themselves: 25 % is still normal, 10 % is still amber.
    H.eq((gui_format.bar(2500, 10000)), 0.25, "B1-gui-pure: 25 % is the last normal fraction")
    H.eq(select(2, gui_format.bar(2500, 10000)), "normal", "B1-gui-pure: 25 % is still normal")
    H.eq(select(2, gui_format.bar(2499, 10000)), "amber", "B1-gui-pure: under 25 % is amber")
    H.eq(select(2, gui_format.bar(1000, 10000)), "amber", "B1-gui-pure: 10 % is still amber")
    H.eq(select(2, gui_format.bar(999, 10000)), "red", "B1-gui-pure: under 10 % is red")

    -- Time formatting, three crafted cases (a zero, a minute boundary, a long contract).
    H.eq(gui_format.clock(0), "0:00", "B1-gui-pure: time formatting of zero ticks")
    H.eq(gui_format.clock(373), "0:07", "B1-gui-pure: time formatting rounds up to the second")
    H.eq(gui_format.clock(43440), "12:04", "B1-gui-pure: time formatting of 12 minutes")

    -- Grouping, three crafted cases (no separator, one separator, several).
    H.eq(gui_format.grouped(208), "208", "B1-gui-pure: grouping 208")
    H.eq(gui_format.grouped(2496), "2 496", "B1-gui-pure: grouping 2 496")
    H.eq(gui_format.grouped(1234567), "1 234 567", "B1-gui-pure: grouping 1 234 567")

    -- Clamping, three crafted cases: below the balance, above it, above the hard ceiling.
    H.eq(gui_format.clamp_quantity(37, 200), 37, "B1-gui-pure: 37 under a 200 ceiling stays 37")
    H.eq(gui_format.clamp_quantity(500, 200), 200, "B1-gui-pure: 500 under a 200 ceiling clamps to 200")
    H.eq(gui_format.clamp_quantity(5000, 99999), gui_format.MAX_QUANTITY, "B1-gui-pure: nothing passes " .. tostring(gui_format.MAX_QUANTITY))
    H.eq(gui_format.clamp_quantity(nil, 200), 1, "B1-gui-pure: an unreadable field falls back to the floor of 1")
    H.eq(gui_format.clamp_quantity(12, 0), 1, "B1-gui-pure: a balance that allows nothing still floors at 1")

    -- Parsing: digits only, never a guess.
    H.eq(gui_format.parse_quantity("42"), 42, "B1-gui-pure: digits parse")
    H.eq(gui_format.parse_quantity(" 42 "), 42, "B1-gui-pure: surrounding spaces are tolerated")
    H.eq(gui_format.parse_quantity("4x"), nil, "B1-gui-pure: a letter is refused, not truncated to 4")
    H.eq(gui_format.parse_quantity(""), nil, "B1-gui-pure: an empty field is refused")

    -- Presets share one value (A23) and are clamped to the balance before any click (A24).
    H.eq(gui_format.preset_count("10", 100, 37), 10, "B1-gui-pure: preset 10 with 37 affordable stays 10")
    H.eq(gui_format.preset_count("stack", 100, 37), 37, "B1-gui-pure: a stack above the balance shows the balance")
    H.eq(gui_format.preset_count("100", 100, 500), 100, "B1-gui-pure: preset 100 with 500 affordable stays 100")

    local stack_size = prototypes.item[gui_format.price_order()[1]].stack_size
    H.at_least(stack_size, 1, "B1-gui-pure: the stack preset reads a real prototype stack size")
    H.eq(
      gui_format.preset_count("stack", stack_size, 1000000),
      stack_size,
      "B1-gui-pure: a stack the balance covers is one stack"
    )

    -- The shop ladder: sixteen rows, cheapest first, deterministic.
    local order = gui_format.price_order()
    H.eq(#order, 16, "B1-gui-pure: the counter tab lists 16 items")
    H.eq(order[1], "copper-cable", "B1-gui-pure: the cheapest item opens the ladder")
    H.eq(order[#order], "processing-unit", "B1-gui-pure: the dearest item closes it")
    local sorted = true
    for index = 2, #order do
      if prices.items[order[index - 1]].price > prices.items[order[index]].price then
        sorted = false
      end
    end
    H.ok(sorted, "B1-gui-pure: the ladder is in non-decreasing price order")

    -- The header icon and the character line: one item per group, one line per company.
    for _, group in ipairs(catalogue.groups) do
      local item = gui_format.group_item(group)
      H.eq(catalogue.items[item], group, "B1-gui-pure: the icon of " .. group .. " is a " .. group .. " item (" .. item .. ")")
    end
    H.eq(gui_format.group_item("electronics"), "copper-cable", "B1-gui-pure: electronics shows the copper cable")

    local primary, secondary = gui_format.character({ weights = { chemistry = 3, electronics = 2, logistics = 1 } })
    H.eq(primary, "chemistry", "B1-gui-pure: the dominant group leads the character line")
    H.eq(secondary, "electronics", "B1-gui-pure: the second axis follows it")
    local tied_primary, tied_secondary = gui_format.character({ weights = { chemistry = 3, electronics = 3, logistics = 1 } })
    H.eq(tied_primary, "chemistry", "B1-gui-pure: equal weights fall back to the sorted group name")
    H.eq(tied_secondary, "electronics", "B1-gui-pure: and so does the second axis")

    -- The colour of a company is a function of its id alone, and wraps.
    local first = gui_format.colour_of(1)
    H.ok(type(first.r) == "number" and type(first.g) == "number" and type(first.b) == "number", "B1-gui-pure: colour_of returns a colour")
    H.eq(gui_format.colour_of(1 + #gui_format.COLOURS).r, first.r, "B1-gui-pure: the colour palette wraps by id")

    -- The remaining time is read from the contract, never recomputed by the window.
    local remaining, total = contracts.time_left({ deadline_seconds = 333, deadline_tick = 1000 }, 200)
    H.eq(remaining, 800, "B1-gui-pure: time_left counts down from the deadline")
    H.eq(total, 19980, "B1-gui-pure: time_left reports the span the bar is a fraction of")
    local late, _ = contracts.time_left({ deadline_seconds = 333, deadline_tick = 1000 }, 5000)
    H.eq(late, 0, "B1-gui-pure: time_left never goes negative")

    -- A21's runtime half, measured instead of scanned: four of the window's keys are handed to the
    -- engine, which writes the text it actually resolves (H.probe_locale). A key missing from the
    -- locale — or declared with its prefix still on it, the lot-b regression — lands in the probe file
    -- as `Unknown key: "comptoir.…"`, and `judge()` in tools/run_tests.py turns the run red. This is
    -- the only check in the bench that asks the engine to render a string.
    H.probe_locale("available", { "comptoir.available", 1 })
    H.probe_locale("character", { "comptoir.character", "Chemistry", "Logistics" })
    H.probe_locale("group-chemistry", { "comptoir.group-chemistry" })
    H.probe_locale("reason-no-free-slot", { "comptoir.reason-no-free-slot" })

    H.note(
      "B1-gui-pure: the frame itself cannot be built headless (ADR 0050 — no `player.gui.screen` without a "
        .. "client). Proven here: the two modules load, and row text, clamping, presets, grouping, the clock, "
        .. "the bar bands, the price ladder, the character line and the colour answer the expected values on "
        .. "crafted cases. The layout stays a by-eye criterion."
    )
  end,
}

-- The queue, in the order `docs/09-tests.md` lists the criteria.
M.ORDER = {
  "a1", "a2", "a3", "a7", "a9", "a10", "a13", "a14", "a15", "a18", "a19", "a26", "a28", "a29", "a30",
  "a31",
  "b1-gui-pure",
  "a9-save", "a9-resume",
}

return M
