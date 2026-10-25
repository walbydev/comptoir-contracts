-- control.lua — event wiring only.
--
-- Description: the mod's runtime entry point. Each `script.on_*` handler forwards to one function of
--              one module; this file holds no decision, no state and no arithmetic. Reading it must
--              be enough to know which events the mod listens to — and to see that on_tick is absent.
--              It also declares the one remote interface the harness (and any add-on) uses to read and
--              drive the economy (design.md §5, correction to ADR 0042).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: on_init and on_configuration_changed wired to scripts/migrate.lua
--              2026-10-25 — building a counter creates its company; `snapshot` exposed to the remote API
--              2026-10-25 — a8/a9/a10: spacing check with refund, first offers on build, `act` door
--                           (accept, dispatch, buy, sell, generate), settle pass before every read
--              2026-10-25 — ADR 0048: `quantity_for_payout` takes the item's tier, `deadline_seconds`
--                           takes the item's chain (the two formula doors follow the generator)
--              2026-10-25 — lot b: the four GUI events wired to scripts/gui/window.lua (opened, closed,
--                           click, text changed); no tick handler was added for the window either
--              2026-10-25 — ADR 0056 §2: `accept` and the two trades are handed the company's counter,
--                           so every action of the door refuses while the car is away. This file is
--                           still wiring only: the pause lives in the modules, the clock in the window.
-- Usages:      executed by the game once per session, before any other control-stage file
-- Notes:       `require` is only legal while control.lua files are being parsed — never inside a
--              handler (measured on 2.1.23: "Require can't be used outside of control.lua parsing").
--              So every module is required here, at the top, once.
--              `storage` is the only persistent table (never `global`: removed in 2.0).
--              `script_raised_built` is wired to the same handler as the two engine events: it is the
--              only way a harness can simulate a placement (measured 2026-10-25 — `on_built_entity`
--              itself cannot be raised by script, and `script_raised_built` is dispatched when raised
--              from an event handler, but not from `on_init`).
--              NO TICK HANDLER IN THIS FILE: the trips, the deadlines and the refills are settled by
--              the read that needs them (`scripts/contracts.lua`). The one clock in the mod is the
--              counter window's (scripts/gui/window.lua, ADR 0056 §2) — it starts when the first window
--              opens and stops when the last one closes — and it is not wired here either.
--              `act` is a door on the rules, not a second implementation of them: it validates the
--              shape of the arguments, settles what is due, calls one module function and copies the
--              answer out. The verdicts (`ok`, `reason`) are the modules'.
-- Licence:     MIT (see LICENSE)

local migrate = require("__comptoir-contracts__/scripts/migrate")
local companies = require("__comptoir-contracts__/scripts/companies")
local contracts = require("__comptoir-contracts__/scripts/contracts")
local counter = require("__comptoir-contracts__/scripts/counter")
local ledger = require("__comptoir-contracts__/scripts/ledger")
local window = require("__comptoir-contracts__/scripts/gui/window")
local balance = require("__comptoir-contracts__/config/balance")

local COUNTER = "comptoir-counter"

-- A plain copy of a contract, for the remote door: no reference into `storage` escapes.
local function contract_view(contract)
  if contract == nil then
    return nil
  end
  return {
    id = contract.id,
    kind = contract.kind,
    item = contract.item,
    quantity = contract.quantity,
    payout = contract.payout,
    reserve = contract.reserve,
    deadline_seconds = contract.deadline_seconds,
    deadline_tick = contract.deadline_tick,
    state = contract.state,
    settled = contract.settled,
    offered_tick = contract.offered_tick,
    accepted_tick = contract.accepted_tick,
    dispatched_tick = contract.dispatched_tick,
    settled_tick = contract.settled_tick,
  }
end

-- Give the counter back to whoever built it (A9, D41). A player gets it in the inventory; a robot, or
-- a script that built it without a player, gets it on the ground at the refused position.
local function refund_counter(entity, player)
  local stack = { name = COUNTER, count = 1 }
  if player ~= nil and player.valid then
    if player.insert(stack) >= 1 then
      return "player"
    end
  end
  entity.surface.spill_item_stack({
    position = entity.position,
    stack = stack,
    enable_looted = true,
    force = entity.force,
  })
  return "ground"
end

-- Placing a counter creates the company that owns it, once (a6), and fills its first offers (F3).
-- A counter closer than `counter.min_distance` to another one of the same force is refused, and the
-- item is refunded (A9, D41).
local function on_built(event)
  local entity = event.entity
  if entity == nil or entity.valid == false then
    return
  end
  if entity.name ~= COUNTER then
    return
  end

  local allowed, distance, nearest = companies.distance_allows(storage, entity)
  if not allowed then
    local player = event.player_index and game.get_player(event.player_index) or entity.last_user
    local position = entity.position
    local returned = refund_counter(entity, player)
    entity.destroy()
    log(
      string.format(
        "[comptoir] counter refused at (%.1f, %.1f): %.1f tiles from counter %s, minimum is %d — item returned to %s",
        position.x,
        position.y,
        distance,
        tostring(nearest),
        balance.counter.min_distance,
        returned
      )
    )
    return
  end

  local company = companies.create_for_hub(storage, entity.force, entity, game.tick)
  contracts.refill(entity.force, company, game.tick)
end

-- A destroyed counter stops being a hub. Its company keeps its money, its contracts and its history:
-- only the counter is gone (the company is the economic actor, ADR 0024).
local function on_destroyed(event)
  local entity = event.entity
  if entity == nil or entity.name ~= COUNTER then
    return
  end
  if storage.hubs ~= nil then
    storage.hubs[entity.unit_number] = nil
  end
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.on_entity_died, on_destroyed)
script.on_event(defines.events.script_raised_destroy, on_destroyed)

-- The window (lot b). Four events, no tick: the frame is drawn when it opens, on a tab change, on a
-- preset and after every action, never on a clock (docs/06 §1).
-- Opening the counter replaces the vanilla container frame: `player.opened = nil` inside
-- on_gui_opened, then a frame in `player.gui.screen` (measured 2026-10-25, ADR 0050, and the working
-- probe in `spike/gui-probe/`). The close caused by that assignment bounces back as on_gui_closed in
-- the same tick and is ignored by `window.on_closed`.
script.on_event(defines.events.on_gui_opened, function(event)
  window.on_opened(storage, event)
end)
script.on_event(defines.events.on_gui_closed, function(event)
  window.on_closed(storage, event)
end)
script.on_event(defines.events.on_gui_click, function(event)
  window.on_click(storage, event)
end)
script.on_event(defines.events.on_gui_text_changed, function(event)
  window.on_text_changed(storage, event)
end)

script.on_init(function()
  migrate.init(storage)
end)

script.on_configuration_changed(function()
  migrate.on_configuration_changed(storage)
end)

-- Read-only door on the economy: `remote.call("comptoir-contracts", "snapshot", force_index)` returns
-- plain numbers and strings, never a table of `storage` (design.md §5).
-- Every member must be a function: `remote.add_interface` rejects anything else (measured 2026-10-25,
-- "Function 1: function must be a function but is not a number"), so the version numbers travel inside
-- the snapshot instead of beside it.
remote.add_interface("comptoir-contracts", {
  -- The interface's refresh: settles first, so what it draws is what is true now.
  snapshot = function(force_index)
    if type(force_index) ~= "number" or force_index % 1 ~= 0 then
      error("[comptoir] snapshot: force_index must be an integer, got " .. tostring(force_index), 2)
    end
    local force = game.forces[force_index]
    if force ~= nil then
      contracts.settle(storage, force, game.tick)
    end
    return companies.snapshot(storage, force_index)
  end,

  -- The settle pass on its own, for a caller that only wants time to move.
  settle = function(force_index)
    local force = game.forces[force_index]
    if force == nil then
      error("[comptoir] settle: unknown force " .. tostring(force_index), 2)
    end
    return contracts.settle(storage, force, game.tick)
  end,

  -- The one door that changes the economy. `params` is a plain table; the answer is plain data.
  -- Actions: accept, dispatch, buy, sell, generate. Unknown actions are refused, never guessed.
  act = function(force_index, action, params)
    if type(force_index) ~= "number" or force_index % 1 ~= 0 then
      error("[comptoir] act: force_index must be an integer, got " .. tostring(force_index), 2)
    end
    if type(action) ~= "string" then
      error("[comptoir] act: action must be a string, got " .. tostring(action), 2)
    end
    params = params or {}
    local force = game.forces[force_index]
    if force == nil then
      error("[comptoir] act: unknown force " .. tostring(force_index), 2)
    end

    local tick = game.tick
    contracts.settle(storage, force, tick)
    local state = companies.force_state(storage, force_index)

    if action == "accept" then
      local company = state.companies[params.company_id]
      if company == nil then
        return { ok = false, reason = "unknown_company" }
      end
      local ok, reason, contract = contracts.accept(state, storage, force_index, force, company, params.contract_id, tick)
      return { ok = ok, reason = reason, contract = contract_view(contract) }
    elseif action == "dispatch" then
      local company = state.companies[params.company_id]
      if company == nil then
        return { ok = false, reason = "unknown_company" }
      end
      local ok, reason, contract = contracts.dispatch(state, storage, force_index, company, params.contract_id, tick)
      return { ok = ok, reason = reason, contract = contract_view(contract) }
    elseif action == "buy" or action == "sell" then
      local company = state.companies[params.company_id]
      if company == nil then
        return { ok = false, reason = "unknown_company" }
      end
      local hub = contracts.hub_for_company(storage, force_index, company.id)
      if hub == nil then
        return { ok = false, reason = "no_hub" }
      end
      local entity = companies.hub_entity(hub)
      local trade = counter[action]
      local ok, reason, count, total = trade(state, company, entity, params.item, params.count, hub)
      return { ok = ok, reason = reason, count = count, total = total }
    elseif action == "generate" then
      local company = state.companies[params.company_id]
      if company == nil then
        return { ok = false, reason = "unknown_company" }
      end
      -- `count` is how a bench asks for a thousand draws in one call (A7, A18, A30) without paying
      -- the lazy settle a thousand times. Clamped: no caller may spin the generator forever.
      local wanted = params.count or 1
      if type(wanted) ~= "number" or wanted % 1 ~= 0 or wanted < 1 then
        return { ok = false, reason = "bad_count" }
      end
      wanted = math.min(wanted, 1000)
      local generated = {}
      local reason = nil
      for _ = 1, wanted do
        local contract, why = contracts.generate(force, company, tick)
        if contract == nil then
          reason = why
          break
        end
        generated[#generated + 1] = contract_view(contract)
      end
      return {
        ok = #generated > 0,
        reason = reason,
        generated = #generated,
        contracts = generated,
        contract = generated[1],
      }
    end
    return { ok = false, reason = "unknown_action" }
  end,

  -- A read-only text dump of one force's records: the harness proof for "nothing but the economy is
  -- stored" (A26) and "a force that did nothing did not move" (A28). Not a door on the rules.
  storage_dump = function(force_index)
    if type(force_index) ~= "number" or force_index % 1 ~= 0 then
      error("[comptoir] storage_dump: force_index must be an integer, got " .. tostring(force_index), 2)
    end
    return companies.dump_storage(storage, force_index)
  end,

  -- The invariants a harness needs to check without owning the economy.
  assert_conservation = function(force_index)
    local state = storage.forces and storage.forces[force_index]
    if state == nil then
      return 0
    end
    return ledger.assert_conservation(state, "remote " .. force_index)
  end,
  -- The two formulas, exposed so a harness can recompute a contract instead of trusting it.
  -- `quantity_for_payout` takes the **item's tier** as a second argument (ADR 0048 §1: the target
  -- scales per tier) and `deadline_seconds` takes the item's `chain`, not its single-recipe `seconds`
  -- (ADR 0048 §2). A caller that forgets the tier gets an explicit error, never a tier-1 default.
  quantity_for_payout = function(payout, tier)
    return contracts.quantity(payout, tier)
  end,
  reserve_for_payout = function(payout)
    return contracts.reserve(payout)
  end,
  deadline_seconds = function(quantity, chain_seconds)
    return contracts.deadline_seconds(quantity, chain_seconds)
  end,
})
