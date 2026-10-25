-- scripts/gui/format.lua — the arithmetic of the window, and nothing that needs a window.
--
-- Description: every number the counter window shows passes through here: grouped figures, the M:SS
--              clock, the two bands of the deadline bar, the clamp of the quantity field and the
--              price ladder of the shop tab. Pure functions over plain values — no `game`, no
--              `storage`, no element — so a headless scenario can assert them (ADR 0050: the window
--              is not testable, its arithmetic is).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: grouping, clock, bar bands, clamp, presets, price order (b1-b3)
-- Usages:      required by scripts/gui/window.lua and by the bench (scenario b1-gui-pure)
-- Notes:       NO NUMBER IS RECOMPUTED HERE. A quantity, a payout or a reserve arrives from
--              `scripts/contracts.lua` and is only formatted: the window never multiplies, never
--              divides, never re-derives a rule.
--              THE CLAMP FLOOR IS 1 (ADR 0038 §2, "clamped to [1, 2 147]") even when the balance
--              allows nothing: a field showing 0 reads as a broken control, and the disabled action
--              button is what says "you cannot" (A22). The ceiling the caller passes is what the
--              balance allows, so the field never exceeds it as soon as that ceiling reaches 1.
--              THE THREE BANDS ARE COMPUTED, NOT PAINTED. Lot (b) draws a plain bar (mission: no
--              styling); `bar` returns the band so the state pass can colour it later without
--              writing a second formula.
--              EVERYTHING IS DETERMINISTIC AND LOCALE-FREE: the strings are digits and separators,
--              the words come from `locale/*/strings.cfg` and are applied by window.lua (A21).
-- Licence:     MIT (see LICENSE)

local prices = require("__comptoir-contracts__/data/prices")
local catalogue = require("__comptoir-contracts__/config/companies")

local M = {}

M.API_VERSION = 1

-- ADR 0038 §2: the quantity field never accepts more than this, whatever the balance allows.
M.MAX_QUANTITY = 2147

-- docs/06-interface.md §2: the bar turns amber under 25 % of the time left, red under 10 %.
M.BAR_AMBER = 0.25
M.BAR_RED = 0.10

-- The colours of the character line (ADR 0022 §3: a colour per company). Chosen from the company
-- id, so two clients show the same colour without storing anything.
M.COLOURS = {
  { r = 0.98, g = 0.62, b = 0.28 },
  { r = 0.42, g = 0.78, b = 0.98 },
  { r = 0.62, g = 0.90, b = 0.48 },
  { r = 0.95, g = 0.48, b = 0.52 },
  { r = 0.80, g = 0.65, b = 0.98 },
  { r = 0.98, g = 0.86, b = 0.40 },
}

local function is_finite_number(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Digits of a non-negative integer, grouped by three with a plain space: 208 -> "208",
-- 4996 -> "4 996", 1234567 -> "1 234 567". Built by walking the digits, so no pattern can leave a
-- trailing separator behind.
local function group_digits(digits)
  local out = {}
  local length = #digits
  for index = 1, length do
    out[#out + 1] = string.sub(digits, index, index)
    local remaining = length - index
    if remaining > 0 and remaining % 3 == 0 then
      out[#out + 1] = " "
    end
  end
  return table.concat(out)
end

-- A figure as the window shows it. Never nil: a caller that passes nonsense gets an error, because a
-- silent zero is how a payout becomes invisible (docs/06 §5, A21's spirit).
function M.grouped(amount)
  if not is_finite_number(amount) then
    error("[comptoir] gui.format.grouped: not a finite number: " .. tostring(amount), 2)
  end
  local rounded = math.floor(math.abs(amount) + 0.5)
  local text = group_digits(tostring(rounded))
  if amount < 0 then
    return "-" .. text
  end
  return text
end

-- Ticks to "M:SS", rounded up so a contract never reads 0:00 while a second is left. Minutes are not
-- padded, seconds always are: 0 -> "0:00", 373 -> "0:07", 19980 -> "5:33", 43440 -> "12:04".
function M.clock(ticks)
  if not is_finite_number(ticks) then
    error("[comptoir] gui.format.clock: not a finite number: " .. tostring(ticks), 2)
  end
  local seconds = 0
  if ticks > 0 then
    seconds = math.ceil(ticks / 60)
  end
  local minutes = math.floor(seconds / 60)
  local rest = seconds - minutes * 60
  return string.format("%d:%02d", minutes, rest)
end

-- The bar of a row: the fraction left in [0, 1] and the band it falls in (normal, amber, red).
function M.bar(remaining_ticks, total_ticks)
  if not is_finite_number(remaining_ticks) then
    error("[comptoir] gui.format.bar: remaining_ticks must be a number, got " .. tostring(remaining_ticks), 2)
  end
  if not is_finite_number(total_ticks) or total_ticks <= 0 then
    return 0, "red"
  end
  local fraction = remaining_ticks / total_ticks
  if fraction < 0 then
    fraction = 0
  elseif fraction > 1 then
    fraction = 1
  end
  if fraction < M.BAR_RED then
    return fraction, "red"
  elseif fraction < M.BAR_AMBER then
    return fraction, "amber"
  end
  return fraction, "normal"
end

-- Digits only, or nil. A field that holds something else is a refusal, never a guess (the caller
-- decides: the window clamps to 1 and the button stays disabled).
function M.parse_quantity(text)
  if type(text) == "number" then
    return text
  end
  if type(text) ~= "string" then
    return nil
  end
  local digits = string.match(text, "^%s*(%d+)%s*$")
  if digits == nil then
    return nil
  end
  return tonumber(digits)
end

-- An integer in [1, min(ceiling, MAX_QUANTITY)]. `ceiling` is what the balance allows; anything that
-- is not a number counts as 0, which leaves the floor in place.
function M.clamp_quantity(value, ceiling)
  local maximum = M.MAX_QUANTITY
  if is_finite_number(ceiling) and ceiling < maximum then
    maximum = math.floor(ceiling)
  end
  if maximum < 1 then
    maximum = 1
  end

  local count = value
  if not is_finite_number(count) then
    count = 1
  end
  count = math.floor(count)
  if count < 1 then
    count = 1
  end
  if count > maximum then
    count = maximum
  end
  return count
end

-- What a preset writes into the field: 1, 10 or 100 as asked, a stack for "stack", always clamped to
-- what the balance allows (A24 — a preset larger than the balance displays the balance, not itself).
function M.preset_count(preset, stack_size, affordable)
  local wanted
  if preset == "stack" then
    wanted = stack_size
  else
    wanted = tonumber(preset)
  end
  if not is_finite_number(wanted) then
    error("[comptoir] gui.format.preset_count: unknown preset " .. tostring(preset), 2)
  end
  return M.clamp_quantity(wanted, affordable)
end

-- The catalogue in price order, cheapest first (docs/06 §3: the tab reads as a ladder). Ties are
-- broken by name so two clients list the same rows.
local price_order_cache = nil

function M.price_order()
  if price_order_cache ~= nil then
    return price_order_cache
  end
  local names = {}
  for name in pairs(prices.items) do
    names[#names + 1] = name
  end
  table.sort(names, function(left, right)
    local left_price = prices.items[left].price
    local right_price = prices.items[right].price
    if left_price ~= right_price then
      return left_price < right_price
    end
    return left < right
  end)
  price_order_cache = names
  return names
end

-- The item that stands for a group in the header icon: the cheapest one of that group, so the icon is
-- stable and recognisable without a single hand-drawn sprite (docs/06 §2, "the game's own sprite").
function M.group_item(group)
  for _, name in ipairs(M.price_order()) do
    if catalogue.items[name] == group then
      return name
    end
  end
  error("[comptoir] gui.format.group_item: no catalogue item in group " .. tostring(group), 2)
end

-- The two axes of a company shown on one line: the dominant group and the second one (ADR 0022 §2).
-- Deterministic: equal weights are broken by the sorted group name.
function M.character(company)
  if type(company) ~= "table" or type(company.weights) ~= "table" then
    error("[comptoir] gui.format.character: company.weights is required", 2)
  end
  local ranked = {}
  for _, group in ipairs(catalogue.groups) do
    ranked[#ranked + 1] = { group = group, weight = company.weights[group] or 0 }
  end
  table.sort(ranked, function(left, right)
    if left.weight ~= right.weight then
      return left.weight > right.weight
    end
    return left.group < right.group
  end)
  return ranked[1].group, ranked[2].group
end

-- The colour of a company, from its id. Same id, same colour, on every client, forever.
function M.colour_of(company_id)
  if not is_finite_number(company_id) or company_id % 1 ~= 0 or company_id < 1 then
    error("[comptoir] gui.format.colour_of: company_id must be a positive integer, got " .. tostring(company_id), 2)
  end
  local index = (company_id - 1) % #M.COLOURS + 1
  local colour = M.COLOURS[index]
  return { r = colour.r, g = colour.g, b = colour.b }
end

-- The texts of one contract row, ready to be captioned. The numbers are the contract's own; only the
-- time is read from the pair the caller passes (contracts.time_left), so the row shows what the
-- module says and nothing else.
function M.row_texts(contract, remaining_ticks, total_ticks)
  if type(contract) ~= "table" then
    error("[comptoir] gui.format.row_texts: contract is required", 2)
  end
  local fraction, band = M.bar(remaining_ticks or 0, total_ticks or 0)
  return {
    item = contract.item,
    quantity = M.grouped(contract.quantity),
    payout = M.grouped(contract.payout),
    reserve = M.grouped(contract.reserve),
    clock = M.clock(remaining_ticks or 0),
    fraction = fraction,
    band = band,
  }
end

return M
