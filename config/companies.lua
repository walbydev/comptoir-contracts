-- config/companies.lua — the shape of a company: its name, its character, its tastes.
--
-- Description: the vocabulary the generator draws from. A company gets one name for life and one
--              character made of two axes: a type (its dominant group of goods) and weights over the
--              three groups. Everything here is data, so a balancing pass can retune who wants what
--              without touching an algorithm.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: 10x10 name grid, three groups, per-item group map
-- Usages:      required by scripts/companies.lua (creation, name, character weights)
-- Notes:       `groups` is sorted on purpose: the LCG draws an index into it, so an unsorted table
--              would give a different company on two clients and desynchronise them (design.md §4).
--              `items` maps every catalogue item to its group; a missing entry is a load-time error,
--              never a silent default, because a silent default is how a tier-3 item ends up with a
--              tier-1 weight and nobody notices.
--              ADR 0022: the character is two visible axes and it never removes an item from a pool —
--              it only makes some more likely.
-- Licence:     MIT (see LICENSE)

local prices = require("__comptoir-contracts__/data/prices")

local M = {}

-- A company is "<first> <last>": 100 combinations, drawn once at creation and then frozen in
-- `storage`. Two companies of the same force never share a name while a free combination remains.
M.first_names = {
  "Meridian",
  "Halcyon",
  "Vantage",
  "Kestrel",
  "Northwind",
  "Solace",
  "Ferrum",
  "Cobalt",
  "Ardent",
  "Juniper",
}

M.last_names = {
  "Trading",
  "Freight",
  "Foundry",
  "Works",
  "Supply",
  "Holdings",
  "Industries",
  "Logistics",
  "Materials",
  "& Fils",
}

-- The three axes of a character (ADR 0022). Sorted: the LCG draws an index into this list.
M.groups = { "chemistry", "electronics", "logistics" }

-- Weights of the character: the dominant group is three times as likely as a neutral one, the
-- second axis twice. A vector, not a filter: every group keeps a non-zero weight (ADR 0034 §3).
M.weights = {
  primary = 3,
  secondary = 2,
  other = 1,
}

-- How many draws before a duplicate name is accepted with a numeric suffix. 40 attempts over 100
-- combinations: reaching it means the force already holds a lot of counters.
M.name_attempts = 40

-- Which group each item of the catalogue belongs to. The catalogue is `data/prices.lua` (15 items,
-- measured); this map is the commercial reading of it: what the company trades, not what the recipe
-- tree says. `pipe` is not here: the game names it as an entity only, so it left the catalogue
-- (ADR 0052), and a group for an item nobody can buy is data that never gets read.
M.items = {
  ["copper-cable"] = "electronics",
  ["electronic-circuit"] = "electronics",
  ["advanced-circuit"] = "electronics",
  ["processing-unit"] = "electronics",
  ["battery"] = "electronics",
  ["electric-engine-unit"] = "electronics",

  ["iron-plate"] = "logistics",
  ["copper-plate"] = "logistics",
  ["steel-plate"] = "logistics",
  ["iron-gear-wheel"] = "logistics",
  ["engine-unit"] = "logistics",
  ["stone-brick"] = "logistics",

  ["plastic-bar"] = "chemistry",
  ["sulfur"] = "chemistry",
  ["low-density-structure"] = "chemistry",
}

-- Load-time guards. They run while control.lua is parsed, so a bad edit fails at load with a line
-- number instead of producing a company with a nonsense weight mid-game.
do
  local previous = nil
  for index, group in ipairs(M.groups) do
    if type(group) ~= "string" then
      error("[comptoir] config/companies: groups[" .. index .. "] is not a string")
    end
    if previous ~= nil and group <= previous then
      error("[comptoir] config/companies: groups must be sorted (" .. previous .. " then " .. group .. ")")
    end
    previous = group
  end

  for name in pairs(prices.items) do
    local group = M.items[name]
    if group == nil then
      error("[comptoir] config/companies: catalogue item without a group: " .. name)
    end
    local known = false
    for _, candidate in ipairs(M.groups) do
      if candidate == group then
        known = true
      end
    end
    if not known then
      error("[comptoir] config/companies: " .. name .. " points at unknown group " .. group)
    end
  end
end

return M
