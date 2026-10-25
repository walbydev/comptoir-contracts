-- scripts/migrate.lua — `storage.version` and the migration chain.
--
-- Description: the only module that owns the shape of `storage` across versions. `init` builds the
--              version-1 skeleton; `run` walks the chain from the version found in the save to the
--              version this build writes, and refuses loudly when a step is missing.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: version 1, empty chain, ensured-on-load path
-- Usages:      required by control.lua; called from on_init and on_configuration_changed only
-- Notes:       v1 ships an empty chain on purpose (design.md §7): the chain exists from the first
--              release because it cannot be added retroactively to saves already in the wild.
--              A missing step raises, it never guesses: a half-migrated save that keeps playing is
--              worse than a save that refuses to load and says why.
--              The `storage` argument is always the caller's storage, never the module's: a module
--              that reaches for the global reads the wrong table the day it is tested.
-- Licence:     MIT (see LICENSE)

local M = {}

M.STORAGE_VERSION = 1

-- The chain: { from = n, to = n + 1, apply = function(storage) ... end }, ordered by `from`.
M.chain = {}

-- Build the version-1 skeleton. No company exists yet: a company is born when a counter is built.
function M.init(storage)
  storage.version = M.STORAGE_VERSION
  storage.forces = {}
  storage.hubs = {}
  log("[comptoir] new save: storage version " .. M.STORAGE_VERSION .. " initialised")
end

-- A save created before the mod was installed has no `storage` of ours: on_init does not run when a
-- mod is added to an existing save, only on_configuration_changed does. This closes that gap.
local function ensure(storage)
  if storage.version == nil then
    M.init(storage)
    return true
  end
  return false
end

local function step_from(version)
  for _, candidate in ipairs(M.chain) do
    if candidate.from == version then
      return candidate
    end
  end
  return nil
end

-- Bring `storage` to M.STORAGE_VERSION. Returns the number of steps applied.
function M.run(storage)
  local created = ensure(storage)
  if created then
    return 0
  end

  if storage.version > M.STORAGE_VERSION then
    error(
      "[comptoir] this save was written by a newer build: storage version "
        .. storage.version
        .. ", this build understands "
        .. M.STORAGE_VERSION
        .. ". Refusing to continue."
    )
  end

  local steps = 0
  while storage.version < M.STORAGE_VERSION do
    local step = step_from(storage.version)
    if step == nil then
      error(
        "[comptoir] no migration step from storage version "
          .. storage.version
          .. " to "
          .. (storage.version + 1)
          .. " (target "
          .. M.STORAGE_VERSION
          .. "). Refusing to continue."
      )
    end
    step.apply(storage)
    storage.version = step.to
    steps = steps + 1
  end
  return steps
end

-- on_configuration_changed: the mod set changed, a mod was updated, or the mod was just added.
function M.on_configuration_changed(storage)
  ensure(storage)
  local before = storage.version
  local steps = M.run(storage)
  log(
    "[comptoir] configuration changed: storage version "
      .. tostring(before)
      .. " -> "
      .. storage.version
      .. " (target "
      .. M.STORAGE_VERSION
      .. "), "
      .. steps
      .. " migration step(s) applied"
  )
  return steps
end

return M
