-- scripts/harness.lua — the bench: one result per criterion, written to disk.
--
-- Description: the smallest possible test harness for Factorio 2.x, where `coroutine` no longer
--              exists (measured 2026-10-25: `attempt to index global 'coroutine'`). A scenario is a
--              function that runs to completion and schedules its waiting half with `H.after` /
--              `H.poll`; the driver (control.lua of the test mod) drains the due callbacks every
--              third tick. Every scenario carries the name of its criterion and ends as exactly one
--              entry of `test-results.json` in the game's script-output.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: assertions, JSON writer, failure accounting
--              2026-10-25 — coroutines replaced by scheduled callbacks (the engine removed them)
-- Usages:      required by control.lua and scripts/scenarios.lua of the test mod
-- Notes:       `helpers.write_file` is the only way a mod may write a file (measured 2026-10-25 on
--              2.1.23: there is no `game.write_file`). The JSON is built by hand: no library ships
--              with the game and a serializer here would be a second thing to test.
--              A TEST THAT CANNOT FAIL IS A BUG: an entry with zero assertions is red, even when
--              nothing "failed". The file is rewritten after every scenario, so the runner can stop
--              the game as soon as the answer it asked for is in — no timed waits in the runner.
-- Licence:     MIT (see LICENSE)

local H = {}

H.RESULTS_FILE = "test-results.json"

H.results = {}
H.current = nil
H.scenario = nil
H.written = false
H.pending = {}
H.deadline = nil

local function escape(text)
  local out = tostring(text)
  out = out:gsub("\\", "\\\\")
  out = out:gsub('"', '\\"')
  out = out:gsub("\n", "\\n")
  out = out:gsub("\r", "")
  out = out:gsub("\t", " ")
  return out
end

local function quote(text)
  return '"' .. escape(text) .. '"'
end

function H.begin_scenario(id, name)
  H.scenario = id
  H.pending = {}
  H.deadline = game.tick + 400000
  H.current = {
    id = id,
    name = name,
    checks = 0,
    failures = 0,
    detail = {},
  }
  H.results[#H.results + 1] = H.current
end

-- An assertion. `message` must say what was expected, in the vocabulary of the criterion.
function H.ok(condition, message)
  if H.current == nil then
    error("[comptoir-test] harness.ok outside a scenario: " .. tostring(message), 2)
  end
  H.current.checks = H.current.checks + 1
  if condition ~= true then
    H.current.failures = H.current.failures + 1
    H.current.detail[#H.current.detail + 1] = "FAIL " .. tostring(message)
  end
  return condition == true
end

function H.eq(actual, expected, message)
  return H.ok(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

function H.at_least(actual, floor, message)
  local ok = type(actual) == "number" and type(floor) == "number" and actual >= floor
  return H.ok(ok, message .. " (expected >= " .. tostring(floor) .. ", got " .. tostring(actual) .. ")")
end

function H.at_most(actual, ceiling, message)
  local ok = type(actual) == "number" and type(ceiling) == "number" and actual <= ceiling
  return H.ok(ok, message .. " (expected <= " .. tostring(ceiling) .. ", got " .. tostring(actual) .. ")")
end

-- Informational line, never a verdict: the runner prints it, the judge reads it.
function H.note(message)
  if H.current ~= nil then
    H.current.detail[#H.current.detail + 1] = "NOTE " .. tostring(message)
  end
  log("[comptoir-test] NOTE " .. tostring(message))
end

-- Schedule `fn` for the tick that comes `ticks` ticks later, at the earliest. Never a multiple
-- assumption: the driver wakes when the tick is at least the one we asked for.
function H.after(ticks, fn)
  H.pending[#H.pending + 1] = { at = game.tick + math.max(1, math.floor(ticks or 1)), fn = fn }
end

-- Poll `predicate` every `step` ticks until it returns something truthy (handed to `on_success`), or
-- until `budget` ticks have passed (then `on_timeout`, or a failed assertion naming the wait).
function H.poll(predicate, budget, step, on_success, on_timeout, label)
  budget = budget or 30000
  step = math.max(1, math.floor(step or 60))
  local waited = 0
  local function attempt()
    local value = predicate()
    if value then
      on_success(value)
      return
    end
    waited = waited + step
    if waited > budget then
      if on_timeout ~= nil then
        on_timeout()
      else
        H.fail("timed out after " .. tostring(budget) .. " ticks waiting for " .. tostring(label or "a condition"))
      end
      return
    end
    H.after(step, attempt)
  end
  attempt()
end

-- Run every callback whose tick has come. Returns true when at least one ran.
-- A callback that raises is a failed scenario: the queue is emptied so the bench moves on.
function H.drain_due()
  local now = game.tick
  local ran = false
  local index = 1
  while index <= #H.pending do
    local item = H.pending[index]
    if item.at <= now then
      table.remove(H.pending, index)
      ran = true
      local ok, err = pcall(item.fn)
      if not ok then
        H.fail("step raised: " .. tostring(err))
        H.pending = {}
        return true
      end
    else
      index = index + 1
    end
  end
  return ran
end

function H.fail(message)
  H.ok(false, message)
end

-- Write (or rewrite) the results file. Called after every scenario and at the end of the queue.
function H.write()
  local parts = {}
  for _, entry in ipairs(H.results) do
    local detail = {}
    for _, line in ipairs(entry.detail) do
      detail[#detail + 1] = quote(line)
    end
    local status = "pass"
    if entry.failures > 0 or entry.checks < 1 then
      status = "fail"
    end
    parts[#parts + 1] = table.concat({
      '{"id":', quote(entry.id),
      ',"name":', quote(entry.name),
      ',"status":', quote(status),
      ',"checks":', tostring(entry.checks),
      ',"failures":', tostring(entry.failures),
      ',"detail":[', table.concat(detail, ","), "]}",
    })
  end

  local body = table.concat({
    '{"api":1',
    ',"scenario":', quote(tostring(H.scenario)),
    ',"tick":', tostring(game.tick),
    ',"tests":[', table.concat(parts, ","), "]}",
  })
  helpers.write_file(H.RESULTS_FILE, body)
  H.written = true
  log("[comptoir-test] results written at tick " .. game.tick .. " (" .. #H.results .. " scenario(s))")
end

-- A scenario that raised: it is a failing entry, and the message says where.
function H.fatal(message)
  if H.current == nil then
    H.begin_scenario("fatal", "harness")
  end
  H.ok(false, "scenario raised: " .. tostring(message))
  H.pending = {}
  H.write()
end

return H
