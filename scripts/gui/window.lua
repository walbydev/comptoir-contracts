-- scripts/gui/window.lua — one frame, two tabs, and the three clicks that move the economy.
--
-- Description: the visual side of the counter. It draws the header (company, character, the two
--              numbers), the contract rows and the shop tab, and it turns a click on a named element
--              into one call on `scripts/contracts.lua` or `scripts/counter.lua`. It owns no rule:
--              every number it prints comes from the modules, every verdict it obeys comes from them
--              too (A22: a button is disabled because the module said the action would fail).
-- Author:      Philippe Ryf
-- Created:     2026-10-25
-- Revisions:   2026-10-25 — initial: frame, tabs, header, contract rows, shop tab (b1-b3)
--              2026-10-25 — b4: every live contract is a row. The "three slots plus one empty" display
--                           cap and the fixed extra placeholder are gone: the module caps the live
--                           contracts (ADR 0051), so the window draws what it is given and fills the
--                           rest with placeholders up to `offer_slots`
-- Usages:      required by control.lua, wired to on_gui_opened / on_gui_closed / on_gui_click /
--              on_gui_text_changed; the pure part lives in scripts/gui/format.lua
-- Notes:       THE WINDOW IS NOT TESTABLE HEADLESS (ADR 0050). The measured prerequisite is the
--              probe in `spike/gui-probe/`: setting `player.opened = nil` inside on_gui_opened, then
--              adding the frame to `player.gui.screen`, replaces the vanilla container frame. That is
--              the sequence below, and the close it causes itself bounces back as an on_gui_closed in
--              the same tick — that one is ignored, or the frame would destroy itself on sight.
--              NO on_tick. The rows are rebuilt when the window opens, when the tab changes, when a
--              preset is written and after every action; nothing is refreshed by a clock.
--              THE TAB AND THE QUANTITY ARE PER PLAYER AND NEVER IN `storage`: two local tables, lost
--              on reload on purpose (a window is not economy). The frame itself survives a save, so a
--              click on a window whose binding was lost destroys it and says so instead of guessing
--              which counter it belongs to.
--              THE WIDTH IS SET ONCE, at creation, and never written again: `style.width` pins both
--              minimal and maximal width, so a row that gains or loses content cannot move a button
--              sideways. The height follows the content, but the content is a bounded number of rows
--              per tab (at most `offer_slots` contract rows, sixteen shop rows), so nothing inside a
--              tab ever moves either: every live contract is a row and the missing ones are drawable
--              placeholders, up to `offer_slots` (ADR 0051 — the cap is the module's, the window has
--              no display limit of its own).
--              THE SHOP QUANTITY IS ONE NUMBER (docs/06 §6). A shared field cannot be clamped per
--              row, because sixteen rows would need sixteen different ceilings; it is therefore
--              clamped to the ceiling of the CHEAPEST catalogue item, which is the loosest bound any
--              row can honour (never blocking a purchase the cooperative can pay for), and each row's
--              BUY is disabled the moment the displayed number exceeds that row's own ceiling. A24 is
--              satisfied where it is measurable: no clickable quantity is above what the balance
--              allows for the row being clicked.
--              NO STYLING (mission lot b): no style prototype, no animation, no icon of our own. The
--              only geometry set is the width of a label, the size of the item sprites, and the
--              colour of the character line (ADR 0022 asks for a colour per company).
-- Licence:     MIT (see LICENSE)

local format = require("__comptoir-contracts__/scripts/gui/format")
local companies = require("__comptoir-contracts__/scripts/companies")
local contracts = require("__comptoir-contracts__/scripts/contracts")
local counter = require("__comptoir-contracts__/scripts/counter")
local ledger = require("__comptoir-contracts__/scripts/ledger")
local balance = require("__comptoir-contracts__/config/balance")

local M = {}

M.API_VERSION = 1

local COUNTER = "comptoir-counter"

-- Names. Stable on purpose: an element is found by name after a reload, when no Lua table survived.
local ROOT = "comptoir_root"
local HEADER = "comptoir_header"
local HEADER_LINE = "comptoir_header_line"
local HEADER_COMPANY = "comptoir_header_company"
local HEADER_CHARACTER = "comptoir_header_character"
local HEADER_ICON = "comptoir_header_icon"
local HEADER_TEXT = "comptoir_header_text"
local HEADER_NUMBERS = "comptoir_header_numbers"
local HEADER_AVAILABLE = "comptoir_header_available"
local HEADER_RESERVED = "comptoir_header_reserved"
local TABS = "comptoir_tabs"
local TAB_CONTRACTS = "ct_tab_contracts"
local TAB_SHOP = "ct_tab_shop"
local BODY_CONTRACTS = "comptoir_body_contracts"
local BODY_SHOP = "comptoir_body_shop"
local QUANTITY_LINE = "comptoir_quantity_line"
local QUANTITY_FIELD = "counter-quantity-field"
local QUANTITY_LABEL = "comptoir_quantity_label"

-- How many rows the contract tab closes with when a company holds nothing: the cap the module enforces
-- on live contracts (ADR 0051). The window never slices the list to it — every live contract is drawn.
local CONTRACT_SLOTS = balance.contracts.offer_slots

-- Geometry. Widths only, and only where a column must line up (mission: ugly but correct).
local WIDTH = 640
local HALF = 300
local ROW_HEIGHT = 48
local SHOP_ROW_HEIGHT = 28
local COL_ITEM = 280
local COL_TIME = 180
local COL_ACTION = 110
local COL_PRICE = 90
local COL_CREDITS = 100
local BAR_WIDTH = 100
local FIELD_WIDTH = 80

-- Per player, never in `storage`: the tab shown, the number in the shop field, and the hub the window
-- is bound to. Lost on reload, rebuilt by reopening the counter.
local tabs = {}
local quantities = {}
local windows = {}

-- The tick at which this module closed a GUI itself (`player.opened = nil`). That close can come back
-- as an on_gui_closed in the same tick; ignoring it is what keeps the frame on screen (ADR 0050).
local self_closed_tick = {}

-- Every reason a module can hand back, so `locale/*/strings.cfg` can be audited against one list
-- instead of against a grep of the call sites. A reason that is not here still prints (as its key):
-- a missing translation is a failure to see, never a silent fallback (A21).
M.REASONS = {
  "unknown_contract",
  "not_offered",
  "no_free_slot",
  "escrow_unavailable",
  "not_accepted",
  "in_flight",
  "unknown_state",
  "no_hub",
  "no_entity",
  "no_inventory",
  "not_enough_stock",
  "stock_changed",
  "flight_in_progress",
  "elevator_rising",
  "elevator_away",
  "elevator_descending",
  "insufficient_credits",
  "nothing_to_trade",
  "empty_pool",
  "no_room",
  "payment_refused",
  "no_stock",
  "shop_cannot_pay",
  "bad_count",
  "unknown_action",
}

-- The cheapest item of the catalogue: the ceiling the shared quantity field is clamped to.
local CHEAPEST = format.price_order()[1]

-- ---------------------------------------------------------------------------------------------------
-- Elements
-- ---------------------------------------------------------------------------------------------------

local function child_named(parent, name)
  if parent == nil or parent.valid == false then
    return nil
  end
  for _, element in ipairs(parent.children) do
    if element.name == name then
      return element
    end
  end
  return nil
end

local function root_of(player)
  local root = player.gui.screen[ROOT]
  if root ~= nil and root.valid then
    return root
  end
  return nil
end

local function destroy(player)
  local root = root_of(player)
  if root ~= nil then
    root.destroy()
  end
end

local function clear(parent)
  if parent == nil or parent.valid == false then
    return
  end
  for index = #parent.children, 1, -1 do
    parent.children[index].destroy()
  end
end

-- The click belongs to us when one of its ancestors is our root. Without this, a click on the vanilla
-- inventory would be read by this module. The walk stops on the first object that has no `parent`
-- (the screen itself) — `pcall` because a GUI container is not a GUI element and does not answer every
-- key an element does.
local function is_ours(element)
  local node = element
  for _ = 1, 16 do
    if node == nil then
      return false
    end
    local named, name = pcall(function()
      return node.name
    end)
    if named and name == ROOT then
      return true
    end
    local fetched, parent = pcall(function()
      return node.parent
    end)
    if not fetched or parent == nil then
      return false
    end
    node = parent
  end
  return false
end

local function icon(parent, name, item, size)
  local sprite = parent.add({ type = "sprite", name = name, sprite = "item/" .. item })
  sprite.resize_to_sprite = false
  sprite.style.width = size
  sprite.style.height = size
  return sprite
end

-- ---------------------------------------------------------------------------------------------------
-- The frame: built once per open, never resized afterwards
-- ---------------------------------------------------------------------------------------------------

local function build(player)
  local root = player.gui.screen.add({
    type = "frame",
    name = ROOT,
    direction = "vertical",
    caption = { "entity-name.comptoir-counter" },
  })
  -- Written exactly once in the life of the frame (docs/06 §1: the header never moves).
  root.style.width = WIDTH

  local header = root.add({ type = "flow", name = HEADER, direction = "vertical" })

  local line = header.add({ type = "flow", name = HEADER_LINE, direction = "horizontal" })
  local company = line.add({ type = "label", name = HEADER_COMPANY, caption = "" })
  company.style.width = COL_ITEM + 40

  local character = line.add({ type = "flow", name = HEADER_CHARACTER, direction = "horizontal" })
  icon(character, HEADER_ICON, CHEAPEST, 20)
  local text = character.add({ type = "label", name = HEADER_TEXT, caption = "" })
  text.style.single_line = true

  local numbers = header.add({ type = "flow", name = HEADER_NUMBERS, direction = "horizontal" })
  local available = numbers.add({ type = "label", name = HEADER_AVAILABLE, caption = "" })
  available.style.width = HALF
  available.style.horizontal_align = "right"
  local reserved = numbers.add({ type = "label", name = HEADER_RESERVED, caption = "" })
  reserved.style.width = HALF
  reserved.style.horizontal_align = "right"

  local tabbar = root.add({ type = "flow", name = TABS, direction = "horizontal" })
  tabbar.add({ type = "button", name = TAB_CONTRACTS, caption = { "comptoir-tab-contracts" } })
  tabbar.add({ type = "button", name = TAB_SHOP, caption = { "comptoir-tab-shop" } })

  root.add({ type = "flow", name = BODY_CONTRACTS, direction = "vertical" })
  root.add({ type = "flow", name = BODY_SHOP, direction = "vertical" })

  return root
end

-- ---------------------------------------------------------------------------------------------------
-- Reads: the state behind the window
-- ---------------------------------------------------------------------------------------------------

-- The hub and the economy a window belongs to. nil means the binding is gone: the counter was
-- deconstructed or the save reloaded without the per-player tables.
local function context(storage, window)
  if window == nil or storage == nil or storage.hubs == nil then
    return nil
  end
  local hub = storage.hubs[window.unit_number]
  if hub == nil then
    return nil
  end
  local state = storage.forces and storage.forces[hub.force_index]
  if state == nil then
    return nil
  end
  local company = state.companies[hub.company_id]
  if company == nil then
    return nil
  end
  return {
    hub = hub,
    state = state,
    company = company,
    force_index = hub.force_index,
    entity = companies.hub_entity(hub),
  }
end

local function quantity_of(player_index)
  return quantities[player_index] or 1
end

-- The two gates of a shop row, computed once and used both when drawing and while typing (A22).
local function shop_gates(ctx, item, quantity)
  local buy = quantity >= 1 and quantity <= counter.affordable(ctx.state, item)
  local sellable = counter.sellable(ctx.company, ctx.entity, item)
  local sell = quantity >= 1 and quantity <= sellable
  return buy, sell
end

-- ---------------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------------

local function draw_contract_row(body, contract, ctx, storage, tick)
  local row = body.add({ type = "flow", name = "contracts-" .. contract.id .. "-row", direction = "horizontal" })
  row.style.height = ROW_HEIGHT

  icon(row, "contracts-" .. contract.id .. "-icon", contract.item, 32)

  local left = row.add({ type = "flow", direction = "vertical" })
  left.style.width = COL_ITEM
  local texts = format.row_texts(contract, contracts.time_left(contract, tick))
  left.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-quantity",
    caption = { "comptoir-quantity-of", texts.quantity, { "item-name." .. contract.item } },
  })
  left.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-reserve",
    caption = { "comptoir-reserve", texts.reserve },
  })

  local right = row.add({ type = "flow", direction = "vertical" })
  right.style.width = COL_TIME
  right.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-payout",
    caption = { "comptoir-money", texts.payout },
  })
  local timeline = right.add({ type = "flow", direction = "horizontal" })
  local bar = timeline.add({ type = "progressbar", name = "contracts-" .. contract.id .. "-bar", value = texts.fraction })
  bar.style.width = BAR_WIDTH
  timeline.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-time",
    caption = texts.clock,
  })

  -- The one contextual button of the row (docs/06 §2). Its verdict is the module's (A22).
  local action, allowed, _, stock = contracts.action_of(ctx.state, storage, ctx.force_index, ctx.company, contract)
  local button = row.add({ type = "button", name = "contracts-" .. contract.id .. "-action", caption = "" })
  button.style.width = COL_ACTION
  if action == "accept" then
    button.caption = { "comptoir-action-accept" }
    button.enabled = allowed == true
  elseif contract.state == contracts.IN_FLIGHT then
    button.caption = { "comptoir-action-in-flight" }
    button.enabled = false
  else
    -- How many the counter holds of what the contract asks for, capped at the quantity: a number above
    -- the order would announce a delivery that cannot happen.
    local count = math.min(stock or 0, contract.quantity)
    button.caption = { "comptoir-action-dispatch", format.grouped(count) }
    button.enabled = allowed == true
  end
  return row
end

local function draw_empty_slot(body, slot)
  local row = body.add({ type = "flow", name = "contracts-slot-" .. slot .. "-empty", direction = "horizontal" })
  row.style.height = ROW_HEIGHT
  row.add({ type = "label", name = "contracts-slot-" .. slot .. "-empty-label", caption = { "comptoir-empty-slot" } })
  return row
end

local function draw_shop_row(body, item, ctx, quantity)
  local quote = counter.quote(item)
  local row = body.add({ type = "flow", name = "counter-" .. item .. "-row", direction = "horizontal" })
  row.style.height = SHOP_ROW_HEIGHT

  icon(row, "counter-" .. item .. "-icon", item, 20)

  local name = row.add({ type = "label", name = "counter-" .. item .. "-name", caption = { "item-name." .. item } })
  name.style.width = COL_ITEM

  local price = row.add({ type = "label", name = "counter-" .. item .. "-price", caption = { "comptoir-money", format.grouped(quote.buy_price) } })
  price.style.width = COL_PRICE
  price.style.horizontal_align = "right"

  local credits = row.add({ type = "label", name = "counter-" .. item .. "-buy-back", caption = { "comptoir-buy-back", format.grouped(quote.sell_credits) } })
  credits.style.width = COL_CREDITS
  credits.style.horizontal_align = "right"

  local buy_enabled, sell_enabled = shop_gates(ctx, item, quantity)
  local buy = row.add({ type = "button", name = "counter-" .. item .. "-buy", caption = { "comptoir-buy" } })
  buy.enabled = buy_enabled
  local sell = row.add({ type = "button", name = "counter-" .. item .. "-sell", caption = { "comptoir-sell" } })
  sell.enabled = sell_enabled
  return row
end

local function draw_shop(body, ctx, player)
  local quantity = quantity_of(player.index)

  local line = body.add({ type = "flow", name = QUANTITY_LINE, direction = "horizontal" })
  line.add({ type = "label", name = QUANTITY_LABEL, caption = { "comptoir-quantity-label" } })
  local field = line.add({ type = "textfield", name = QUANTITY_FIELD, text = tostring(quantity), numeric = true })
  field.style.width = FIELD_WIDTH
  for _, preset in ipairs({ "1", "10", "100", "stack" }) do
    local button = line.add({ type = "button", name = "counter-quantity-" .. preset, caption = "" })
    if preset == "stack" then
      button.caption = { "comptoir-preset-stack" }
    else
      button.caption = preset
    end
  end

  for _, item in ipairs(format.price_order()) do
    draw_shop_row(body, item, ctx, quantity)
  end
end

local function render(storage, player, window)
  local ctx = context(storage, window)
  if ctx == nil then
    destroy(player)
    windows[player.index] = nil
    return
  end

  local root = root_of(player)
  if root == nil then
    root = build(player)
  end
  local tick = game.tick

  -- Header: the company, its character, then the two numbers (A19: available + reserved = total).
  local header = child_named(root, HEADER)
  local line = child_named(header, HEADER_LINE)
  child_named(line, HEADER_COMPANY).caption = ctx.company.name

  local character = child_named(line, HEADER_CHARACTER)
  local primary, secondary = format.character(ctx.company)
  local text = child_named(character, HEADER_TEXT)
  text.caption = { "comptoir-character", { "comptoir-group-" .. primary }, { "comptoir-group-" .. secondary } }
  text.style.font_color = format.colour_of(ctx.company.id)
  child_named(character, HEADER_ICON).sprite = "item/" .. format.group_item(primary)

  local numbers = child_named(header, HEADER_NUMBERS)
  child_named(numbers, HEADER_AVAILABLE).caption = { "comptoir-available", format.grouped(ledger.available(ctx.state)) }
  child_named(numbers, HEADER_RESERVED).caption = { "comptoir-reserved", format.grouped(ctx.state.reserved) }

  -- Tabs: the active one is disabled, which is the whole of "the active tab reads as active" without
  -- a style (mission: no styling).
  local tab = tabs[player.index] or TAB_CONTRACTS
  local tabbar = child_named(root, TABS)
  local contracts_tab = child_named(tabbar, TAB_CONTRACTS)
  local shop_tab = child_named(tabbar, TAB_SHOP)
  contracts_tab.enabled = tab ~= TAB_CONTRACTS
  shop_tab.enabled = tab ~= TAB_SHOP

  local contract_body = child_named(root, BODY_CONTRACTS)
  local shop_body = child_named(root, BODY_SHOP)
  contract_body.visible = tab == TAB_CONTRACTS
  shop_body.visible = tab == TAB_SHOP

  if tab == TAB_CONTRACTS then
    clear(contract_body)
    -- Every live contract is a row (ADR 0051). The cap of `offer_slots` is enforced by the module, so
    -- this loop never has to drop one; the placeholders close the tab to a constant height when the
    -- company holds fewer than the cap. A save that carries more than the cap (edited, or written by
    -- an older build) is drawn in full — hiding a row would make its contract impossible to dispatch,
    -- which is exactly what the display cap used to do.
    local live = contracts.live(ctx.company)
    for _, contract in ipairs(live) do
      draw_contract_row(contract_body, contract, ctx, storage, tick)
    end
    for slot = #live + 1, CONTRACT_SLOTS do
      draw_empty_slot(contract_body, slot)
    end
  else
    clear(shop_body)
    draw_shop(shop_body, ctx, player)
  end
end

local function refresh(storage, player)
  local window = windows[player.index]
  if window == nil then
    return
  end
  local force = player.force
  if force ~= nil then
    -- Settle first: what the window draws is what is true now (design.md §3, never a clock).
    contracts.settle(storage, force, game.tick)
  end
  render(storage, player, window)
end

-- ---------------------------------------------------------------------------------------------------
-- Openers, closers, clicks
-- ---------------------------------------------------------------------------------------------------

function M.on_opened(storage, event)
  local entity = event.entity
  if entity == nil or entity.valid == false then
    return
  end
  if entity.name ~= COUNTER then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil or player.valid == false then
    return
  end
  -- A counter of another force is not ours to open: the vanilla container frame stays, and that is a
  -- reading of the rules, not a failure.
  if entity.force ~= nil and entity.force.index ~= player.force.index then
    return
  end
  local hub = storage.hubs and storage.hubs[entity.unit_number]
  if hub == nil then
    -- No company behind this counter yet: leave the container in place rather than draw a window with
    -- nothing to say.
    return
  end

  self_closed_tick[event.player_index] = game.tick
  destroy(player)
  -- The measured prerequisite (ADR 0050): the engine has just opened the container; this takes it
  -- away, and the frame below is the only thing left on screen.
  player.opened = nil

  windows[event.player_index] = { unit_number = entity.unit_number, force_index = hub.force_index }
  refresh(storage, player)
end

function M.on_closed(storage, event)
  if self_closed_tick[event.player_index] == game.tick then
    self_closed_tick[event.player_index] = nil
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    windows[event.player_index] = nil
    return
  end
  destroy(player)
  windows[event.player_index] = nil
end

-- A refused action says why, in the player's language, from one key per reason.
local function refuse(player, reason)
  if reason == nil then
    return
  end
  player.print({ "comptoir-refused", { "comptoir-reason-" .. reason } })
end

local function accept(storage, player, ctx, contract_id)
  local tick = game.tick
  local ok, reason = contracts.accept(ctx.state, player.force, ctx.company, contract_id, tick)
  if not ok then
    refuse(player, reason)
  end
  refresh(storage, player)
end

local function dispatch(storage, player, ctx, contract_id)
  local tick = game.tick
  local ok, reason = contracts.dispatch(ctx.state, storage, ctx.force_index, ctx.company, contract_id, tick)
  if not ok then
    refuse(player, reason)
  end
  refresh(storage, player)
end

local function trade(storage, player, ctx, item, action_name)
  local quantity = quantity_of(player.index)
  local trade_fn = counter[action_name]
  local ok, reason, count, total = trade_fn(ctx.state, ctx.company, ctx.entity, item, quantity)
  if ok then
    player.print({
      action_name == "buy" and "comptoir-bought" or "comptoir-sold",
      format.grouped(count),
      { "comptoir-money", format.grouped(total) },
    })
  else
    refuse(player, reason)
  end
  refresh(storage, player)
end

local function apply_preset(storage, player, ctx, preset)
  local stack_size = 1
  local prototype = prototypes.item[CHEAPEST]
  if prototype ~= nil then
    stack_size = prototype.stack_size
  end
  quantities[player.index] = format.preset_count(preset, stack_size, counter.affordable(ctx.state, CHEAPEST))
  refresh(storage, player)
end

-- While the player types, the clamp is applied to the field itself and the two buttons of each row are
-- re-gated: no click can be prepared above what the balance allows (A22, A24). The rows are not
-- rebuilt — that would take the focus out of the field the player is typing in.
local function regate(root, ctx, player, quantity)
  local body = child_named(root, BODY_SHOP)
  if body == nil or body.valid == false then
    return
  end
  for _, item in ipairs(format.price_order()) do
    local buy = child_named(body, "counter-" .. item .. "-buy")
    local sell = child_named(body, "counter-" .. item .. "-sell")
    if buy ~= nil or sell ~= nil then
      local buy_enabled, sell_enabled = shop_gates(ctx, item, quantity)
      if buy ~= nil then
        buy.enabled = buy_enabled
      end
      if sell ~= nil then
        sell.enabled = sell_enabled
      end
    end
  end
end

function M.on_text_changed(storage, event)
  local element = event.element
  if element == nil or element.valid == false then
    return
  end
  if element.name ~= QUANTITY_FIELD then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  local ctx = context(storage, windows[event.player_index])
  if ctx == nil then
    destroy(player)
    windows[event.player_index] = nil
    return
  end

  local ceiling = counter.affordable(ctx.state, CHEAPEST)
  local parsed = format.parse_quantity(event.text)
  local clamped = format.clamp_quantity(parsed, ceiling)
  quantities[event.player_index] = clamped
  local shown = tostring(clamped)
  if element.text ~= shown then
    element.text = shown
  end
  regate(root_of(player), ctx, player, clamped)
end

function M.on_click(storage, event)
  local element = event.element
  if element == nil or element.valid == false then
    return
  end
  if is_ours(element) ~= true then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  local ctx = context(storage, windows[event.player_index])
  if ctx == nil then
    -- The frame outlived its binding (a save reloaded, or the counter was deconstructed): close it and
    -- say so rather than act on a counter we can no longer identify.
    destroy(player)
    windows[event.player_index] = nil
    player.print({ "comptoir-stale-window" })
    return
  end

  local name = element.name
  if name == TAB_CONTRACTS or name == TAB_SHOP then
    tabs[event.player_index] = name
    refresh(storage, player)
    return
  end

  local preset = string.match(name, "^counter%-quantity%-(%w+)$")
  if preset ~= nil then
    apply_preset(storage, player, ctx, preset)
    return
  end

  local contract_id = tonumber(string.match(name, "^contracts%-(%d+)%-action$"))
  if contract_id ~= nil then
    local contract = ctx.company.contracts[contract_id]
    local action, allowed, reason = contracts.action_of(ctx.state, storage, ctx.force_index, ctx.company, contract)
    if allowed ~= true then
      -- The button should have been disabled; if a click still arrives, the module's reason is the
      -- answer and nothing moves (A22).
      refuse(player, reason)
      refresh(storage, player)
      return
    end
    if action == "accept" then
      accept(storage, player, ctx, contract_id)
    elseif action == "dispatch" then
      dispatch(storage, player, ctx, contract_id)
    else
      refuse(player, "unknown_action")
      refresh(storage, player)
    end
    return
  end

  local item, trade_name = string.match(name, "^counter%-(.+)%-(buy|sell)$")
  if item ~= nil then
    trade(storage, player, ctx, item, trade_name)
    return
  end
end

return M
