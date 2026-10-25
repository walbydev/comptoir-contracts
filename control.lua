-- control.lua — event wiring only.
--
-- Description: the mod's runtime entry point. Each `script.on_*` handler forwards to one function of
--              one module; this file holds no decision, no state and no arithmetic. Reading it must
--              be enough to know which events the mod listens to — and to see that on_tick is absent.
--              It also declares the one remote interface the harness (and any add-on) uses to read the
--              economy (design.md §5, correction to ADR 0042).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: on_init and on_configuration_changed wired to scripts/migrate.lua
--              2026-10-25 — building a counter creates its company; `snapshot` exposed to the remote API
-- Usages:      executed by the game once per session, before any other control-stage file
-- Notes:       `require` is only legal while control.lua files are being parsed — never inside a
--              handler (measured on 2.1.23: "Require can't be used outside of control.lua parsing").
--              So every module is required here, at the top, once.
--              `storage` is the only persistent table (never `global`: removed in 2.0).
--              `script_raised_built` is wired to the same handler as the two engine events: it is the
--              only way a harness can simulate a placement (measured 2026-10-25 — `on_built_entity`
--              itself cannot be raised by script, and `script_raised_built` is dispatched when raised
--              from an event handler, but not from `on_init`).
-- Licence:     MIT (see LICENSE)

local migrate = require("__comptoir-contracts__/scripts/migrate")
local companies = require("__comptoir-contracts__/scripts/companies")
local contracts = require("__comptoir-contracts__/scripts/contracts")
local ledger = require("__comptoir-contracts__/scripts/ledger")

-- Placing a counter creates the company that owns it, once (a6). The distance check and the refund of
-- a refused build are not here: they arrive with the interface that explains the refusal (a9, b6).
local function on_built(event)
  local entity = event.entity
  if entity == nil or entity.valid == false then
    return
  end
  if entity.name ~= "comptoir-counter" then
    return
  end
  companies.create_for_hub(storage, entity.force, entity, game.tick)
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)

script.on_init(function()
  migrate.init(storage)
end)

script.on_configuration_changed(function()
  migrate.on_configuration_changed(storage)
end)

-- Read-only door on the economy: `remote.call("comptoir-contracts", "snapshot", force_index)` returns
-- plain numbers and strings, never a table of `storage` (design.md §5).
-- Every member must be a function: `remote.add_interface` rejects anything else (measured 2026-10-25,
-- "Function 1: function must be a function but is a number"), so the version numbers travel inside
-- the snapshot instead of beside it.
remote.add_interface("comptoir-contracts", {
  snapshot = function(force_index)
    if type(force_index) ~= "number" or force_index % 1 ~= 0 then
      error("[comptoir] snapshot: force_index must be an integer, got " .. tostring(force_index), 2)
    end
    return companies.snapshot(storage, force_index)
  end,
  -- The invariants a harness needs to check without owning the economy.
  assert_conservation = function(force_index)
    local state = storage.forces and storage.forces[force_index]
    if state == nil then
      return 0
    end
    return ledger.assert_conservation(state, "remote " .. force_index)
  end,
  quantity_for_payout = function(payout)
    return contracts.quantity(payout)
  end,
  reserve_for_payout = function(payout)
    return contracts.reserve(payout)
  end,
  deadline_seconds = function(quantity, machine_seconds)
    return contracts.deadline_seconds(quantity, machine_seconds)
  end,
})
