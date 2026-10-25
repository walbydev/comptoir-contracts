-- data.lua — prototype stage entry point.
--
-- Description: every prototype of the mod is created through the files required here. Nothing
--              else happens in this file: a prototype error is a load failure for every player, so
--              this stage stays declarative and free of logic.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: counter, item, recipe and technology
-- Usages:      loaded by the game in the data stage, before any save exists
-- Notes:       `data/prices.lua` is NOT loaded here. It is generated data read at runtime by the
--              control stage (`require("__comptoir-contracts__/data/prices")`), and the engine only
--              executes data.lua, data-updates.lua and data-final-fixes.lua at the root.
-- Licence:     MIT (see LICENSE)

require("__comptoir-contracts__/data/counter")
require("__comptoir-contracts__/data/item")
require("__comptoir-contracts__/data/technology")
