-- control.lua — the driver: one scenario at a time, woken by the tick, results written to disk.
--
-- Description: runs the scenario named by `scenario.lua` (or the whole queue when it says "all") and
--              rewrites `script-output/test-results.json` after every scenario, so the runner can
--              stop the game as soon as its answer is in. Factorio 2.x has no `coroutine` library
--              (measured 2026-10-25), so a scenario is a function that schedules its waiting half
--              with `H.after` / `H.poll`; this file drains what is due.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: queue + coroutine driver
--              2026-10-25 — callbacks instead of coroutines (the engine removed them)
-- Usages:      entry point of the test mod (loaded by the game)
-- Notes:       The driver is woken by `on_nth_tick(3)`, which fires on ticks divisible by 3, tick 0
--              included. That is deliberate and harmless: the driver is a clock, not a phase. No
--              scenario assumes a tick multiple — waits are "at least n ticks" and the elevator
--              phases are read from the snapshot. The mod under test never uses on_tick; the bench
--              does not either, it hangs off the same nth-tick event and costs nothing when idle.
--              The queue is rebuilt on every load: the bench keeps nothing in `storage`, so a map
--              reloaded mid-run starts its queue again — which is what the resumed test needs.
-- Licence:     MIT (see LICENSE)

local harness = require("__comptoir-test__/scripts/harness")
local scenarios = require("__comptoir-test__/scripts/scenarios")
local selection = require("__comptoir-test__/scenario")

local queue = {}
local started = false
local finished = false
local active = false

local function build_queue()
  if selection == nil or selection.id == nil or selection.id == "all" then
    for _, key in ipairs(scenarios.ORDER) do
      queue[#queue + 1] = { key = key, params = nil }
    end
  else
    queue[1] = { key = selection.id, params = selection.params }
  end
end

local function start_next()
  local item = table.remove(queue, 1)
  if item == nil then
    return false
  end
  local scenario = scenarios[item.key]
  if scenario == nil then
    harness.begin_scenario(item.key, "unknown scenario")
    harness.fail("no scenario named '" .. tostring(item.key) .. "'")
    harness.write()
    return start_next()
  end
  harness.begin_scenario(scenario.id, scenario.name)
  local ok, err = pcall(scenario.run, item.params)
  if not ok then
    harness.fatal(err)
  end
  active = true
  return true
end

local function step()
  if not started then
    started = true
    build_queue()
  end
  if finished then
    return
  end

  if not active then
    if not start_next() then
      finished = true
      harness.write()
      return
    end
  end

  harness.drain_due()

  if harness.deadline ~= nil and game.tick > harness.deadline then
    harness.fail("scenario exceeded its deadline of 400000 ticks")
    harness.pending = {}
  end

  if #harness.pending == 0 then
    harness.write()
    active = false
  end
end

script.on_nth_tick(3, function()
  step()
end)
