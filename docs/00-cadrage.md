# Framing — Company contracts (Factorio 2.1 mod set)

> Version: 0.3 · Date: 2026-10-25 · Requested by: Philippe Ryf
> Status: **blocks 1–6 CLOSED** (2026-10-25) — 65 decisions recorded (4 withdrawn), 38 ADRs, 24
> acceptance criteria, **no question left blocking v1**, 15 parked with their features.
> Repository: `walbydev/comptoir-contracts` (public GitHub, MIT) — created and verified 2026-10-25.
> No development before tag `v0.1-cadrage`.

**Language convention:** this document, all ADRs and all source code are written in **English**.
Conversation with the requester happens in French; deliverables do not.

---

## 0. Phase 0 — Project environment

Declared 2026-10-25, before any substantive decision. **Every environment question is now settled**
(forge, licence, distribution): Phase 0 is closed.

### 0.1 Nature of the deliverable

This is **not a service**: it is a **Factorio game mod set** (Lua 5.2, data API + runtime API). The
usual operations grid collapses accordingly:

| Usual service question | Answer here |
|---|---|
| Where does it run in production? | Nowhere. The code runs inside Philippe's Factorio client. |
| Who probes for failure? | Nobody. There is no probe: a failure is a Lua error in game or a save crash. |
| Automatic restart? | Not applicable (no server process to supervise). |
| Server backup? | Not applicable. The only persistent data is the player's **save** (`storage`). |
| Network exposure, TLS, reverse proxy? | Not applicable. No open port, no Caddy. |
| Operational secrets? | None at runtime. One possible secret: the mod portal publishing token. |

Block 7 (operations) therefore reduces to **three commitments**: save compatibility, the release
procedure, and "what the player does when a version breaks their game".

### 0.2 Test chain (verified by execution, not assumed)

- Factorio **headless 2.1.23** (build 87750, linux64) in `/opt/data/.local/opt/factorio` —
  re-verified 2026-10-25: `factorio --version` → `Version: 2.1.23 (build 87750, linux64, headless)`.
  It loads mods, generates a map and executes the control stage.
- `luac` is **not installed on this machine** — verified 2026-10-25, depth-6 search of `/` found no
  binary (the handoff brief claimed a locally compiled 5.2.4: it is wrong). Either build Lua 5.2 in
  block 4, or accept that a syntax error surfaces as a headless load failure. Until then `make
  check` has nothing to run, and no document may claim a syntax check passed.
- Framing consequence: **the mod is testable without a graphical client and without Philippe**,
  hence in local CI. This is what makes block 9 (quality) achievable.
- What **cannot** be tested this way: GUI rendering, balancing feel, merchant animations. Accepted
  as untestable, compensated by Philippe's play sessions (§9).

### 0.3 Distribution and licence — settled

| Topic | State | Detail |
|---|---|---|
| Distribution channel | Official portal `mods.factorio.com` | Manual upload of a `x.y.z.zip` per mod of the set. Exact upload and moderation procedure: `[to verify]` in block 7 (Q09). |
| Required account | Philippe's factorio.com account + publishing API token | Token stored **outside the repository**, named `FACTORIO_API_KEY`; never committed, never copied into a document. |
| Code licence | **MIT — decided 2026-10-25** (Q07 closed) | ADR `0003`. LGPL-3 rejected: a publicly distributed mod benefits from showing its code. |
| Target game version | Factorio **2.1.x** | `info.json`: `"factorio_version": "2.1"`. Space Age is an **optional** dependency, never required (D5). |
| Cost | 0 (no service, no cloud) | Philippe already owns the Factorio licence; headless test binaries do not require one. |

### 0.4 Code repository — settled

**Decision of 2026-10-25: public GitHub `walbydev/comptoir-contracts`** (option 3a), MIT licence,
ADR `0003`. Verified through the API: public repository created, `HTTP 201`, `visibility: public`.

Consequence: this document is **now versioned**. The handoff brief becomes a frozen input
(`docs/entrants/`), not a living source. Layout of the set inside the repository: **Q27**.

### 0.5 How Phase 0 reshapes the remaining blocks

- Block 2 (users and usage): one real user (Philippe, the player) plus the anonymous portal
  population → usage is described in **play sessions**, not requests per day.
- Block 5 (data): "data" means persistent `storage` state plus the mod's prototypes. Data contract =
  `storage` schema with a save version. Retention = the player's save lifetime.
- Block 7 (operations): reduced to save compatibility and the release procedure (§0.1, §0.3) —
  multiplied by the number of mods in the set (D23).
- Block 8 (security): no permissions, no authentication; the only concerns are **the publishing
  token**, **not overwriting other mods' prototypes**, and **multiplayer determinism**.

---

## 1. Vision and non-goals

**Raw vision statement (requester's own words, original French):**

> « J'aime bien l'idée des contrats de compagnies via un hub de communication commerciale ce qui
> permet d'obtenir des crédits et/ou des technologies. Les crédits accumulés permettent d'acheter
> des stacks de matériaux ou des technologies se passant de recherche. J'aimerais quelque chose
> d'équilibré. Le hub est un ascenseur spatial relié à un spatioport qui permet aux marchands de
> venir chercher les commandes des contrats réalisés. »

**Restated vision:** a commercial hub (space elevator plus a spaceport) run by a **colonial
federation** offers delivery contracts to the company; delivering them earns credits and/or
technologies, and credits buy stacks of materials or technologies without research — a **complement**
to local production, never a substitute.

**What this is not (to prevent drift across blocks):** it is not an economy mod, not an alternative
tech tree, not a new planet or a new production chain. The added loop is **an exchange loop** grafted
onto what already exists.

### 1.1 Decisions

| ID | Question | Philippe's decision | Trace |
|---|---|---|---|
| D1 | Nature of credits, first answer | **Virtual currency** (1a) — *superseded the same day* | ADR `0001` (superseded) |
| D1-bis | Credit-item, final answer | ~~The item exists in the MVP, convertible both ways at the hub only~~ → **superseded by D39: no physical currency at all** | ADR `0004` → `0023` |
| D2 | Delivery method, first answer | Insertion into the hub or rocket launch — **superseded by D21** (warehouses + elevator, no rocket) | ADR `0010` |
| D3 | Purchasable technologies | **Curated list** (2a): never the technology that unlocks the hub, never a tech on the critical path | ADR `0002` |
| D4 | Number of hubs | One hub or several — **settled by D25**: several per surface | ADR `0014` |
| D5 | Space Age | **Works with and without the DLC**: prototypes owned by the mod, SA assets reused only when the DLC is present | ADR `0005` |
| D6 | Repository forge | **Public GitHub `walbydev`** (3a), licence **MIT** | ADR `0003` |
| D7 | Money format | **Integer credits only** — no cents, no fractional credit anywhere, explicit rounding | ADR `0006` |
| ~~D8~~ | ~~Credit-item value~~ | **withdrawn** — there is no item | `0023` |
| ~~D9~~ | ~~Conversion cost~~ | **withdrawn** — there is no conversion | `0023` |
| ~~D10~~ | ~~Rate improvements~~ | **withdrawn** — no rate to improve; the two technologies leave the scope | `0023` |
| D11 | Bank | **Parked (post-v1)**: deposit, withdraw, regular interest — with no player wallet (`0023`, `0024`) the bank has no subject in v1 | ADR `0007`, `0025` |
| ~~D12~~ | ~~Players~~ | **Solo and multiplayer**; ~~gifting exists only via credit-items~~ → **no gifting**: nothing is giftable (D39), nobody but a company holds credits (D40) | §2, `0023`, `0024` |
| D13 | Game horizon | **2 h speedrun to 100 h long game** — the economy scales by **progression tier**, not wall-clock | §2 |
| D14 | Passive player | **Parked (post-v1)**: no income without activity — with no player wallet and no interest, there is nothing to pause | ADR `0008`, `0025` |
| D15 | Bounties | **Parked (post-v1)**: nests, worms and science packs pay escalating bonuses | ADR `0009`, `0025` |
| D16 | Money source | **One treasury funds every credit payout** — contracts, bounties, interest. *Revised by D26*: one treasury **per company** | ADR `0009`, `0014` |
| D17 | Contract mix | **Most contracts on already-acquired technologies**; a minority are "motivation" contracts requiring the next tier | §3 |
| D18 | AFK signal | **Production**, not movement — *still open*: attribution in a shared multiplayer factory (Q19-bis) | ADR `0008` |
| D19 | Bank structure | **One bank** holding the accounts of players, companies, the colonial federation and the bank itself — *revised by `0014`: one unit and one issuer, N books; who issues is Q30* | ADR `0011`, `0014` |
| D20 | Printing right | **Printing credits is a right obtained by research** — *blocked*: creation or materialisation (Q25) | ADR `0012` |
| D21 | Delivery chain | **Hub + space elevator = the interface with the spaceport**; dedicated **cargo warehouses bound 1:1 to a contract**, fed by inserter **or** logistics robot | ADR `0010` |
| D22 | Dispatch and loss | Manual send or automatic on quantities reached; goods on expiry / destruction — *open* (Q24) | ADR `0010` |
| D23 | Packaging | **A set: one core mod + optional add-ons** (`company-contracts`, `-bank`, `-bounties`, `-mint`) | ADR `0013` |
| D24 | Add-on rule | Add-ons add **behaviour, not prototypes**, so they stay removable from a save | ADR `0013` |
| D25 | Hub = company | **One hub = one space elevator = one spaceport = one company** that offers contracts **and** holds a bank counter; **several hubs**, on any surface, spaced apart | ADR `0014` |
| D26 | Common element | **The credit is the only value common to every company** — no scrip, no company-bound item; prices differ, the unit does not. One treasury **per holder** | ADR `0014` |
| D27 | Company accounts | Accounts are keyed by **holder and company**; a player's money sits *at* a company, so "where is my money" is a real question | ADR `0014` |
| D28 | Issuer | **The colonial federation is the only issuer** (reading C); its account may go negative, and that is the money supply. Companies are operators with their own books; interest and bounties they pay are **debt**, not creation | ADR `0015` |
| D29 | Solvency dial | A company can be **dry**. One startup dial sets its credit line: **poor** (0) / **rich** (default) / **unlimited** (sandbox, I1–I2 void). The numbers live in the data file | ADR `0015` |
| D30 | Price table | **One price table** for the whole set; a company may differ by a bounded coefficient and by its catalogue, never by a second table | §4, Q18 |
| D31 | Hub = inventory | **No separate cargo warehouse**: the hub carries the inventory, fed by inserter or robot; a contract is served from that stock | ADR `0016` (supersedes `0010`) |
| D32 | Contract load | **One to three active contracts per company**, never more; the generator refills up to the cap | ADR `0016` |
| D33 | Bankruptcy | A company in default **loses every contract and issues none**; the hub is **resold to another company**; the debt stays with the dead company, so the loss lands on the federation | ADR `0018` |
| D34 | Printing | The research raises **one step up the dial**, for the company that holds it, permanently. One research, one step | ADR `0017` |
| D35 | Contract kinds | Every contract carries a `kind`: **one-off** (once, with a deadline), **recurring at a fixed price**, **recurring at a decaying price** (`payout_decay`). One structure, one generator, one GUI. *v1 keeps the one-off only* (`0025`) | ADR `0019` |
| D36 | Decay | **Logarithmic**, anchored on the tier, floored at a **minimum price per delivered item** read from the price table; the contract stops being offered at its floor, and the number of occurrences is **derived**, never configured | ADR `0020` |
| D37 | Company character | A company's catalogue is **homogeneous in kind** (Q41 = reading A) and its identity is the pair **what it wants + how it pays**, displayed on the tooltip and the contract list, with a colour and an icon. The kind changes at most once per tier | ADR `0022` |
| D38 | Hub sites | *(proposed, awaiting confirmation)* Hubs are built on **dedicated, generated sites** instead of being spaced by a minimum distance; the site is a visible, unmineable resource patch and the check is a build-time script test with refund — the same cost the distance rule already carried | ADR `0021` |
| D39 | No physical currency | **No credit item at all**: credits are integers on a balance, never an object. No face value, no conversion, no fee, no rate technology, nothing giftable (supersedes D1-bis, D8–D10) | ADR `0023` |
| D40 | Non-nominative contracts | A contract belongs to the **company**, never to a player; any player may feed and dispatch; the payment goes to the company's balance; the cap is per company | ADR `0024` |
| D41 | v1 scope | **v1 = one mod**: one hub = one company with its inventory, one contract kind (one-off, deadline), one shop, company balances, an endowment, three tiers, min-distance spacing. Everything else is parked as evolution | ADR `0025` |
| D42 | Ledger | **Three kinds of holder**: one **cooperative** account shared by all players (no per-player wallet), one account **per company**, one **federation**. Buying moves credits from the cooperative to a company; honouring a contract moves them back | ADR `0026` |
| D43 | Expiry penalty | An expired contract costs credits: the amount is **reserved on acceptance**, released on delivery, **forfeited to the offering company** on expiry, and **displayed before acceptance** | ADR `0027` |
| D44 | Dispatch | **Manual, contract by contract** — with one shared stock and three contracts, an automatic dispatch has to pick a winner and there is no non-arbitrary rule. Goods inside a destroyed hub are **lost** | `0016`, D31 |
| D45 | Stock attribution | **First come, first served** at dispatch: the stock is common, nothing is reserved per contract, and the contract list shows what is currently coverable | `0016`, D31 |
| D46 | Price band | `cost < payout < price (= cost × 1.5)` governs **every** number in the single table | D30, `0006` |
| D47 | Escrow amount | `reserved = ceil(payout × rate)`, **one rate for the whole set**, in the price table. A contract **cannot be accepted** if the cooperative's free balance does not cover it | ADR `0028` |
| D48 | Shop safety valve | The shop **always buys**, contract or not: it is the only way back from a cooperative at zero, and therefore the safety valve of the economy | ADR `0028` |
| D49 | Hub power | The hub has a **small electric draw**: it must be connected to a grid, which is a placement constraint for free and a closed counter when unpowered | ADR `0030` |
| D50 | Naming | **`<family>-<feature>`**, lowercase, hyphenated; the family is chosen once, before the first release, and never after. Candidates: `charter`, `concord`, `outpost`; recommendation `charter` | ADR `0029` |
| D51 | Locale | Interface available in **English and French** (`locale/en`, `locale/fr`); every string goes in both files | Q49 → settled |
| D52 | Energy role | An entity's energy source is **fixed by prototype**: a hub cannot become a producer. Orbital power therefore needs a **second prototype** (a receiver), which is a second loop | ADR `0031` |
| D53 | Orbital power | **Parked as evolution.** When it returns: one receiver prototype, one up-going order type, one technology — and the failure mode of a lost shipment. Not v1 | ADR `0030`, `0031` |
| D54 | Counter spread | The counter **sells at cost × 1.5 and buys at cost**. The 50 % spread is its margin and the price of the safety valve. No pair of operations is profitable in both directions, so no arbitrage exists | ADR `0032` |
| D55 | v1 catalogue | The counter sells **materials only, no buildings**: 16 items from copper cable to processing unit, priced from the game's recipes (`docs/05-price-table.md`) | ADR `0032`, `tools/cost_table.py` |
| D56 | Counter placement | The counter is **built before oil**: its recipe contains **no oil-derived item**, one technology with red and green science, about 600 raw units | ADR `0033` |
| D57 | Tiers | A tier is **not a padlock**: it is read from the item's **oil-chain depth** (no fluid → 1, one oil step → 2, a chain → 3), so the "three tiers" of `0025` become a commercial band. The real gate is the player's research | ADR `0034` |
| D58 | Contract generation | Pool = catalogue ∩ research unlocked ∩ tier; weighted pick by the company's character; quantity from a payout band; deadline = `max(10 min, qty × machine_seconds / 2)`; **seeded RNG per company**, never `math.random` | ADR `0034` |
| D59 | Refill | **Immediate**: a slot refills as soon as its contract is completed or expires. No timer, no clock, therefore no `on_tick` | ADR `0035` |
| D60 | Balancing numbers | Scale **10** credits per raw unit · escrow **20 %** of the payout · endowment **3 000** credits issued once to the cooperative | ADR `0036` |
| D61 | Window | **Two tabs** (*Contracts*, *Counter*) in one window, with a **permanent header**: company, character line, and two numbers — `available` and `reserved` | ADR `0037`, `docs/06-interface.md` |
| D62 | Deadline display | **Digits `M:SS` and a bar**, both: the digits answer "do I have time", the bar answers "am I in trouble". Bar amber under 25 %, red under 10 %; the digits never change colour | ADR `0038` |
| D63 | Quantity control | A **text field with four presets** (`1`, `10`, `100`, `stack`) sharing one value: a preset writes the field. Clamped to `[1, 2147]`, and clamped again to what the balance allows | ADR `0038` |

### 1.2 Success indicators (observable) — **accepted by Philippe on 2026-10-25**

| # | Indicator | Measurement | Status |
|---|---|---|---|
| I1 | The hub does not replace production | On a reference save, buying a material from the hub costs **strictly more** than producing it locally (ratio ≥ 1.5), measured on 10 reference items | accepted — **`poor`/`rich` only, void in `unlimited`** |
| I2 | Contracts remain a choice | At any time **at least 1 of the 3 active contracts** is honourable from current stock, and **never all 3 without producing** — so production stays required to keep the pace | accepted 2026-10-25 (rewritten for a cap of 3) |
| I3 | The hub is used, not ignored | Philippe opens it at least **once per play session** across 5 consecutive test sessions | accepted |
| I4 | The hub is understandable without documentation | First contract delivered **without reading external docs**, using only tooltips and the GUI | accepted |
| I5 | No technical regression | No Lua error on load, 0 errors across headless scenarios, a save from version N reloadable in N+1 | accepted |

I1 and I2 carry the "balanced" requirement on their own: they decide success, and they must be turned
into concrete numbers in block 3 and tested in block 9. **The I1 threshold (ratio ≥ 1.5) was confirmed
by Philippe on 2026-10-25** along with the whole set.

### 1.3 Non-goals (what this project will never do)

- No new planet, no new surface, no rework of base recipes.
- No competitive multiplayer economy: no PvP, no player market, no leaderboard.
- No configuration where the mod requires the DLC: it plays identically with and without Space Age
  (ADR 0005), and **both configurations are tested**. "Works in my setup" is not a claim.
- No final artwork in v0.1: placeholders accepted, art pass later.
- No replacement of research: no technology on the critical path can be bought at the hub.
- Several hubs per surface are **in** (D25) and **spaced by a minimum distance**; **multi-force is out** in v1.
- ~~No credit-item in the MVP~~ — reversed 2026-10-25 (ADR `0004`), then **re-reversed the same day**:
  there is **no physical currency at all** (`0023`). What stays forbidden: **creating credits outside
  the declared channel** — the issuer's initial endowment and nothing else.
- **No player wallet in v1** (D39, D40): credits belong to companies. The bank, its deposits and its
  interest are parked (`0025`).

---

## 2. Users and usage

### 2.1 Who actually uses it

| Population | Reality | Consequence |
|---|---|---|
| **Philippe, solo** | the primary user: the mod is built for his games first | every acceptance criterion is measured on his saves (I1–I5) |
| **Other players, multiplayer** | the catalogue is **shared and single** per company; any player may fill the hub and dispatch; the payment goes to the **company's** balance (D40 — the per-player ledger of the first framing is gone) | two players dispatching in the same tick must be deterministic and re-entrant |
| **Anonymous portal users** | install from `mods.factorio.com`, never contact us | I4 (understandable without documentation) is a hard requirement, not a nicety |
| **A player without the set** | **cannot use a hub at all**: the hub does not exist in a save without the mod. Nothing travels between saves, and with no item (D39) there is nothing to hand over | the mod is self-contained; no cross-save value |

### 2.2 The usage gestures

Open the hub · read a contract and its requirements · fill the hub's inventory · dispatch · be paid on
the company's balance · buy materials in the shop. Nothing else.

*(The gestures of the first framing — binding a warehouse, converting credits into an item and back,
depositing with the bank, handing items to another player — are **withdrawn**: `0016` removed the
warehouse, `0023` removed the item and the conversion, `0024` removed the player purse, and with it the
reason to hand credits over.)*

Every one of these gestures must be reachable from the hub GUI without reading a wiki.

### 2.3 Time horizon: 2 hours to 100 hours

The requester plays anything from a **2-hour run** to a **100-hour long game**. A single static
catalogue cannot serve both: at 2 hours the player has barely launched a rocket, at 100 hours
everything is unlocked.

**Design consequence, settled here:** the economy scales by **progression tier**, never by wall-clock
time. Contracts and purchasable goods are gated on what the player has already accomplished, so the
same table serves a short and a long game. A timer-based economy would make the 2-hour run see one
contract and the 100-hour run see everything too early.

### 2.4 What usage is *not*

No API, no external consumer, no other mod is required to consume anything. Nothing is scheduled: a
contract expires or it does not, but **nothing runs while the game is closed**. There is no
"it worked overnight" metric — the only clock is game time.

---

## 3. Scope — the set

### 3.1 What was on the table

By block 3 the mechanism list read: hub/elevator, spaceport, cargo warehouses, logistics insertion,
two contract flavours, a shop, curated technologies, a credit-item, two-way conversion with a tiered
fee, a bank with four account holders, interest, bounties, a printing right, a tier model, two DLC
configurations. **That is not one mod, that is three** — so the packaging decision (D23) is what makes
the scope survivable.

**`0025` then cut it.** v1 is **one mod**: the four-mod set is parked, and the list above is kept here
as the record of what was on the table and what was set aside.

### 3.2 Core: `company-contracts`

Hub + space elevator, spaceport, **the hub's own inventory** (fed by inserter or logistics robot), the contract generator (one to three active contracts, current-tier majority + motivation minority, deadline expiry), **one-off contracts only**, credits as **one cooperative account plus one per company** (no item, no conversion), the **escrow on acceptance**, the shop with its single price table, and three progression tiers.

**v1 = one mod.** The four-mod set of `0013` (`-bank`, `-bounties`, `-mint`) is **parked**: with no
player wallet, no bounty channel and no credit line, none of the three add-ons has a subject in v1.
The core is the whole product until the loop is measured.

This is the loop that can be measured: **deliver → get paid → buy**.

Since D25 the core ships **several hubs**: each one is a company with its own catalogue, its own
treasury and its own counter. The model is keyed by company from the first line of code — a "single
hub for v1, several later" model would be a rewrite, not a setting.

### 3.3 Add-ons — behaviour only, no prototypes (D24)

| Mod | Adds | Why it is separate |
|---|---|---|
| `company-contracts-bank` | interest, AFK gating on production, deposit/withdraw screens | the only mechanism that creates credit volume (ADR 0007/0008) |
| `company-contracts-bounties` | nests, worms, science milestones, escalation on tier | a second faucet on the same treasury; a player may want contracts without bounties (ADR 0009) |
| `company-contracts-mint` | the printing right | the most dangerous switch of the design; absent by default (ADR 0012) |

A player installs the core plus whatever add-ons they want. The core **never** knows about them: the
dependency arrow points one way only (ADR 0013).

### 3.4 Out of scope

Several hubs per surface, multi-force, secondary surfaces, player markets, PvP, a floating currency, an
API for third-party mods beyond the add-on interface, final art.

### 3.5 Acceptance criteria

| # | Criterion |
|---|---|
| A1 | A fresh save honours its **first contract end to end in under 30 minutes**, with the hub and its inventory only — no second building to construct, otherwise the 2-hour horizon never starts |
| A2 | The hub's inventory accepts insertion by inserter **and** by logistics robot; a contract can only be dispatched when its full quantity is in stock (no partial delivery) |
| A3 | The **sum of every company balance, the cooperative and the federation** is unchanged by any operation except the initial endowment — no item leg, one number to assert |
| A4 | **Withdrawn** (no conversion exists) — replaced by: the shop shows the buying price and the selling price of an item **before** the transaction, and I4 holds on that screen |
| A5 | The core loads and runs the same scenarios in **both** DLC configurations (headless, two matrices) |
| A6 | No Lua error on load, no desync in a two-player headless session where both players fill and dispatch contracts in the same tick |
| A7 | A contract generated on an acquired technology is always completable with what the player already produces (checked by the generator, not by hand) |
| A8 | Each add-on installs, runs and is **removed** without breaking an existing save |
| A9 | Two hubs on the same surface are refused **below the minimum distance, or off-site if D38 is adopted**, with a message and without losing the item; two hubs on the same surface offer **different** contract sets (different kinds) |
| A10 | The conservation invariant is asserted in `poor` and `rich`; in `unlimited` the game **says** it is a sandbox and the harness asserts only that nothing crashes |
| A11 | A company driven to default **loses its contracts, issues none, and is resold**; the resale hands the building to a different company and the dead company's debt stays with it (headless assertion) |
| A12 | A company's contract list contains **the single kind of that company**, and the kind is displayed; across two companies on the same surface the kinds **differ**; a `recurring_decaying` payout is **strictly lower at each occurrence, logarithmically**, and stops being offered at its per-item floor; the GUI shows the **next** payout before acceptance |
| A13 | An expired contract moves **exactly the reserved amount** from the cooperative to the offering company; delivery releases the hold; the reserved amount is **visible before acceptance** |
| A14 | From a cooperative at **zero**, selling goods to a hub (with no contract active) restores a spendable balance and allows a contract to be accepted again — no deadlock |
| A15 | **Buying then immediately reselling always loses credits** (counter spread, D54): no pair of operations is profitable in both directions |
| A16 | **No ingredient of the counter's recipe has oil anywhere in its tree** (D56), checked with the same measurement that builds the price table |
| A17 | With a tier-1 catalogue, **every item offered can be produced with red/green research and no fluid** (D57) |
| A18 | **No generated contract ever contains an item whose recipe is not unlocked** for the force (D58) — a trap that steals an escrow would fail the suite |
| A19 | The header's two numbers always satisfy `available + reserved = total` for the cooperative (D61) |
| A20 | At 100 % and at 150 % GUI scale, **no text is truncated and no control falls outside the window** |
| A21 | Every visible string exists in **both** `locale/en` and `locale/fr`; a missing key shows as the key itself and is a failure, not a fallback |
| A22 | An action button is **never enabled when the action would fail** (no coverage, no goods in the hub, no power) |
| A23 | The quantity field and the presets **never disagree**: a preset writes the field, and the action always acts on the displayed value |
| A24 | No preset can exceed what the balance allows; a preset that would is **clamped and displays the clamped value before the click** |

---

## 4. Technical constraints and reuse

**Block 4 — filled 2026-10-25.** The v1 technical shape is §4.2; what the set looked like before the
cut is kept as §4.3. Already certain:

- Language: **Lua 5.2** (Factorio API), no .NET, no PostgreSQL — the preferred stack does not apply.
- Persistent state: `storage` (the 2.0 rename of `global`) — one `storage` table **per mod**, which is
  what makes add-ons separable at all.
- In 2.0+, `recipe.categories` replaces `recipe.category`.
- **Money is integer arithmetic**: no `/` or `*` on a credit amount without an explicit rounding rule
  that favours the hub (D7).
- **Space Age optional**: the core declares only `"? space-age"` (optional, loads after) and branches
  on `mods["space-age"]`; the behaviour is carried by the core's own prototypes (ADR 0005).
- **Cross-mod communication**: only `remote.add_interface` / `remote.call` / `remote.interfaces`. The
  core exposes a versioned `api_version` and named events; add-ons never write the ledger directly.
- **Cross-mod GUI**: a mod cannot edit another mod's GUI. An add-on draws its own window, or fills a
  container element the core hands over through its interface. No widget may be owned by two mods.
- **Dependency direction**: add-ons require the core (`"company-contracts >= 0.1.0"`); the core
  requires only `base` and optionally `space-age`. Never the reverse.
- **Reuse**: `rocket-silo` exists in base 2.1 and can serve as a visual anchor.
  `cargo-landing-pad` and `cargo-pod` are **Space Age prototypes**: usable only in the DLC
  configuration. The hub's own prototypes carry the behaviour in both cases. No existing prototype
  may be overwritten.
- **`luac`**: build Lua 5.2 locally, or rely on headless load failures (§0.2).

### 4.2 The v1 technical shape — one mod, no per-tick work

| Piece | Choice | Why |
|---|---|---|
| **Hub entity** | a **`container`** cloned from a large chest, with its own `inventory_size` | inserters and logistics robots work natively, with no script; the vanilla inventory is exactly what `0016` asks for |
| **Hub GUI** | `on_gui_opened` opens **our own frame**; the vanilla chest GUI is not used | one window, one style, and no dependency on the container layout |
| **Control flow** | **no `on_tick`**. Everything hangs on events: `on_built_entity`, `on_gui_opened`, `on_gui_click`, `on_gui_closed`, `on_entity_died`, `on_player_mined_entity` | a per-tick loop over hubs is the classic way to make a mod expensive; there is nothing here that needs a clock |
| **Deadlines** | the deadline is a **number of ticks** stored with the contract; expiry is **evaluated on read** and applied once, with a flag | deterministic, zero cost, and correct after a save/load |
| **State** | one `storage` table: `storage.companies`, `storage.hubs[unit_number]`, `storage.ledger {cooperative, federation}`, `storage.contracts` | the 2.0 rename of `global`; one owned table, no cross-mod access in v1 |
| **Randomness** | **never `math.random`**. A seeded generator per company, stored in `storage`, advanced only on generation | a shared random stream is how a mod desyncs in multiplayer |
| **Money** | integers only, `ceil` on the escrow (D47), explicit rounding everywhere | D7 and D47 |
| **Price table** | a plain Lua file (`scripts/prices.lua`) `require`d by `control.lua`, one table, versioned with the mod | readable, diffable, and no settings dance; it is a *design* artefact, not a preference |
| **Locale** | **`locale/en/` and `locale/fr/`** (D51) | the portal audience is international |
| **Power** | an `electric` energy source with a low draw (`0030`) | a hub must be connected to a grid: a placement constraint for free |
| **Space Age** | `"dependencies": ["base", "? space-age"]`; nothing else | D5 — the mod loads in both configurations and tests both |

**What is deliberately absent in v1**: no `remote.add_interface` (nothing to talk to), no add-on hooks,
no `on_tick`, no custom `tile`, no `resource` prototype, no second GUI window.

### 4.3 What the four-mod set needed, kept for when it returns

The three bullets above about cross-mod communication (`remote.add_interface`, `api_version`, named
events), cross-mod GUI (a mod cannot edit another mod's window, and no widget may be owned by two mods)
and dependency direction (`add-on >= core`, never the reverse) exist **only** for the multi-mod design
of `0013`. v1 has no add-on, so none of them applies — they are kept here because the evolution will
need them, and because rediscovering them costs a day.



## 5. Data

`[TO FILL — block 5]` Contract = `storage` schema + save version number + migrations.

Already certain:
- **Company record** (D25): `id`, `name`, `surface`, `position`, `treasury`, `catalogue_seed`,
  `state` (open / dry). One record per hub entity, linked by `unit_number`. It is the owner of a
  catalogue, a treasury and a counter.
- **Accounts** (D42): three kinds only — **one cooperative** shared by all players, **one per company**,
  **one federation**. No per-player balance, no item. Integer amounts.
- **Reservation** (D43): accepting a contract holds an amount on the cooperative; delivery releases it,
  expiry forfeits it to the company. The amount is displayed before acceptance.
- **Conservation invariant** (A3): `sum(company balances) + cooperative + federation` is constant,
  except through the initial endowment (D28). One number, no item leg. Tested in CI at every
  configuration.
- **Hub inventory** (D31): one custom inventory on the hub entity, fed by inserter or logistics robot.
  Up to three contracts read from it. No binding state, no second building.
- **Solvency** (D29): a company pays out of its own balance plus a credit line drawn on the
  federation. The line is set by the startup dial. At zero and line exhausted: **default** (`0018`) —
  contracts lost, no new ones, the hub is resold.
- **Federation** (D28): the only holder whose balance may go negative; that negative is the money
  supply, bounded by the dial. It earns the interest on the debts it holds.
- **Price table**: one versioned, human-readable data file; every price derives from a production cost
  (raw + energy + time) inside the band `cost < contract payout < hub price (= cost × 1.5)` (Q18).
- **Retention**: nothing to design. A save carries its own history; no external log.

## 6. UI/UX

`[TO FILL — block 6]` Known constraints: Lua GUI, no full rebuild every tick, no cross-mod widget
ownership. The hub is the single entry point; add-ons open from it.

## 7. Operations

`[TO FILL — block 7]` Reduced to three commitments (§0.1), multiplied by the number of published mods.
Release process: **four listings, four changelogs, one compatibility matrix**. `[to verify — Q09]`.

## 8. Security and permissions

`[TO FILL — block 8]` Four concerns only: the publishing token stays outside the repository, no
third-party prototype is overwritten, multiplayer determinism (the server is authoritative), and the
ledger is readable by add-ons but writable only by the core.

## 9. Quality

`[TO FILL — block 9]` Headless harness operational (§0.2). `luac -p` in pre-commit **if** Lua 5.2 is
built. Deterministic scenarios with Lua assertions.

Test matrix: 2 DLC configurations × (core alone, core + bank, core + bounties, core + mint) = 8
headless runs minimum, plus a two-player determinism scenario.

## 10. Risks, decisions, schedule

`[TO FILL — block 10]` Main risks already identified:

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Scope: 28 decisions, four mods, one maintainer | high | ship nothing | the core first; add-ons only once the core holds I1/I2 |
| Balance: six interacting levers (payout, price, fee, rate, interest, technologies) | high | I1/I2 unprovable | tune in order: face value → fixed fee → rate curve → interest → technologies |
| Money creation by accident | medium | I1 dies silently | conservation test in CI, per configuration |
| Cross-mod API churn | medium | add-ons rewritten twice | freeze `api_version` before the first add-on |
| Warehouse UX: goods lost on expiry | medium | player loses hours silently | Q24 settled before any warehouse code |

**No calendar date until Q05, Q08–Q09, Q15–Q29 are settled.** Blocks 4–10 are estimated in sessions,
not weeks.

---

## Appendix A — Open questions

**After `0025` a v1 cut applies.** **No open question blocks v1 any more** — Q46 and Q47 were the last
two and they are closed by `0028`. Every remaining open question belongs to a parked feature and is
resolved with its feature, not before.

| ID | Question | Impact if we get it wrong | Owner | State |
|---|---|---|---|---|
| ~~Q01 (D1)~~ | ~~Virtual credits or physical item?~~ → **virtual (1a), then item in the MVP (D1-bis)** | — | Philippe | **settled** |
| ~~Q02 (D3)~~ | ~~Curated list or full tree?~~ → **curated list (2a)** | — | Philippe | **settled** |
| ~~Q03 (D6)~~ | ~~Public GitHub or private Gitea?~~ → **public GitHub `walbydev` (3a)** | — | Philippe | **settled** |
| ~~Q04 (D2)~~ | ~~Insertion or rocket launch?~~ → **warehouses bound to a contract, dispatched through the elevator (D21) — no rocket** | — | Philippe | **settled 2026-10-25** |
| ~~Q06 (D5)~~ | ~~Space Age hard dependency?~~ → **plays with and without the DLC** | — | Philippe | **settled, ADR 0005** |
| ~~Q07~~ | ~~MIT or LGPL-3?~~ → **MIT** | — | Philippe | **settled** |
| ~~Q10~~ | ~~Are the 5 indicators accepted? Ratio ≥ 1.5?~~ → **all accepted** | — | Philippe | **settled** |
| ~~Q11~~ | ~~1b: extension point or planned wave 2?~~ → **the item is in the MVP** | — | Philippe | **settled, ADR 0004** |
| ~~Q12~~ | ~~Conversion spread?~~ → **fixed fee + amount-dependent rate (D9)** | — | Philippe | **settled** |
| ~~Q13~~ | ~~Fixed or floating rate?~~ → **fixed numeric table; the cost varies with the amount** | — | Philippe | **settled** |
| ~~Q14~~ | ~~Multiplayer in the MVP?~~ → **solo and multiplayer, gifting only via items** | — | Philippe | **settled** |
| ~~Q17~~ | ~~Catalogue by tier or by time?~~ → **by progression tier (D13)** | — | Philippe | **settled** |
| ~~Q19~~ | ~~AFK signal: movement or production?~~ → **production (D18)** | — | Philippe | **settled** |
| ~~Q20~~ | ~~One treasury or separate faucets?~~ → **one treasury (D16)** | — | Philippe | **settled** |
| ~~Q26~~ | ~~Cut interest and bounties to wave 2?~~ → **reframed: they become add-ons (D23)** | — | Philippe | **settled 2026-10-25** |
| ~~Q05~~ | ~~A single hub or several?~~ → **several hubs per surface, on any surface, spaced apart (D25)** | — | Philippe | **settled 2026-10-25** |
| ~~Q08~~ | ~~Late penalty or dry expiry?~~ → **a penalty in credits: the amount is reserved on acceptance and forfeited to the company on expiry** (D43) | — | Philippe | **settled 2026-10-25, ADR 0027** |
| ~~Q15~~ | ~~What funds the interest?~~ → **parked with the bank (`0025`): no player wallet, no interest** | — | Philippe | **parked 2026-10-25** |
| Q16 | Rate-improvement technologies: **researched normally** (proposal) or bought at the hub? | Bought: the hub funds its own discount — a self-financing loop | Philippe | block 3 |
| ~~Q18~~ | ~~Is the band the rule for every number?~~ → **yes**: `cost < payout < price (= cost × 1.5)` for every entry | — | Philippe | **settled 2026-10-25** |
| Q19-bis | In multiplayer, does a player who does not produce accrue interest while **another** player's factory runs? | Force statistics are shared: without an attribution rule the AFK rule means nothing in multi | Philippe | block 3 |
| Q21 | Bounty escalation anchored on **tier** (proposal) rather than **evolution factor**? | Evolution: farming nests becomes the optimal strategy — exactly what the bounty pays for | Philippe | block 3 |
| Q22 | Science-pack bounty: **per unit** or **per milestone** — first *N* packs of each new tier then closed (proposal)? | Per unit: a large factory prints credits and the hub becomes decorative | Philippe | block 3 |
| ~~Q23~~ | ~~What funds the federation's account?~~ → **it issues**: its negative balance is the money supply, bounded by the D29 dial. It earns the interest on the debts it holds | — | Philippe | **settled in principle 2026-10-25, ADR 0015** |
| ~~Q24~~ | ~~Dispatch and loss rules?~~ → **manual, contract by contract; goods inside a destroyed hub are lost** (D44) | — | Philippe | **settled 2026-10-25** |
| ~~Q25~~ | ~~Printing: creation or materialisation?~~ → **neither: the research raises the dial one step, per company, permanently (D34)** | — | Philippe | **settled 2026-10-25, ADR 0017** |
| Q27 | **Repository layout**: one monorepo holding the four mods (proposal) or four repositories? | Four repos: four CI, four changelogs, four places to be wrong | Philippe | block 4 |
| Q28 | **Publication**: four portal listings with the core required (proposal) or a single pack? | A pack: the player cannot choose, which voids D23 | Philippe | block 7 |
| Q29 | **Names**: `company-contracts` + `-bank` / `-bounties` / `-mint`? | Renaming after release is a migration for every existing save | Philippe | block 4 |
| ~~Q30~~ | ~~Who issues the unit?~~ → **C: the federation issues and guarantees; companies keep their own books** (D28) | — | Philippe | **settled 2026-10-25, ADR 0015** |
| ~~Q31~~ | ~~May a company pay beyond its balance?~~ → **it can go dry, and one dial (poor / rich / unlimited) sets the credit line** (D29) | — | Philippe | **settled 2026-10-25, ADR 0015** |
| ~~Q33~~ | ~~Does a company repay its debt?~~ → **no: it dies.** Contracts lost, none issued, the hub is resold to another company, the debt stays with the dead company and lands on the federation (D33) | — | Philippe | **settled 2026-10-25, ADR 0018** |
| Q34 | **Resale terms**: who buys the dead hub (the federation as broker, a pool of neutral companies, the player under another name)? At what price? What happens to the stock inside? Does the buyer get a **fresh** catalogue and line? | A buyer with no cost and no constraint turns default into a free reset | Philippe | block 3 |
| ~~Q35~~ | ~~I2 rewritten for a cap of three~~ → **accepted**: "at least 1 of the 3 from stock, never all 3 without producing" | — | Philippe | **settled 2026-10-25** |
| ~~Q36~~ | ~~Shared stock: first-come or reserved?~~ → **first come, first served**; nothing is reserved per contract (D45) | — | Philippe | **settled 2026-10-25** |
| Q37 | The dial step (D34): does the research **stop at `rich`**, or can it reach `unlimited` mid-game — in which case I1/I2 are void from that moment, not from map creation? | Reaching `unlimited` by research puts the sandbox inside the balanced game | Philippe | block 3 |
| ~~Q38~~ | ~~Where is the floor?~~ → **a minimum price per delivered item, from the price table; the contract stops being offered there** (D36). The curve is logarithmic, anchored on the tier | — | Philippe | **settled 2026-10-25, ADR 0020** |
| Q38-bis | Can the player **abandon** a recurring contract — freely, with a penalty, or never? | Without an answer, a contract signed at tier 2 is a prison at tier 4 | Philippe | block 3 |
| Q38-ter | Is the per-item floor **below** the local production cost (the contract dies by itself in the player's interest) or **above** it (a thin margin, farmable forever)? | Above: the decaying kind never ends, and `0019`'s purpose is lost | Philippe | block 3 |
| ~~Q39~~ | ~~Does a recurring contract hold a slot?~~ → **answered as "one contract kind at a time", which is ambiguous — see Q41** | — | Philippe | **reformulated 2026-10-25** |
| ~~Q40~~ | ~~Decay shape?~~ → **logarithmic, anchored on the tier, floored per delivered item** (D36) | — | Philippe | **settled 2026-10-25, ADR 0020** |
| ~~Q41~~ | ~~"One contract kind at a time"~~ → **reading A: the catalogue of a company is homogeneous in kind**; character = what it wants + how it pays, with stability, colour, icon and one-line display (D37) | — | Philippe | **settled 2026-10-25, ADR 0022** |
| Q42 | **A guaranteed hub site near the spawn**: nothing in 2.1's data guarantees a patch in the starting area, and a fresh save with no site shows no hub at all | The mod would be invisible during the whole 2-hour horizon (A1) | Philippe | block 3 |
| Q43 | **Existing saves**: autoplace does not run retroactively — seed a site by script, or declare the mod **new-game only**? | New-game only is honest and cheap; a script seeding sites is a migration to maintain forever | Philippe | block 3 |
| Q44 | **How many sites per surface**: a fixed number, a map-generation setting, or the autoplace controls? | A fixed number makes hubs scarce; the controls let the player decide how much economy he wants | Philippe | block 3 |
| ~~Q45~~ | ~~Who holds the money?~~ → **a cooperative shared by all players + one account per company + the federation; no per-player wallet** (D42) | — | Philippe | **settled 2026-10-25, ADR 0026** |
| ~~Q46~~ | ~~How much is reserved?~~ → **a percentage of the payout**, one rate for the whole set, `ceil`, in the price table (D47) | — | Philippe | **settled 2026-10-25, ADR 0028** |
| ~~Q47~~ | ~~Coverage?~~ → **required**: a contract cannot be accepted if the cooperative's free balance does not cover the reservation; the shop buying goods is the way back from zero (D48) | — | Philippe | **settled 2026-10-25, ADR 0028** |
| Q32 | Moving credits between **two companies**: item conversion only, or a transfer between counters with a fee? | Free transfers: no reason to hold money anywhere; for-pay only: tedious for a legitimate player | Philippe | block 4 |
| ~~Q48~~ | ~~Orbital power: v1 or parked?~~ → **parked as evolution** (D53); the hub produces nothing in v1, it only consumes | — | Philippe | **settled 2026-10-25** |
| ~~Q49~~ | ~~Interface language?~~ → **English and French** (D51) | — | Philippe | **settled 2026-10-25** |
| ~~Q50~~ | ~~Family prefix?~~ → **`comptoir`**: mod `comptoir-contracts`, repo renamed, package `comptoir-contracts_<version>.zip` (D50, ADR `0029`) | — | Philippe | **settled 2026-10-25** |
| Q09 | Exact publishing procedure on `mods.factorio.com` (upload, moderation, delay) | `[to verify]` — no credible release date without it | cadrage (research) | block 7 |
| ~~Q51~~ | ~~Three balancing numbers?~~ → **scale 10, escrow 20 %, endowment 3 000** (D60, ADR `0036`) | — | Philippe | **settled 2026-10-25** |
| ~~Q52~~ | ~~The three tier thresholds~~ → **dissolved**: a tier is read from the item's oil-chain depth, not from a technology (D57). The counter itself is gated by one early red/green technology (D56) | — | Philippe | **settled 2026-10-25** |
| ~~Q53~~ | ~~Cadence: immediate or timer?~~ → **immediate**, no timer, therefore no clock (D59, ADR `0035`) | — | Philippe | **settled 2026-10-25** |
| ~~Q54~~ | ~~Deadline display?~~ → **digits and bar** (D62, ADR `0038`) | — | Philippe | **settled 2026-10-25** |
| ~~Q55~~ | ~~Quantity control?~~ → **a field with presets** `1/10/100/stack`, one shared value (D63, ADR `0038`) | — | Philippe | **settled 2026-10-25** |

---

## Appendix B — Sources and incoming documents

| File | Origin | What was retained |
|---|---|---|
| `docs/entrants/brief-cadrage-2026-10-25.md` | Hermes `web-coder`, 2026-10-25 (French, kept verbatim) | Original request, verified technical facts (§0.2), D1–D6, balancing leads, non-goals |
| `adr/0001` … `adr/0013` | this framing | every structuring decision, with the rejected alternatives and why |
| Factorio wiki | upstream | *Modding FAQ* (dependency prefixes), *Script interfaces* (`remote`), FFF 305 (GUI) |
