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
--              2026-10-25 — lot b regression: every caption was a bare key (`{"comptoir-available"}`)
--                           while the strings sat under `[comptoir]` with their prefix still on them,
--                           so the engine resolved nothing and the window read "Unknown key" from top
--                           to bottom. Captions are now `{"comptoir.<key>"}`, the reason and group
--                           keys are literals in `REASON_KEYS` / `GROUP_KEYS` instead of
--                           concatenations, and `tools/check_locale.py` refuses the old shape at
--                           `make check` (ADR 0053)
--              2026-10-25 — A20: every row is the exact sum of its cells. Fixed widths on the prices,
--                           the buttons and the tabs; pinned labels (`single_line`, `maximal_width`)
--                           for the names and the figures; explicit `horizontal_spacing`; frame width
--                           = `ROW_WIDTH` + 2 x `PADDING`. The sums are asserted at load and proved
--                           by scenario B1-gui-pure from `M.GEOMETRY`
--              2026-10-25 — ADR 0056 §2/§3: a header row for the car (down / rising / away /
--                           descending + the remaining time), the three actions disabled while it is not
--                           down with the reason and the countdown on the button, one feedback row under
--                           the tabs rewritten by every action, and ONE bounded `on_nth_tick(30)` that
--                           starts with the first window and stops with the last
-- Usages:      required by control.lua, wired to on_gui_opened / on_gui_closed / on_gui_click /
--              on_gui_text_changed; the pure part lives in scripts/gui/format.lua
-- Notes:       THE WINDOW IS NOT TESTABLE HEADLESS (ADR 0050). The measured prerequisite is the
--              probe in `spike/gui-probe/`: setting `player.opened = nil` inside on_gui_opened, then
--              adding the frame to `player.gui.screen`, replaces the vanilla container frame. That is
--              the sequence below, and the close it causes itself bounces back as an on_gui_closed in
--              the same tick — that one is ignored, or the frame would destroy itself on sight.
--              NO on_tick OF ITS OWN, AND ONE ON A CLOCK IT OWNS (ADR 0056 §2). The rows are rebuilt
--              when the window opens, when the tab changes, when a preset is written and after every
--              action; the header's countdown is the one thing that has to move on its own, so this
--              module registers `script.on_nth_tick(30)` when the first window opens and unregisters
--              it the moment the last one closes — including when that window cannot be drawn any
--              more (destroyed, player gone). No other tick exists in the mod.
--              THE TAB AND THE QUANTITY ARE PER PLAYER AND NEVER IN `storage`: two local tables, lost
--              on reload on purpose (a window is not economy). The frame itself survives a save, so a
--              click on a window whose binding was lost destroys it and says so instead of guessing
--              which counter it belongs to.
--              THE WIDTH IS SET ONCE, at creation, and never written again: `style.width` pins both
--              minimal and maximal width, so a row that gains or loses content cannot move a button
--              sideways. The height follows the content, but the content is a bounded number of rows
--              per tab (at most `offer_slots` contract rows, fifteen shop rows), so nothing inside a
--              tab ever moves either: every live contract is a row and the missing ones are drawable
--              placeholders, up to `offer_slots` (ADR 0051 — the cap is the module's, the window has
--              no display limit of its own).
--              EVERY ROW IS THE SUM OF ITS CELLS (A20). Lot (b) drew its buttons outside the frame and
--              cut two labels at the right edge: a button had no width, so its localised caption made
--              the row longer than the frame, and a label grew with its text. The frame is now
--              `ROW_WIDTH + 2 x PADDING` wide, every row declares `style.width = ROW_WIDTH` and
--              `horizontal_spacing = SPACING`, every label is pinned (`style.width`, `single_line`,
--              `maximal_width`), and the flexible columns are the remainder of the fixed ones. The
--              sums are asserted at load, so a cell that does not add up is a load error, not a row on
--              the sand; `M.GEOMETRY` carries the same numbers to the bench (scenario B1-gui-pure).
--              THE SHOP QUANTITY IS ONE NUMBER (docs/06 §6). A shared field cannot be clamped per
--              row, because fifteen rows would need fifteen different ceilings; it is therefore
--              clamped to the ceiling of the CHEAPEST catalogue item, which is the loosest bound any
--              row can honour (never blocking a purchase the cooperative can pay for), and each row's
--              BUY is disabled the moment the displayed number exceeds that row's own ceiling. A24 is
--              satisfied where it is measurable: no clickable quantity is above what the balance
--              allows for the row being clicked.
--              NO STYLING (mission lot b): no style prototype, no animation, no icon of our own. The
--              geometry set is the width of every cell, the spacing of every row, the four paddings of
--              the frame, the size of the item sprites and the colour of the character line (ADR 0022
--              asks for a colour per company).
-- Licence:     MIT (see LICENSE)

local format = require("__comptoir-contracts__/scripts/gui/format")
local companies = require("__comptoir-contracts__/scripts/companies")
local contracts = require("__comptoir-contracts__/scripts/contracts")
local counter = require("__comptoir-contracts__/scripts/counter")
local ledger = require("__comptoir-contracts__/scripts/ledger")
local elevator = require("__comptoir-contracts__/scripts/elevator")
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
local HEADER_ELEVATOR = "comptoir_header_elevator"
local HEADER_ELEVATOR_STATE = "comptoir_header_elevator_state"
local HEADER_ELEVATOR_CLOCK = "comptoir_header_elevator_clock"
local FEEDBACK_TEXT = "comptoir_feedback_text"
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

-- Geometry. Every width is a number of pixels decided here, and a row is the exact sum of its cells
-- plus the spacing between them. Lot (b) shipped rows whose buttons were drawn outside the frame and
-- whose last two labels were cut at the right edge (A20): a button carries no width of its own, so its
-- caption decided how long the row was, and the French captions are longer than the English ones.
-- Nothing below is left to the layout to guess: the fixed cells are declared, the flexible ones are
-- remainders computed from them, and the frame is `ROW_WIDTH` plus its two paddings wide.
local ROW_WIDTH = 720   -- the content width of a row, and therefore of the frame minus its padding
local PADDING = 12      -- frame padding, set explicitly on the four sides (never the style default)
local SPACING = 8       -- horizontal_spacing of every row, set explicitly (never the flow default)
local ICON_SHOP = 20
local ICON_CONTRACT = 32
local COL_PRICE = 96      -- shop: the buy price, right aligned
local COL_CREDITS = 96    -- shop: the buy-back price, right aligned
local COL_BUY = 120       -- shop: the BUY button (widened by ADR 0056 §2 — it wears a countdown)
local COL_SELL = 120      -- shop: the SELL button (same: a paused button says why and how long)
local COL_LIFT_CLOCK = 96 -- header: the elevator's remaining time, right aligned
local COL_TIME = 208      -- contract: payout, bar and clock
local COL_ACTION = 140    -- contract: the one contextual button
local COL_COMPANY = 240   -- header: the company name
local FIELD_WIDTH = 90    -- shop: the shared quantity field
local PRESET_WIDTH = 80   -- shop: each of the four preset buttons
local BAR_WIDTH = 100     -- contract: the deadline bar inside the time column
local ROW_HEIGHT = 48
local SHOP_ROW_HEIGHT = 28

-- The flexible columns are remainders, computed once from the fixed cells. The width of a row is
-- therefore a fact of this file, not a hope about the font the player runs.
local COL_NAME = ROW_WIDTH - (ICON_SHOP + COL_PRICE + COL_CREDITS + COL_BUY + COL_SELL) - 5 * SPACING
local COL_LEFT = ROW_WIDTH - (ICON_CONTRACT + COL_TIME + COL_ACTION) - 3 * SPACING
local COL_CHARACTER = ROW_WIDTH - COL_COMPANY - SPACING
local COL_CHARACTER_TEXT = COL_CHARACTER - ICON_SHOP - SPACING
local COL_CLOCK = COL_TIME - BAR_WIDTH - SPACING
local NUM_CELL = (ROW_WIDTH - SPACING) / 2
local COL_QUANTITY_LABEL = ROW_WIDTH - (FIELD_WIDTH + 4 * PRESET_WIDTH) - 5 * SPACING
local COL_LIFT_STATE = ROW_WIDTH - COL_LIFT_CLOCK - SPACING
local FRAME_WIDTH = ROW_WIDTH + 2 * PADDING

-- The cell widths of every row, in drawing order: the guard below sums them, and the bench reads
-- `M.GEOMETRY` to prove the same sums without a client (ADR 0050: the frame is not testable, its
-- arithmetic is).
M.GEOMETRY = {
  row_width = ROW_WIDTH,
  padding = PADDING,
  spacing = SPACING,
  frame_width = FRAME_WIDTH,
  shop_row = { ICON_SHOP, COL_NAME, COL_PRICE, COL_CREDITS, COL_BUY, COL_SELL },
  contract_row = { ICON_CONTRACT, COL_LEFT, COL_TIME, COL_ACTION },
  header_line = { COL_COMPANY, COL_CHARACTER },
  header_character = { ICON_SHOP, COL_CHARACTER_TEXT },
  header_numbers = { NUM_CELL, NUM_CELL },
  header_elevator = { COL_LIFT_STATE, COL_LIFT_CLOCK },
  feedback_line = { ROW_WIDTH },
  quantity_line = { COL_QUANTITY_LABEL, FIELD_WIDTH, PRESET_WIDTH, PRESET_WIDTH, PRESET_WIDTH, PRESET_WIDTH },
  contract_time = { BAR_WIDTH, COL_CLOCK },
}

-- Checked while control.lua is parsed: a row whose cells and spacing do not fill exactly its width is
-- the lot (b) bug again, and a load error with the row's name is a better reader than a button drawn
-- on the sand (A20). The two nested flows are measured against their own column, not against the row.
do
  local rows = {
    { "shop_row", M.GEOMETRY.shop_row, ROW_WIDTH },
    { "contract_row", M.GEOMETRY.contract_row, ROW_WIDTH },
    { "header_line", M.GEOMETRY.header_line, ROW_WIDTH },
    { "header_numbers", M.GEOMETRY.header_numbers, ROW_WIDTH },
    { "header_elevator", M.GEOMETRY.header_elevator, ROW_WIDTH },
    { "feedback_line", M.GEOMETRY.feedback_line, ROW_WIDTH },
    { "quantity_line", M.GEOMETRY.quantity_line, ROW_WIDTH },
    { "header_character", M.GEOMETRY.header_character, COL_CHARACTER },
    { "contract_time", M.GEOMETRY.contract_time, COL_TIME },
  }
  for _, entry in ipairs(rows) do
    local label, cells, expected = entry[1], entry[2], entry[3]
    local total = (#cells - 1) * SPACING
    for index, width in ipairs(cells) do
      if type(width) ~= "number" or width <= 0 or width % 1 ~= 0 then
        error("[comptoir] gui.window: " .. label .. " cell " .. index .. " is not a positive whole "
          .. "number of pixels (" .. tostring(width) .. ")")
      end
      total = total + width
    end
    if total ~= expected then
      error("[comptoir] gui.window: " .. label .. " sums to " .. tostring(total) .. " px, not "
        .. tostring(expected) .. " — a row that does not fill its width draws outside the frame")
    end
  end
  if FRAME_WIDTH ~= ROW_WIDTH + 2 * PADDING then
    error("[comptoir] gui.window: the frame is not its content plus two paddings")
  end
end

-- Per player, never in `storage`: the tab shown, the number in the shop field, and the hub the window
-- is bound to. Lost on reload, rebuilt by reopening the counter.
local tabs = {}
local quantities = {}
local windows = {}

-- The tick at which this module closed a GUI itself (`player.opened = nil`). That close can come back
-- as an on_gui_closed in the same tick; ignoring it is what keeps the frame on screen (ADR 0050).
local self_closed_tick = {}

-- The answer to the last action (ADR 0056 §3), per player: what the feedback row reads. Cleared with
-- the window — a line that outlived its frame would greet the next opening as if it had just happened.
local feedback = {}

-- The bounded clock (ADR 0056 §2). ONE `script.on_nth_tick(30)` for the whole module: registered when
-- the first window opens, unregistered the moment the last one closes, and never kept alive by a window
-- that cannot be drawn. It measures one thing — the header's countdown has to move — and decides
-- nothing: the trips, the deadlines and the refills stay lazy (design.md §3).
local CLOCK_INTERVAL = 30
local clock = { registered = false, storage = nil, runs = 0 }

-- Declared before it is defined: registering needs the handler, and the handler needs `refresh`, which
-- is defined after the drawing code.
local clock_tick

local function clock_stop()
  if clock.registered then
    script.on_nth_tick(CLOCK_INTERVAL, nil)
    clock.registered = false
  end
end

local function clock_start(storage)
  clock.storage = storage
  if not clock.registered then
    script.on_nth_tick(CLOCK_INTERVAL, clock_tick)
    clock.registered = true
  end
end

-- One window stops being drawn — closed by the player, destroyed with its counter, or lost with the
-- player. The last one takes the clock with it: the mod is lazy again as soon as nobody is looking at a
-- countdown.
local function detach(player_index)
  windows[player_index] = nil
  feedback[player_index] = nil
  if next(windows) == nil then
    clock_stop()
  end
end

-- The bookkeeping the events below use, and that the bench drives directly (scenario B4-clock): one
-- window per player, and a clock that follows the first and the last of them.
function M.track(storage, player_index, window)
  if storage == nil or type(player_index) ~= "number" or window == nil then
    error("[comptoir] gui.window.track: storage, player index and window are required", 2)
  end
  windows[player_index] = window
  clock_start(storage)
end

function M.untrack(player_index)
  detach(player_index)
end

-- Whether the one clock is registered, and how many times its handler has run. The bench asserts the
-- pair: closing the last window must unregister, and a handler that is still registered shows up as a
-- counter that keeps growing.
function M.clock_running()
  return clock.registered
end

function M.clock_runs()
  return clock.runs
end

-- The interval itself, so a scenario never hard-codes 30.
M.CLOCK_INTERVAL = CLOCK_INTERVAL

-- The catalogue's three groups, one literal key each: the character line of the header is a localised
-- string, and the family prefix lives in the section name (`[comptoir]`), so a key is the bare name
-- and the Lua side asks for `{"comptoir.<key>"}` (ADR 0053). Same for the reasons below: `_` became
-- `-`, because a locale key is `[a-z0-9-]+` and a dot inside a key would read as a section separator.
M.GROUP_KEYS = {
  chemistry = { "comptoir.group-chemistry" },
  electronics = { "comptoir.group-electronics" },
  logistics = { "comptoir.group-logistics" },
}

-- The four states of the car, one literal key each (ADR 0056 §2). Same rule as the reasons below:
-- written out, never built with `"comptoir.elevator-" .. state`, or `tools/check_locale.py` cannot see
-- them. The key keeps the state's own name so the header and the refusal reasons say the same word.
M.ELEVATOR_KEYS = {
  down = { "comptoir.elevator-down" },
  rising = { "comptoir.elevator-rising" },
  away = { "comptoir.elevator-away" },
  descending = { "comptoir.elevator-descending" },
}

-- Checked while control.lua is parsed: the module knows exactly four states, and a state without a
-- caption would draw an empty header cell — the same class of bug as a missing reason (ADR 0053).
do
  local states = { elevator.DOWN, elevator.RISING, elevator.AWAY, elevator.DESCENDING }
  for _, state in ipairs(states) do
    if M.ELEVATOR_KEYS[state] == nil then
      error("[comptoir] gui.window: the elevator state \"" .. state .. "\" has no caption key")
    end
  end
  for state in pairs(M.ELEVATOR_KEYS) do
    local known = false
    for _, other in ipairs(states) do
      if state == other then
        known = true
      end
    end
    if not known then
      error("[comptoir] gui.window: ELEVATOR_KEYS carries \"" .. state .. "\", which is not a state of the car")
    end
  end
end

-- Every reason a module can hand back, with the caption it prints, one literal key per code.
-- WRITTEN OUT, NEVER BUILT WITH `"comptoir.reason-" .. reason`: a concatenated key is invisible to
-- `tools/check_locale.py`, and that is how the lot-b regression shipped a window full of "Unknown
-- key" (ADR 0053). The code keeps its `_` — it is the modules' vocabulary — the key uses `-`.
M.REASON_KEYS = {
  unknown_contract = { "comptoir.reason-unknown-contract" },
  not_offered = { "comptoir.reason-not-offered" },
  no_free_slot = { "comptoir.reason-no-free-slot" },
  escrow_unavailable = { "comptoir.reason-escrow-unavailable" },
  not_accepted = { "comptoir.reason-not-accepted" },
  in_flight = { "comptoir.reason-in-flight" },
  unknown_state = { "comptoir.reason-unknown-state" },
  no_hub = { "comptoir.reason-no-hub" },
  no_entity = { "comptoir.reason-no-entity" },
  no_inventory = { "comptoir.reason-no-inventory" },
  not_enough_stock = { "comptoir.reason-not-enough-stock" },
  stock_changed = { "comptoir.reason-stock-changed" },
  flight_in_progress = { "comptoir.reason-flight-in-progress" },
  elevator_rising = { "comptoir.reason-elevator-rising" },
  elevator_away = { "comptoir.reason-elevator-away" },
  elevator_descending = { "comptoir.reason-elevator-descending" },
  insufficient_credits = { "comptoir.reason-insufficient-credits" },
  nothing_to_trade = { "comptoir.reason-nothing-to-trade" },
  empty_pool = { "comptoir.reason-empty-pool" },
  no_room = { "comptoir.reason-no-room" },
  payment_refused = { "comptoir.reason-payment-refused" },
  no_stock = { "comptoir.reason-no-stock" },
  shop_cannot_pay = { "comptoir.reason-shop-cannot-pay" },
  bad_count = { "comptoir.reason-bad-count" },
  unknown_action = { "comptoir.reason-unknown-action" },
}

-- The codes in a stable order, for the bench: derived from the table above, so the list of reasons and
-- the list of captions cannot drift apart.
M.REASONS = {}
for code in pairs(M.REASON_KEYS) do
  M.REASONS[#M.REASONS + 1] = code
end
table.sort(M.REASONS)

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

-- The frame this player has, or nil when there is none to draw into. Without a client the screen
-- element does not exist and asking for it raises instead of returning nil (ADR 0050), so the read is
-- wrapped: "there is no window to draw" and "the player is gone" are the same answer here, and the
-- bounded clock below depends on getting that answer instead of an error.
local function root_of(player)
  if player == nil or player.valid ~= true then
    return nil
  end
  local ok, screen = pcall(function()
    return player.gui.screen
  end)
  if not ok or screen == nil then
    return nil
  end
  local root = screen[ROOT]
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

-- A label that occupies its column and nothing else. `style.width` pins the minimal AND maximal width,
-- so the cell cannot grow with its text; `single_line` refuses to wrap, and `maximal_width` is what
-- makes a long caption truncate inside its own cell instead of pushing the rest of the row out of the
-- frame (A20). `single_line` only exists for labels: a button is pinned by `button_cell` below.
local function cell(label, width, align)
  label.style.single_line = true
  label.style.maximal_width = width
  label.style.width = width
  if align ~= nil then
    label.style.horizontal_align = align
  end
  return label
end

-- A button of fixed width. Its caption is a locale string, and no runtime API measures a string, so
-- the widths below are sized for the longest caption of the two locales ("EXPÉDIER 1 234" in the
-- contract row, "ACHETER" in the shop): a caption that outgrew its cell would be clipped by the engine.
local function button_cell(button, width)
  button.style.width = width
  button.style.maximal_width = width
  return button
end

-- A row of the window: full width, explicit spacing, so its cells are the only thing that decides
-- where a column starts.
local function full_row(parent, entry, height)
  local row = parent.add(entry)
  row.style.width = ROW_WIDTH
  row.style.horizontal_spacing = SPACING
  if height ~= nil then
    row.style.height = height
  end
  return row
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
  -- Written exactly once in the life of the frame (docs/06 §1: the header never moves). The padding is
  -- set here rather than inherited, because the frame's width is the sum of its widest row plus these
  -- two paddings and nothing else (A20).
  root.style.left_padding = PADDING
  root.style.right_padding = PADDING
  root.style.top_padding = PADDING
  root.style.bottom_padding = PADDING
  root.style.width = FRAME_WIDTH

  local header = root.add({ type = "flow", name = HEADER, direction = "vertical" })
  header.style.width = ROW_WIDTH

  local line = full_row(header, { type = "flow", name = HEADER_LINE, direction = "horizontal" })
  cell(line.add({ type = "label", name = HEADER_COMPANY, caption = "" }), COL_COMPANY)

  local character = line.add({ type = "flow", name = HEADER_CHARACTER, direction = "horizontal" })
  character.style.width = COL_CHARACTER
  character.style.horizontal_spacing = SPACING
  icon(character, HEADER_ICON, CHEAPEST, ICON_SHOP)
  cell(character.add({ type = "label", name = HEADER_TEXT, caption = "" }), COL_CHARACTER_TEXT)

  local numbers = full_row(header, { type = "flow", name = HEADER_NUMBERS, direction = "horizontal" })
  cell(numbers.add({ type = "label", name = HEADER_AVAILABLE, caption = "" }), NUM_CELL, "right")
  cell(numbers.add({ type = "label", name = HEADER_RESERVED, caption = "" }), NUM_CELL, "right")

  -- Where the car is, and how long it has left (ADR 0056 §2). A row of its own, above the tabs: the
  -- state is a fact of the counter, not of a tab, and the countdown is the only text in the frame that
  -- moves on its own.
  local lift = full_row(header, { type = "flow", name = HEADER_ELEVATOR, direction = "horizontal" })
  cell(lift.add({ type = "label", name = HEADER_ELEVATOR_STATE, caption = "" }), COL_LIFT_STATE)
  cell(lift.add({ type = "label", name = HEADER_ELEVATOR_CLOCK, caption = "" }), COL_LIFT_CLOCK, "right")

  local tabbar = full_row(root, { type = "flow", name = TABS, direction = "horizontal" })
  button_cell(tabbar.add({ type = "button", name = TAB_CONTRACTS, caption = { "comptoir.tab-contracts" } }), NUM_CELL)
  button_cell(tabbar.add({ type = "button", name = TAB_SHOP, caption = { "comptoir.tab-shop" } }), NUM_CELL)

  -- The feedback line (ADR 0056 §3): one row under the tabs, one line, rewritten after every action and
  -- left alone until the next one. Built with the frame and never destroyed, so a refusal and a sale
  -- land in the same place and the window does not move when either happens.
  local feedback_row = root.add({ type = "label", name = FEEDBACK_TEXT, caption = "" })
  feedback_row.style.horizontal_align = "left"
  cell(feedback_row, ROW_WIDTH)

  for _, name in ipairs({ BODY_CONTRACTS, BODY_SHOP }) do
    local body = root.add({ type = "flow", name = name, direction = "vertical" })
    body.style.width = ROW_WIDTH
  end

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

-- The elevator, as the window shows it (ADR 0056 §2): the state, its caption, the clock, and the one
-- caption the paused buttons wear. Read once per render, so the header and the buttons cannot
-- disagree, and the `wait` string is built once instead of once per row.
local function lift_of(ctx, tick)
  local elevator_state = elevator.state_of(ctx.hub)
  local remaining = format.clock(elevator.remaining_ticks(ctx.hub, tick))
  local caption = M.ELEVATOR_KEYS[elevator_state]
  return {
    state = elevator_state,
    moving = elevator_state ~= elevator.DOWN,
    caption = caption,
    clock = remaining,
    wait = { "comptoir.action-wait", caption, remaining },
  }
end

-- The three gates of a shop row, computed once and used both when drawing and while typing (A22). The
-- third is the pause of ADR 0056 §2: a counter whose car is not down trades nothing, so the two
-- buttons are disabled before any price is read.
local function shop_gates(ctx, item, quantity, moving)
  local paused = moving == true
  local buy = paused ~= true and quantity >= 1 and quantity <= counter.affordable(ctx.state, item)
  local sellable = counter.sellable(ctx.company, ctx.entity, item)
  local sell = paused ~= true and quantity >= 1 and quantity <= sellable
  return buy, sell
end

-- ---------------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------------

local function draw_contract_row(body, contract, ctx, storage, tick, lift)
  local row = full_row(body, { type = "flow", name = "contracts-" .. contract.id .. "-row", direction = "horizontal" }, ROW_HEIGHT)

  icon(row, "contracts-" .. contract.id .. "-icon", contract.item, ICON_CONTRACT)

  local left = row.add({ type = "flow", direction = "vertical" })
  left.style.width = COL_LEFT
  local texts = format.row_texts(contract, contracts.time_left(contract, tick))
  cell(left.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-quantity",
    caption = { "comptoir.quantity-of", texts.quantity, { "item-name." .. contract.item } },
  }), COL_LEFT)
  cell(left.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-reserve",
    caption = { "comptoir.reserve", texts.reserve },
  }), COL_LEFT)

  local right = row.add({ type = "flow", direction = "vertical" })
  right.style.width = COL_TIME
  cell(right.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-payout",
    caption = { "comptoir.money", texts.payout },
  }), COL_TIME)
  local timeline = right.add({ type = "flow", direction = "horizontal" })
  timeline.style.width = COL_TIME
  timeline.style.horizontal_spacing = SPACING
  local bar = timeline.add({ type = "progressbar", name = "contracts-" .. contract.id .. "-bar", value = texts.fraction })
  bar.style.width = BAR_WIDTH
  cell(timeline.add({
    type = "label",
    name = "contracts-" .. contract.id .. "-time",
    caption = texts.clock,
  }), COL_CLOCK)

  -- The one contextual button of the row (docs/06 §2). Its verdict is the module's (A22) — except
  -- while the car is not down: then the pause wins the caption, the button is disabled, and it says
  -- what it waits for and how long it has to wait (ADR 0056 §2). A disabled button with no reason is
  -- exactly the complaint this answers.
  local action, allowed, _, stock = contracts.action_of(ctx.state, storage, ctx.force_index, ctx.company, contract)
  local button = row.add({ type = "button", name = "contracts-" .. contract.id .. "-action", caption = "" })
  button_cell(button, COL_ACTION)
  if contract.state == contracts.IN_FLIGHT then
    button.caption = { "comptoir.action-in-flight" }
    button.enabled = false
  elseif lift.moving then
    button.caption = lift.wait
    button.enabled = false
  elseif action == "accept" then
    button.caption = { "comptoir.action-accept" }
    button.enabled = allowed == true
  else
    -- How many the counter holds of what the contract asks for, capped at the quantity: a number above
    -- the order would announce a delivery that cannot happen.
    local count = math.min(stock or 0, contract.quantity)
    button.caption = { "comptoir.action-dispatch", format.grouped(count) }
    button.enabled = allowed == true
  end
  return row
end

local function draw_empty_slot(body, slot)
  local row = full_row(body, { type = "flow", name = "contracts-slot-" .. slot .. "-empty", direction = "horizontal" }, ROW_HEIGHT)
  cell(row.add({ type = "label", name = "contracts-slot-" .. slot .. "-empty-label", caption = { "comptoir.empty-slot" } }), ROW_WIDTH)
  return row
end

local function draw_shop_row(body, item, ctx, quantity, lift)
  local quote = counter.quote(item)
  local row = full_row(body, { type = "flow", name = "counter-" .. item .. "-row", direction = "horizontal" }, SHOP_ROW_HEIGHT)

  icon(row, "counter-" .. item .. "-icon", item, ICON_SHOP)

  -- The item name is the flexible column: it takes what the fixed cells leave, truncates inside it
  -- (a long localised name must not push the prices and the buttons out of the frame), and never wraps.
  cell(row.add({ type = "label", name = "counter-" .. item .. "-name", caption = { "item-name." .. item } }), COL_NAME)

  cell(row.add({ type = "label", name = "counter-" .. item .. "-price", caption = { "comptoir.money", format.grouped(quote.buy_price) } }), COL_PRICE, "right")

  cell(row.add({ type = "label", name = "counter-" .. item .. "-buy-back", caption = { "comptoir.buy-back", format.grouped(quote.sell_credits) } }), COL_CREDITS, "right")

  local buy_enabled, sell_enabled = shop_gates(ctx, item, quantity, lift.moving)
  local buy = button_cell(row.add({ type = "button", name = "counter-" .. item .. "-buy", caption = { "comptoir.buy" } }), COL_BUY)
  local sell = button_cell(row.add({ type = "button", name = "counter-" .. item .. "-sell", caption = { "comptoir.sell" } }), COL_SELL)
  -- While the car is away the two buttons say why they are grey and when they will come back, in the
  -- same words as the header (ADR 0056 §2). Fifteen rows wear the same caption: it is one state, not
  -- fifteen.
  if lift.moving then
    buy.caption = lift.wait
    sell.caption = lift.wait
  end
  buy.enabled = buy_enabled
  sell.enabled = sell_enabled
  return row
end

local function draw_shop(body, ctx, player, lift)
  local quantity = quantity_of(player.index)

  local line = full_row(body, { type = "flow", name = QUANTITY_LINE, direction = "horizontal" })
  cell(line.add({ type = "label", name = QUANTITY_LABEL, caption = { "comptoir.quantity-label" } }), COL_QUANTITY_LABEL)
  local field = line.add({ type = "textfield", name = QUANTITY_FIELD, text = tostring(quantity), numeric = true })
  field.style.width = FIELD_WIDTH
  field.style.maximal_width = FIELD_WIDTH
  for _, preset in ipairs({ "1", "10", "100", "stack" }) do
    local button = button_cell(line.add({ type = "button", name = "counter-quantity-" .. preset, caption = "" }), PRESET_WIDTH)
    if preset == "stack" then
      button.caption = { "comptoir.preset-stack" }
    else
      button.caption = preset
    end
  end

  for _, item in ipairs(format.price_order()) do
    draw_shop_row(body, item, ctx, quantity, lift)
  end
end

local function render(storage, player, window)
  local ctx = context(storage, window)
  if ctx == nil then
    destroy(player)
    detach(player.index)
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
  text.caption = {
    "comptoir.character",
    M.GROUP_KEYS[primary] or primary,
    M.GROUP_KEYS[secondary] or secondary,
  }
  text.style.font_color = format.colour_of(ctx.company.id)
  child_named(character, HEADER_ICON).sprite = "item/" .. format.group_item(primary)

  local numbers = child_named(header, HEADER_NUMBERS)
  child_named(numbers, HEADER_AVAILABLE).caption = { "comptoir.available", format.grouped(ledger.available(ctx.state)) }
  child_named(numbers, HEADER_RESERVED).caption = { "comptoir.reserved", format.grouped(ctx.state.reserved) }

  -- The car (ADR 0056 §2): where it is, and how long before it is down again. The clock reads 0:00 when
  -- the car is down — a countdown to nothing is not a state, and the header already says "down".
  local lift = lift_of(ctx, tick)
  local lift_row = child_named(header, HEADER_ELEVATOR)
  child_named(lift_row, HEADER_ELEVATOR_STATE).caption = { "comptoir.elevator", lift.caption }
  child_named(lift_row, HEADER_ELEVATOR_CLOCK).caption = lift.clock

  -- The answer to the last action (ADR 0056 §3). It is a fact of the window, not of a tab: switching
  -- tabs leaves it alone, and only the next action rewrites it.
  child_named(root, FEEDBACK_TEXT).caption = feedback[player.index] or ""

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
      draw_contract_row(contract_body, contract, ctx, storage, tick, lift)
    end
    for slot = #live + 1, CONTRACT_SLOTS do
      draw_empty_slot(contract_body, slot)
    end
  else
    clear(shop_body)
    draw_shop(shop_body, ctx, player, lift)
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

-- The handler of the one clock (ADR 0056 §2). It redraws the windows that can still be drawn and drops
-- the ones that cannot: a counter deconstructed with its window open, a player who left, a client that
-- is no longer there. Dropping them is what keeps the registration bounded — the last window to go takes
-- the clock with it, so `on_nth_tick` is unregistered by the same code that keeps it honest. The
-- `runs` counter is the bench's proof that this handler is really the thing that stopped.
clock_tick = function()
  clock.runs = clock.runs + 1
  if next(windows) == nil then
    -- A save taken with a window open reloads with the engine still holding this handler while the
    -- module's per-player tables are gone (they are deliberately not in `storage`). Nothing to draw is
    -- nothing to measure: this is the one path that could leave the registration behind, so it is closed
    -- here instead of hoped away — the next window to open registers it again.
    clock_stop()
    return
  end
  local doomed, alive = {}, {}
  for player_index, window in pairs(windows) do
    local player = game.get_player(player_index)
    if root_of(player) == nil or context(clock.storage, window) == nil then
      doomed[#doomed + 1] = player_index
    else
      alive[#alive + 1] = player
    end
  end
  for _, player_index in ipairs(doomed) do
    -- A window whose counter is gone must not stay on screen with the last numbers it drew.
    destroy(game.get_player(player_index))
    detach(player_index)
  end
  for _, player in ipairs(alive) do
    refresh(clock.storage, player)
  end
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

  -- One window, tracked: the frame is built by the refresh below, and this is where the mod learns that
  -- somebody is looking at a countdown (ADR 0056 §2 — the clock starts with the first window).
  M.track(storage, event.player_index, { unit_number = entity.unit_number, force_index = hub.force_index })
  refresh(storage, player)
end

function M.on_closed(storage, event)
  if self_closed_tick[event.player_index] == game.tick then
    self_closed_tick[event.player_index] = nil
    return
  end
  local player = game.get_player(event.player_index)
  destroy(player)
  -- The last window to close stops the clock (ADR 0056 §2). `destroy` above answers for a player who is
  -- still here; a player who is gone has no frame left to destroy.
  M.untrack(event.player_index)
end

-- A refused action says why, in the player's language, from one key per reason. A code this table does
-- not know is shown as the raw code: a visible gap (design.md §5), never a key the engine cannot
-- resolve into a window full of "Unknown key" (ADR 0053).
local function reason_caption(reason)
  return M.REASON_KEYS[reason] or reason
end

-- The answer to the last action (ADR 0056 §3): one line, under the tabs, rewritten by every action —
-- acceptance, dispatch, purchase, sale — and by every refusal, which uses the same row with its reason.
-- It stays until the next action replaces it, and it is a line of the window rather than a print in the
-- console: the player is looking at the window, so the window is what answers. The rows are rebuilt on
-- every action anyway, and `render` paints this line from the table below, so it survives a tab change
-- too.
local function say(player, caption)
  feedback[player.index] = caption
end

local function refuse(player, reason)
  if reason == nil then
    return
  end
  say(player, { "comptoir.refused", reason_caption(reason) })
end

local function accept(storage, player, ctx, contract_id)
  local tick = game.tick
  local ok, reason, contract = contracts.accept(
    ctx.state,
    storage,
    ctx.force_index,
    player.force,
    ctx.company,
    contract_id,
    tick
  )
  if ok then
    say(player, format.feedback_contract("accept", contract.quantity, contract.item))
  else
    refuse(player, reason)
  end
  refresh(storage, player)
end

local function dispatch(storage, player, ctx, contract_id)
  local tick = game.tick
  local ok, reason, contract = contracts.dispatch(ctx.state, storage, ctx.force_index, ctx.company, contract_id, tick)
  if ok then
    say(player, format.feedback_contract("dispatch", contract.quantity, contract.item))
  else
    refuse(player, reason)
  end
  refresh(storage, player)
end

local function trade(storage, player, ctx, item, action_name)
  local quantity = quantity_of(player.index)
  local trade_fn = counter[action_name]
  local ok, reason, count, total = trade_fn(ctx.state, ctx.company, ctx.entity, item, quantity, ctx.hub)
  if ok then
    say(player, format.feedback_trade(action_name, count, total))
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
  -- The pause is re-read here too: typing in the field must not re-enable a button the car has taken
  -- away, and the caption has to follow the countdown (ADR 0056 §2).
  local lift = lift_of(ctx, game.tick)
  for _, item in ipairs(format.price_order()) do
    local buy = child_named(body, "counter-" .. item .. "-buy")
    local sell = child_named(body, "counter-" .. item .. "-sell")
    if buy ~= nil or sell ~= nil then
      local buy_enabled, sell_enabled = shop_gates(ctx, item, quantity, lift.moving)
      if buy ~= nil then
        buy.enabled = buy_enabled
        if lift.moving then
          buy.caption = lift.wait
        else
          buy.caption = { "comptoir.buy" }
        end
      end
      if sell ~= nil then
        sell.enabled = sell_enabled
        if lift.moving then
          sell.caption = lift.wait
        else
          sell.caption = { "comptoir.sell" }
        end
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
    M.untrack(event.player_index)
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
    -- say so rather than act on a counter we can no longer identify. There is no window left to write a
    -- feedback line into, so this one message stays a print.
    destroy(player)
    M.untrack(event.player_index)
    player.print({ "comptoir.stale-window" })
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
