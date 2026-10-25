-- control.lua — event wiring only.
--
-- Description: the mod's runtime entry point. Each `script.on_*` handler forwards to one function of
--              one module; this file holds no decision, no state and no arithmetic. Reading it must
--              be enough to know which events the mod listens to — and to see that on_tick is absent.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: on_init and on_configuration_changed wired to scripts/migrate.lua
-- Usages:      executed by the game once per session, before any other control-stage file
-- Notes:       `require` is only legal while control.lua files are being parsed — never inside a
--              handler (measured on 2.1.23: "Require can't be used outside of control.lua parsing").
--              So every module is required here, at the top, once.
--              `storage` is the only persistent table (never `global`: removed in 2.0).
-- Licence:     MIT (see LICENSE)

local migrate = require("__comptoir-contracts__/scripts/migrate")

script.on_init(function()
  migrate.init(storage)
end)

script.on_configuration_changed(function()
  migrate.on_configuration_changed(storage)
end)
