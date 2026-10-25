-- scripts/elevator.lua — the round trip of the car, as a state machine and a timestamp.
--
-- Description: owns the four states of a hub's elevator (`down`, `rising`, `away`, `descending`) and
--              the two absolute ticks that describe where in the trip the car is. It answers one
--              question — "may this hub send, and when does it come back?" — and it never touches
--              money: the payout is `scripts/contracts.lua`'s business (design.md §1).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: four states, one flight at a time, absolute phase end (a9)
--              2026-10-25 — `pause_reason` (ADR 0056 §2): the four states, read as the one answer the
--                           counter gives every shop action while the car is away
-- Usages:      required by control.lua, scripts/companies.lua (hub creation) and scripts/contracts.lua
-- Notes:       NO TICK HANDLER. The trip is two numbers in `storage` — the state and the tick the
--              current phase ends at — and `advance` walks them whenever something reads (design.md
--              §3: lazy, never on a clock). A save taken mid-flight therefore resumes exactly where it
--              was: nothing to reconstruct, nothing to re-arm. This is the whole reason the phases are
--              absolute ticks rather than counters. The one clock in the mod is the interface's, and
--              it only measures (`scripts/gui/window.lua`, ADR 0056 §2): a window being open makes
--              `advance` be called twice a second, and nothing else about this file changes.
--              ONLY `down` SENDS (A29, ADR 0043): `can_send` is the single gate, and every caller —
--              the GUI button, the remote API, a future add-on — asks it. There is no second path.
--              A phase chain that does not end is an error, not a while-loop with a hope: a corrupt
--              state must be read, not absorbed.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")

local M = {}

M.API_VERSION = 1

M.DOWN = "down"
M.RISING = "rising"
M.AWAY = "away"
M.DESCENDING = "descending"

-- The order of a trip, kept as an array so `advance` reads the same sequence on every client.
M.ORDER = { M.RISING, M.AWAY, M.DESCENDING }

local function ticks_of(seconds)
  return math.ceil(seconds * 60)
end

-- Seconds to ticks, once, at load: 8 s -> 480, 104 s -> 6240, 8 s -> 480.
M.DURATION = {
  [M.RISING] = ticks_of(balance.elevator.rise_seconds),
  [M.AWAY] = ticks_of(balance.elevator.away_seconds),
  [M.DESCENDING] = ticks_of(balance.elevator.descend_seconds),
}

M.CYCLE_TICKS = ticks_of(balance.elevator.cycle_seconds)

-- Load-time guard: the three phases are the cycle, or the deadline formula lies about the trip.
do
  local total = 0
  for _, state in ipairs(M.ORDER) do
    total = total + M.DURATION[state]
  end
  if total ~= M.CYCLE_TICKS then
    error(
      "[comptoir] scripts/elevator: phases sum to "
        .. total
        .. " ticks, cycle_seconds is "
        .. M.CYCLE_TICKS
        .. " ticks"
    )
  end
end

local function known_state(state)
  if state == M.DOWN then
    return true
  end
  for _, candidate in ipairs(M.ORDER) do
    if candidate == state then
      return true
    end
  end
  return false
end

-- A fresh elevator, car at the bottom.
function M.new(tick)
  if type(tick) ~= "number" or tick % 1 ~= 0 or tick < 0 then
    error("[comptoir] elevator.new: tick must be a non-negative integer, got " .. tostring(tick), 2)
  end
  return {
    state = M.DOWN,
    since_tick = tick,
    phase_ends_tick = tick,
    sent_tick = nil,
    return_tick = nil,
  }
end

local function check(hub, where)
  if hub == nil or hub.elevator == nil then
    error("[comptoir] elevator." .. where .. ": hub has no elevator record", 3)
  end
  local elevator = hub.elevator
  if not known_state(elevator.state) then
    error(
      "[comptoir] elevator." .. where .. ": unknown state " .. tostring(elevator.state)
        .. " — a save from another build, refusing to guess",
      3
    )
  end
  if type(elevator.phase_ends_tick) ~= "number" then
    error("[comptoir] elevator." .. where .. ": no phase_ends_tick", 3)
  end
  return elevator
end

-- The one gate (A29). Every dispatch path asks this and nothing else.
function M.can_send(hub)
  local elevator = check(hub, "can_send")
  return elevator.state == M.DOWN
end

function M.state_of(hub)
  return check(hub, "state_of").state
end

-- The pause of ADR 0056 §2, in one place. While the car is not down the counter answers nothing at
-- all — no acceptance, no purchase, no sale, no dispatch — and every caller asks here rather than
-- re-reading the four states. Returns nil when the counter may speak, or the reason it may not, in
-- the same `elevator_<state>` vocabulary the dispatch gate already uses (so the window needs no new
-- refusal caption: it already has one per state).
function M.pause_reason(hub)
  local elevator_state = check(hub, "pause_reason").state
  if elevator_state == M.DOWN then
    return nil
  end
  return "elevator_" .. elevator_state
end

-- The car leaves. Refuses unless it is down: one flight at a time, per hub (F6, ADR 0043).
-- Returns the tick the car is due back, which is the sum of the three phases from now.
function M.send(hub, tick)
  local elevator = check(hub, "send")
  if elevator.state ~= M.DOWN then
    return false, "elevator_" .. elevator.state
  end
  elevator.state = M.RISING
  elevator.since_tick = tick
  elevator.sent_tick = tick
  elevator.phase_ends_tick = tick + M.DURATION[M.RISING]
  elevator.return_tick = tick + M.CYCLE_TICKS
  return true, nil, elevator.return_tick
end

-- Walk every phase that has ended. Returns true exactly once per trip: on the call that brings the
-- car back to the bottom. The next phase's end is computed from the previous end, never from `tick`,
-- so a save/reload or a long absence does not stretch the trip.
function M.advance(hub, tick)
  local elevator = check(hub, "advance")
  local arrived = false
  local guard = 0
  while elevator.state ~= M.DOWN and tick >= elevator.phase_ends_tick do
    guard = guard + 1
    if guard > #M.ORDER + 1 then
      error("[comptoir] elevator.advance: phase chain did not terminate for hub in state " .. tostring(elevator.state), 2)
    end
    local next_state
    if elevator.state == M.RISING then
      next_state = M.AWAY
    elseif elevator.state == M.AWAY then
      next_state = M.DESCENDING
    else
      next_state = M.DOWN
    end
    elevator.since_tick = elevator.phase_ends_tick
    elevator.phase_ends_tick = elevator.phase_ends_tick + (M.DURATION[next_state] or 0)
    elevator.state = next_state
    if next_state == M.DOWN then
      arrived = true
      elevator.return_tick = elevator.phase_ends_tick
    end
  end
  return arrived
end

-- Ticks until the car is down again (0 when it already is). For the interface and for tests.
function M.remaining_ticks(hub, tick)
  local elevator = check(hub, "remaining_ticks")
  if elevator.state == M.DOWN then
    return 0
  end
  local remaining = elevator.phase_ends_tick - tick
  if elevator.state == M.RISING then
    return remaining + M.DURATION[M.AWAY] + M.DURATION[M.DESCENDING]
  elseif elevator.state == M.AWAY then
    return remaining + M.DURATION[M.DESCENDING]
  end
  return remaining
end

return M
