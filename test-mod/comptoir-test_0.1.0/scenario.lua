-- scenario.lua — the selector. `tools/run_tests.py` rewrites this file before every run.
--
-- Description: says which scenario the next run must execute, and with which parameters. Keeping it
--              in a file (rather than a command-line argument) is what the engine gives us: a mod
--              cannot read the command line. The runner writes, the game reads.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial
-- Usages:      required by control.lua
-- Notes:       `id = "all"` queues every scenario in one map — useful by hand, never in CI, because
--              the scenarios then share the economy. The runner always asks for one scenario.
-- Licence:     MIT (see LICENSE)

return {
  id = "a1",
  params = nil,
}
