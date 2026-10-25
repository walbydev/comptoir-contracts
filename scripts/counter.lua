-- scripts/counter.lua — the shop of the counter: it sells at cost x 1.5, it buys back at cost.
--
-- Description: the only place where credits are spent (spec.md §1). It answers two questions — what
--              does this cost, what does this fetch — and performs the two moves: the cooperative pays
--              the company to buy, the company pays the cooperative to buy back. The counter's own
--              inventory is both the shelf and the collection bin, so every quantity is clamped to
--              what is really there and to what the buyer can really pay.
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: buy at price, sell at credits, quote, clamped quantities (a10)
-- Usages:      required by control.lua; called by the remote interface and, later, by the shop tab
-- Notes:       THE SHOP ALWAYS BUYS (D48, ADR 0028 §"the shop always buys"): with no contract active,
--              with nothing in reserve, at any time of day. It has no stock of its own and no price
--              condition — selling is the way back from a cooperative at zero, which is why the
--              buy-back price is `credits` and not `price` (docs/05-price-table.md §3: selling at the
--              shop price would print money, since `payout < price`).
--              The one limit is the company's own balance: the shop pays with the company's credits,
--              and a company without a line (`poor`) cannot pay for what it buys back. That is the
--              solvency dial of ADR 0015 working as designed, not the shop refusing a sale.
--              NEVER A NEGATIVE QUANTITY, NEVER A FREE ITEM (D7): counts are positive integers, the
--              amount actually traded is returned so the interface shows what happened, and the
--              credits are computed with integer arithmetic from the generated table.
--              NO SIDE STOCK. The shop does not keep goods: what is bought lands in the counter's
--              inventory (the same one a contract is filled from), what is sold leaves it. A full
--              counter therefore sells a purchase short — the returned count says so.
-- Licence:     MIT (see LICENSE)

local prices = require("__comptoir-contracts__/data/prices")
local ledger = require("__comptoir-contracts__/scripts/ledger")

local M = {}

M.API_VERSION = 1

local function is_integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function entry_of(item)
  local entry = prices.items[item]
  if entry == nil then
    error("[comptoir] counter: " .. tostring(item) .. " is not in the price table", 3)
  end
  return entry
end

-- What the shop shows before anything happens (A4): one row, two prices, no hidden condition.
function M.quote(item)
  local entry = entry_of(item)
  return {
    item = item,
    buy_price = entry.price,
    sell_credits = entry.credits,
    payout = entry.payout,
    tier = entry.tier,
  }
end

function M.inventory_of(entity)
  if entity == nil or entity.valid == false then
    return nil
  end
  return entity.get_inventory(defines.inventory.chest)
end

-- Clamp a requested count to what the caller asked, the money available and (for a sale) the stock.
local function clamp_count(count, ceiling)
  if not is_integer(count) or count < 1 then
    return nil, "bad_count"
  end
  if ceiling < 1 then
    return nil, "nothing_to_trade"
  end
  if count > ceiling then
    return ceiling
  end
  return count
end

-- The cooperative buys `count` units: the money goes to the company, the goods land in the counter.
-- Returns ok, reason, traded_count, total_credits.
function M.buy(state, company, entity, item, count)
  if state == nil or company == nil then
    error("[comptoir] counter.buy: state and company are required", 2)
  end
  local entry = entry_of(item)
  local inventory = M.inventory_of(entity)
  if inventory == nil then
    return false, "no_inventory", 0, 0
  end

  local affordable = math.floor(ledger.available(state) / entry.price)
  local wanted, reason = clamp_count(count, affordable)
  if wanted == nil then
    if reason == "nothing_to_trade" then
      reason = "insufficient_credits"
    end
    return false, reason, 0, 0
  end

  local inserted = inventory.insert({ name = item, count = wanted })
  if inserted == 0 then
    return false, "no_room", 0, 0
  end

  local total = inserted * entry.price
  local ok = pcall(ledger.transfer, state, ledger.COOPERATIVE, ledger.company(company.id), total)
  if not ok then
    -- The available amount was checked above; reaching this line means the ledger moved under us.
    inventory.remove({ name = item, count = inserted })
    return false, "payment_refused", 0, 0
  end
  return true, nil, inserted, total
end

-- The company buys `count` units back: the goods leave the counter, the cooperative is credited.
-- The only ceiling on the quantity is the stock and the company's balance.
-- Returns ok, reason, traded_count, total_credits.
function M.sell(state, company, entity, item, count)
  if state == nil or company == nil then
    error("[comptoir] counter.sell: state and company are required", 2)
  end
  local entry = entry_of(item)
  local inventory = M.inventory_of(entity)
  if inventory == nil then
    return false, "no_inventory", 0, 0
  end

  local stock = inventory.get_item_count(item)
  local payable = math.floor(company.balance / entry.credits)
  local ceiling = math.min(stock, payable)
  local wanted, reason = clamp_count(count, ceiling)
  if wanted == nil then
    if reason == "nothing_to_trade" then
      if stock < 1 then
        reason = "no_stock"
      else
        -- D48: the shop does not refuse, the company cannot pay. Same distinction as in the log.
        reason = "shop_cannot_pay"
      end
    end
    return false, reason, 0, 0
  end

  local removed = inventory.remove({ name = item, count = wanted })
  if removed < 1 then
    return false, "no_stock", 0, 0
  end

  local total = removed * entry.credits
  local ok = pcall(ledger.transfer, state, ledger.company(company.id), ledger.COOPERATIVE, total)
  if not ok then
    inventory.insert({ name = item, count = removed })
    return false, "shop_cannot_pay", 0, 0
  end
  return true, nil, removed, total
end

return M
