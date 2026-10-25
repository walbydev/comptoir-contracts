-- scripts/ledger.lua — the arithmetic of money, and nothing else.
--
-- Description: moves integer credits between the three holders of an economy — the cooperative, the
--              companies and the federation — and refuses every move that would break conservation
--              or drive a holder below zero. It knows no contract, no build and no GUI: it takes a
--              force's economy record and integers (design.md §1).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: hold, release, forfeit, debit, credit, assert_conservation
-- Usages:      required by control.lua; called by scripts/companies.lua and scripts/contracts.lua
-- Notes:       THE THREE HOLDERS. The cooperative (the player's pot), the companies (what a hub can
--              pay with) and the federation (the issuer). Only the federation may hold a negative
--              balance: it created the endowment out of nothing, so its account is the mirror of
--              every credit in circulation and the sum of the three stays constant forever (ADR
--              0012/0041). `supply` records that constant, so a bug cannot be absorbed silently.
--              INTEGERS ONLY (D7): every amount is checked, and a float that happens to be whole is
--              accepted only because `n % 1 == 0` proves it is.
--              `reserved` is not money of its own: it is a part of `cooperative` promised to an
--              accepted contract. It is excluded from spending while it is held, and `forfeit` turns
--              it into real money in a company's hands. `reserved` is part of `cooperative`, so it
--              never enters the conservation sum.
--              Every mutation ends with `assert_conservation`: a silent imbalance is worse than a
--              crash, because a crash can be read.
-- Licence:     MIT (see LICENSE)

local M = {}

M.API_VERSION = 1

local COOPERATIVE = "cooperative"
local FEDERATION = "federation"
local COMPANY_PREFIX = "company:"

M.COOPERATIVE = COOPERATIVE
M.FEDERATION = FEDERATION

-- The account reference of one company, e.g. `ledger.company(3)` -> "company:3". References are
-- plain strings so a caller can log them as they are.
function M.company(id)
  if type(id) ~= "number" or id % 1 ~= 0 then
    error("[comptoir] ledger.company: id must be an integer, got " .. tostring(id), 2)
  end
  return COMPANY_PREFIX .. id
end

local function is_integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

local function check_integer(value, where)
  if not is_integer(value) then
    error("[comptoir] ledger." .. where .. ": amount must be an integer, got " .. tostring(value), 3)
  end
  if value < 0 then
    error("[comptoir] ledger." .. where .. ": amount must not be negative, got " .. tostring(value), 3)
  end
end

-- "company:3" -> 3, anything else -> nil. Kept private: callers use M.company to build a reference.
local function company_id_of(reference)
  if type(reference) ~= "string" then
    return nil
  end
  local digits = string.match(reference, "^company:(%d+)$")
  if digits == nil then
    return nil
  end
  return tonumber(digits)
end

local function balance_of(state, reference)
  if reference == COOPERATIVE then
    return state.cooperative
  elseif reference == FEDERATION then
    return state.federation
  end
  local id = company_id_of(reference)
  if id == nil then
    error("[comptoir] ledger: unknown account " .. tostring(reference), 3)
  end
  local company = state.companies[id]
  if company == nil then
    error("[comptoir] ledger: unknown company " .. tostring(id), 3)
  end
  return company.balance
end

local function add_to(state, reference, delta)
  if reference == COOPERATIVE then
    state.cooperative = state.cooperative + delta
    return
  elseif reference == FEDERATION then
    state.federation = state.federation + delta
    return
  end
  local id = company_id_of(reference)
  state.companies[id].balance = state.companies[id].balance + delta
end

-- The sum of every balance. For information and for tests; `assert_conservation` is the guard.
function M.total(state)
  local total = state.cooperative + state.federation
  local ids = {}
  for id in pairs(state.companies) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    total = total + state.companies[id].balance
  end
  return total
end

-- Credits the cooperative can still spend: what it holds minus what its accepted contracts reserve.
function M.available(state)
  return state.cooperative - state.reserved
end

function M.balance(state, reference)
  return balance_of(state, reference)
end

-- The guard. Raises with the exact figures, because "conservation broken" without numbers is a
-- riddle: the caller must be able to see which holder moved.
function M.assert_conservation(state, context)
  local where = context or "unspecified"

  local fields = { "cooperative", "federation", "reserved", "supply" }
  for _, field in ipairs(fields) do
    if not is_integer(state[field]) then
      error(
        "[comptoir] ledger (" .. where .. "): " .. field .. " must be an integer, got " .. tostring(state[field]),
        2
      )
    end
  end
  if state.companies == nil then
    error("[comptoir] ledger (" .. where .. "): no companies table", 2)
  end
  if state.cooperative < 0 then
    error("[comptoir] ledger (" .. where .. "): cooperative is negative (" .. tostring(state.cooperative) .. ")", 2)
  end
  if state.reserved < 0 then
    error("[comptoir] ledger (" .. where .. "): reserved is negative (" .. tostring(state.reserved) .. ")", 2)
  end
  if state.reserved > state.cooperative then
    error(
      "[comptoir] ledger (" .. where .. "): reserved (" .. tostring(state.reserved) .. ") exceeds cooperative ("
        .. tostring(state.cooperative) .. ")",
      2
    )
  end

  local ids = {}
  for id in pairs(state.companies) do
    ids[#ids + 1] = id
  end
  table.sort(ids)

  local sum = state.cooperative + state.federation
  for _, id in ipairs(ids) do
    local company = state.companies[id]
    if not is_integer(company.balance) then
      error(
        "[comptoir] ledger (" .. where .. "): company " .. tostring(id) .. " has a non-integer balance "
          .. tostring(company.balance),
        2
      )
    end
    if company.balance < 0 then
      error(
        "[comptoir] ledger (" .. where .. "): company " .. tostring(id) .. " has a negative balance ("
          .. tostring(company.balance) .. "); only the federation may go below zero",
        2
      )
    end
    sum = sum + company.balance
  end

  if sum ~= state.supply then
    error(
      "[comptoir] ledger (" .. where .. "): conservation broken — cooperative "
        .. tostring(state.cooperative) .. " + federation " .. tostring(state.federation) .. " + companies "
        .. tostring(sum - state.cooperative - state.federation) .. " = " .. tostring(sum) .. ", expected supply "
        .. tostring(state.supply),
      2
    )
  end
  return sum
end

-- A fresh economy for one force: the federation issues the endowment to the cooperative, so its own
-- balance is the negative mirror of it and `supply` stays zero.
function M.new_force(endowment)
  check_integer(endowment, "new_force")
  local state = {
    cooperative = 0,
    reserved = 0,
    federation = 0,
    supply = 0,
    next_company_id = 1,
    companies = {},
  }
  if endowment > 0 then
    M.transfer(state, FEDERATION, COOPERATIVE, endowment)
  end
  M.assert_conservation(state, "new_force")
  return state
end

-- Register a company record. Balances are the ledger's business, so a record enters with a zero
-- balance and the ledger validates the id before anything can point at it.
function M.register_company(state, record)
  if record == nil then
    error("[comptoir] ledger.register_company: no record", 2)
  end
  if not is_integer(record.id) or record.id < 1 then
    error("[comptoir] ledger.register_company: id must be a positive integer, got " .. tostring(record.id), 2)
  end
  if state.companies[record.id] ~= nil then
    error("[comptoir] ledger.register_company: company " .. tostring(record.id) .. " already exists", 2)
  end
  if not is_integer(record.balance) then
    error("[comptoir] ledger.register_company: balance must be an integer, got " .. tostring(record.balance), 2)
  end
  if record.balance < 0 then
    error("[comptoir] ledger.register_company: a company cannot be born in debt", 2)
  end
  state.companies[record.id] = record
  M.assert_conservation(state, "register_company")
  return record
end

-- The single mutation of the module: `amount` leaves `from` and reaches `to`. The order of the two
-- references is always (source, destination), so `debit` and `credit` cannot be called with the
-- arguments swapped by mistake — they read the same move from the two ends.
local function move(state, from, to, amount, label)
  check_integer(amount, label)
  if from == to then
    error("[comptoir] ledger." .. label .. ": source and destination are both " .. tostring(from), 3)
  end

  local source = balance_of(state, from)
  balance_of(state, to) -- validates the destination before anything is written

  if from ~= FEDERATION and source - amount < 0 then
    error(
      "[comptoir] ledger." .. label .. ": " .. tostring(from) .. " has " .. tostring(source)
        .. " credits and cannot pay " .. tostring(amount) .. "; only the federation may go below zero",
      3
    )
  end
  if from == COOPERATIVE and state.cooperative - state.reserved - amount < 0 then
    error(
      "[comptoir] ledger." .. label .. ": " .. tostring(amount) .. " credits are not available — cooperative "
        .. tostring(state.cooperative) .. ", reserved " .. tostring(state.reserved) .. ", available "
        .. tostring(state.cooperative - state.reserved),
      3
    )
  end

  add_to(state, from, -amount)
  add_to(state, to, amount)
  M.assert_conservation(state, label .. " " .. tostring(from) .. " -> " .. tostring(to))
end

-- `debit`: the money leaves the source. `credit`: the same move, read from the side that receives it.
-- Same signature on purpose: (state, source, destination, amount).
function M.debit(state, from, to, amount)
  move(state, from, to, amount, "debit")
end

function M.credit(state, from, to, amount)
  move(state, from, to, amount, "credit")
end

function M.transfer(state, from, to, amount)
  move(state, from, to, amount, "transfer")
end

-- Promise `amount` credits of the cooperative to an accepted contract: the money stays where it is,
-- it just stops being spendable (ADR 0027).
function M.hold(state, amount)
  check_integer(amount, "hold")
  local available = M.available(state)
  if amount > available then
    error(
      "[comptoir] ledger.hold: not enough available credits — available " .. tostring(available) .. ", asked "
        .. tostring(amount),
      2
    )
  end
  state.reserved = state.reserved + amount
  M.assert_conservation(state, "hold")
  return state.reserved
end

-- Give the promise back (delivery, or an abandoned contract the player is allowed to abandon).
function M.release(state, amount)
  check_integer(amount, "release")
  if amount > state.reserved then
    error(
      "[comptoir] ledger.release: cannot release " .. tostring(amount) .. " credits, only " .. tostring(state.reserved)
        .. " are reserved",
      2
    )
  end
  state.reserved = state.reserved - amount
  M.assert_conservation(state, "release")
  return state.reserved
end

-- The reserve of a failed contract becomes real money for the company that offered it (A13, ADR 0027).
function M.forfeit(state, amount, company_id)
  check_integer(amount, "forfeit")
  if amount > state.reserved then
    error(
      "[comptoir] ledger.forfeit: cannot forfeit " .. tostring(amount) .. " credits, only " .. tostring(state.reserved)
        .. " are reserved",
      2
    )
  end
  local company = state.companies[company_id]
  if company == nil then
    error("[comptoir] ledger.forfeit: unknown company " .. tostring(company_id), 2)
  end
  state.reserved = state.reserved - amount
  state.cooperative = state.cooperative - amount
  company.balance = company.balance + amount
  M.assert_conservation(state, "forfeit -> company " .. tostring(company_id))
  return company.balance
end

return M
