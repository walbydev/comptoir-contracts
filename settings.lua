-- settings.lua — the one dial the player sets at map creation.
--
-- Description: declares the startup setting `comptoir-solvency` (D29, ADR 0015 §3-4): the credit line
--              the companies of a new world are born with. `poor` (line 0), `rich` (the default) and
--              `unlimited` (sandbox). The numbers themselves live in `config/balance.lua`; this file
--              only names them, and `scripts/companies.lua` refuses to run if the two lists diverge.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: startup setting, three allowed values
-- Usages:      read by the game at map creation, then by scripts/companies.lua on first use of a force
-- Notes:       A **startup** setting, not a runtime one: a player who can flip to `unlimited` when the
--              treasury is empty has no economy (ADR 0015 §4). The value is therefore copied into
--              `storage` when a force's economy is born, and never read again from the setting.
--              The allowed values are derived from the data file, in sorted order, so a profile added
--              to `config/balance.lua` appears in the interface without touching this file.
-- Licence:     MIT (see LICENSE)

local balance = require("__comptoir-contracts__/config/balance")

local values = {}
for name in pairs(balance.solvency.profiles) do
  values[#values + 1] = name
end
table.sort(values)

data:extend({
  {
    type = "string-setting",
    name = "comptoir-solvency",
    setting_type = "startup",
    default_value = balance.solvency.default,
    allowed_values = values,
    order = "a[comptoir]-a[solvency]",
  },
})
