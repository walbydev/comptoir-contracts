# Spec 001 — design

- **Status**: frozen for implementation, 2026-10-25
- **Read with**: `spec.md` (what) and `docs/arborescence.md` (where)

## 1. Modules and their single responsibility

| File | Owns | Never does |
|---|---|---|
| `control.lua` | `script.on_*` wiring | hold state or logic |
| `scripts/ledger.lua` | the arithmetic of money: `hold`, `release`, `forfeit`, `debit`, `credit`, `assert_conservation` | know what a contract is |
| `scripts/companies.lua` | creation, name, character, tier, the company's RNG | touch balances |
| `scripts/contracts.lua` | generation, accept, dispatch, pay, expire | draw anything |
| `scripts/elevator.lua` | the state machine and its timestamps | touch money |
| `scripts/counter.lua` | buy and sell, spread, clamping to what the balance allows | read the GUI |
| `scripts/gui/*` | build, refresh, dispatch clicks by element name | decide a rule |
| `scripts/migrate.lua` | `storage.version` and the chain | run on a fresh save |

The rule behind the table: **a module that both decides and displays becomes untestable.** The GUI only
calls the module that decides.

## 2. Storage schema — version 1

```lua
storage = {
  version = 1,
  forces = {                     -- keyed by force index
    [1] = {
      cooperative = 3000,
      reserved = 0,
      next_company_id = 1,
      companies = {
        [1] = {
          id = 1, name = "Meridian Trading", tier = 1,
          balance = 0,
          rng = 123456789,       -- 32-bit LCG state, this company only
          weights = { logistics = 3, chemistry = 1, electronics = 2 },
          contracts = {
            [1] = {
              item = "iron-plate", quantity = 208,
              payout = 2496, reserve = 500,
              deadline_tick = 36000,
              state = "offered", -- offered | accepted | in_flight | done | expired
              settled = false,
            },
          },
        },
      },
    },
  },
  hubs = {                       -- keyed by unit_number
    [42] = {
      force_index = 1, company_id = 1,
      elevator = { state = "down", since_tick = 0, return_tick = 0 },
    },
  },
}
```

Three deliberate choices:

- **`reserved` is a single number**, not a per-contract sum maintained by hand: it is recomputed from the
  contracts on write and asserted equal (`A19`).
- **`deadline_tick` is absolute.** Nothing counts down in the background; the remaining time is
  `deadline_tick - game.tick`, computed when something looks at it. Expiry is applied **once**, guarded by
  `settled`, the first time any read sees `game.tick > deadline_tick`.
- **The company's RNG state lives in the company**, so the company's own decisions are reproducible after a
  reload and identical on every client.

## 3. Events — the entire surface

| Event | Handler does |
|---|---|
| `on_init` | create `storage.version`, no company yet |
| `on_configuration_changed` | run the migration chain, rebind hubs to companies |
| `on_built_entity` / `on_robot_built_entity` | distance check, refund if refused, create the company |
| `on_entity_died` / `script_raised_destroy` | forget the hub, keep the company's money, drop its contracts |
| `on_gui_opened` / `on_gui_closed` | build or destroy the window |
| `on_gui_click` | dispatch by element name: `ct_accept_N`, `ct_send_N`, `shop_buy_ITEM`, … |
| `on_gui_text_changed` | quantity field only, clamped |
| `on_gui_elem_changed` | presets set the field, they do not act |

**No `on_tick`.** This is the performance budget: an idle hub costs zero ticks, a busy one costs a handful
of GUI events. The consequence is accepted in `0035`: the elevator's return and a contract's expiry are
**lazy**, applied on the next read, never on a clock.

## 4. Randomness — a local LCG, not the engine

`game.create_random_generator` was not measured on 2.1.23, and `math.random` desyncs. So the company
carries a 32-bit state and the mod advances it with its own linear congruential generator (the classic
`state = (state * 1103515245 + 12345) % 2^31`). It is fifteen lines, it is identical on every client, it
survives a reload, and it has no dependency on an API this project has not verified.

**Rule: any iteration that writes state iterates a sorted key list.** Lua's table order is not guaranteed,
and that is how a mod desyncs without ever calling `math.random`.

## 5. The public API, and why the test mod can exist

A separate mod **cannot read another mod's `storage`**. So the shipped mod exposes one small remote
interface:

```lua
remote.add_interface("comptoir-contracts", {
  snapshot = function(force_index) ... end,   -- read-only: balances, companies, contracts, elevator state
  act = function(force_index, action, params) ... end,  -- accept / dispatch / buy / sell, the same paths the GUI calls
  api_version = 1,
})
```

This is a **correction to ADR 0042's wording**: the shipped mod contains no *test assertions*, but it does
contain this API. Three reasons it is the right shape:

1. without it, an automated harness is impossible — a test mod can place an entity but cannot read the
   result;
2. `comptoir-freight` and every future add-on will need exactly this surface (`0013` already required a
   versioned API);
3. `act` grants nothing a player cannot already do with the console, which `0040` declares out of scope.
   It is not a security hole; it is a documented door.

The test mod therefore contains the assertions and nothing else.

## 6. GUI

- One frame, `name = "comptoir_root"`, two tabs (`ct_tab_contracts`, `ct_tab_shop`) and a header built once
  and **refreshed in place**. No element is destroyed except when the tab changes.
- Element names carry their payload: `ct_accept_<contract_id>`. The click handler parses the name; it never
  searches the tree.
- The window **never resizes while open** (a contract completing must not move the button under the
  cursor), so every field has a fixed width in characters, and long company names are truncated with an
  ellipsis at build time, not at refresh time.
- Refresh happens on: open, tab change, click, and contract settlement. Not on tick.

## 7. Migrations

`migrate.lua` holds a list of `{ from = n, to = n + 1, apply = function(storage) ... end }` and runs them in
order on `on_configuration_changed`. A missing step is a **loud console error and a refusal to continue**,
never a silent guess. v1 ships `version = 1` and an empty chain; the chain exists from the first release
because it cannot be added retroactively to saves already in the wild.
