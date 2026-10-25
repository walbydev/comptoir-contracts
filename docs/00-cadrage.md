# Framing — Company contracts (Factorio 2.1 mod set)

> Version: 0.3 · Date: 2026-10-25 · Requested by: Philippe Ryf
> Status: **blocks 1–3 consolidated** — 32 decisions recorded, 14 questions still open.
> Repository: `walbydev/factorio-contrats` (public GitHub, MIT) — created and verified 2026-10-25.
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

**Decision of 2026-10-25: public GitHub `walbydev/factorio-contrats`** (option 3a), MIT licence,
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
| D1-bis | Credit-item, final answer | **The item exists in the MVP**, convertible **both ways at the hub only**; bearer asset: giftable, storable in a chest | ADR `0004` |
| D2 | Delivery method, first answer | Insertion into the hub or rocket launch — **superseded by D21** (warehouses + elevator, no rocket) | ADR `0010` |
| D3 | Purchasable technologies | **Curated list** (2a): never the technology that unlocks the hub, never a tech on the critical path | ADR `0002` |
| D4 | Number of hubs | One hub or several — **settled by D25**: several per surface | ADR `0014` |
| D5 | Space Age | **Works with and without the DLC**: prototypes owned by the mod, SA assets reused only when the DLC is present | ADR `0005` |
| D6 | Repository forge | **Public GitHub `walbydev`** (3a), licence **MIT** | ADR `0003` |
| D7 | Money format | **Integer credits only** — no cents, no fractional credit anywhere, explicit rounding | ADR `0006` |
| D8 | Credit-item value | **Fixed face value**, forever, set in the price table | ADR `0006` |
| D9 | Conversion cost | **Fixed fee + amount-dependent (degressive) rate** | ADR `0006` |
| D10 | Rate improvements | **Two technologies** on rate and fixed fee — *proposal*: researched, not bought (Q16) | ADR `0006` |
| D11 | Bank | **Deposit, withdraw, regular interest** — funding rule open (Q15) | ADR `0007` |
| D12 | Players | **Solo and multiplayer**; gifting exists **only via credit-items** | §2 |
| D13 | Game horizon | **2 h speedrun to 100 h long game** — the economy scales by **progression tier**, not wall-clock | §2 |
| D14 | Passive player | **No income without activity**: interest pauses when nothing is produced | ADR `0008` |
| D15 | Bounties | **Nests, worms and science packs pay escalating bonuses** | ADR `0009` |
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

### 1.2 Success indicators (observable) — **accepted by Philippe on 2026-10-25**

| # | Indicator | Measurement | Status |
|---|---|---|---|
| I1 | The hub does not replace production | On a reference save, buying a material from the hub costs **strictly more** than producing it locally (ratio ≥ 1.5), measured on 10 reference items | accepted — **`poor`/`rich` only, void in `unlimited`** |
| I2 | Contracts remain a choice | At any time the player can honour at least **2 contracts out of 4** from current stock, and **at most 3 out of 4** without producing — so production is required to keep the pace | accepted |
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
- No second hub per surface, no multi-force, in the MVP (Q05).
- ~~No credit-item in the MVP~~ — **reversed 2026-10-25** (ADR 0004): the item is in the MVP. What
  stays forbidden is **creating credits outside the declared channels** — no recipe, no chest trick,
  no script, no third path.

---

## 2. Users and usage

### 2.1 Who actually uses it

| Population | Reality | Consequence |
|---|---|---|
| **Philippe, solo** | the primary user: the mod is built for his games first | every acceptance criterion is measured on his saves (I1–I5) |
| **Other players, multiplayer** | each player has their **own** ledger and bank; credits are per player, not shared | a conversion and a deposit must be deterministic and re-entrant (same tick, two players) |
| **Anonymous portal users** | install from `mods.factorio.com`, never contact us | I4 (understandable without documentation) is a hard requirement, not a nicety |
| **A player without the set** | **cannot receive credits**: the credit-item has no meaning in a save where the mod is absent | gifting is only meaningful between equipped players — stated in the mod description |

### 2.2 The usage gestures

Open the hub · read a contract and its requirements · bind a warehouse · fill it · dispatch · be paid
in credits and/or a technology · buy materials or a curated technology · **convert credits into
credit-items** · **convert credit-items into credits** · **deposit into the bank** · **withdraw** ·
**hand items to another player** (chest, ground, direct insertion). Nothing else.

Every one of these gestures must be reachable from the hub GUI (or the item itself for the item form)
without reading a wiki.

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

### 3.2 Core: `company-contracts`

Hub + space elevator, spaceport, cargo warehouses bound to one contract each and fed by inserter or
logistics robot, the contract generator (current-tier majority + motivation minority, dry expiry),
virtual credits, the credit-item, two-way conversion with a fixed fee and a degressive rate, the
ledger with its accounts, the shop, the curated technology list, the tier model.

This is the loop that can be measured: **deliver → get paid → convert → buy**.

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
| A1 | A fresh save honours its **first contract end to end in under 30 minutes**, and that first contract needs **no warehouse** — otherwise the 2-hour horizon never starts |
| A2 | A bound warehouse accepts insertion by inserter **and** by logistics robot; an unbound one is inert and **says so** |
| A3 | Converting credits to items and back **never increases the total** (automated test, integers only) |
| A4 | The conversion fee is displayed **before** confirmation, and I4 holds on that same screen |
| A5 | The core loads and runs the same scenarios in **both** DLC configurations (headless, two matrices) |
| A6 | No Lua error on load, no desync in a two-player headless session performing conversions and dispatches in the same tick |
| A7 | A contract generated on an acquired technology is always completable with what the player already produces (checked by the generator, not by hand) |
| A8 | Each add-on installs, runs and is **removed** without breaking an existing save |
| A9 | Two hubs on the same surface are refused below the minimum distance, **with a message and without losing the item**; two hubs on the same surface offer **different** contract sets |
| A10 | The conservation invariant is asserted in `poor` and `rich`; in `unlimited` the game **says** it is a sandbox and the harness asserts only that nothing crashes |

---

## 4. Technical constraints and reuse

`[TO FILL — block 4]` See §0.2 for the verified test chain. Already certain:

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

## 5. Data

`[TO FILL — block 5]` Contract = `storage` schema + save version number + migrations.

Already certain:
- **Company record** (D25): `id`, `name`, `surface`, `position`, `treasury`, `catalogue_seed`,
  `state` (open / dry). One record per hub entity, linked by `unit_number`. It is the owner of a
  catalogue, a treasury and a counter.
- **Accounts**: keyed by `(holder, company)` — holder = player, company, federation. Integer balances.
- **Conservation invariant**: `sum(company treasuries) + sum(player accounts) + credits held as
  items` is constant, except through the issuer (Q30). Tested in CI at every configuration.
- **Solvency** (proposal, Q31): a company pays contracts and interest **out of its own treasury** and
  cannot go below zero; a company at zero stops offering new contracts until it sells.
- **Warehouse binding**: by `unit_number`, one contract per warehouse, states `inert / bound / ready /
  dispatching`; an unbound warehouse refuses items and explains why.
- **Federation revenue**: `[À TRANCHER — Q23]` proposal: its commercial margin — it buys deliveries
  below the price at which it resells materials and technologies.
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
| Q08 | Late penalty or **dry expiry** of a contract? | A penalty needs a debt or reputation mechanic, otherwise the contract is neutral | Philippe | block 3 |
| ~~Q15~~ | ~~What funds the interest?~~ → **the company's margin, then its credit line (debt). Only the rate remains, and it belongs to the price table (Q18)** | — | Philippe | **settled in principle 2026-10-25, ADR 0015** |
| Q16 | Rate-improvement technologies: **researched normally** (proposal) or bought at the hub? | Bought: the hub funds its own discount — a self-financing loop | Philippe | block 3 |
| Q18 | Is the price **band** `cost < payout < price (= cost × 1.5)` the rule for every number? | Ad-hoc numbers: I1 is unmeasurable and the table gets rewritten three times | Philippe | block 3 |
| Q19-bis | In multiplayer, does a player who does not produce accrue interest while **another** player's factory runs? | Force statistics are shared: without an attribution rule the AFK rule means nothing in multi | Philippe | block 3 |
| Q21 | Bounty escalation anchored on **tier** (proposal) rather than **evolution factor**? | Evolution: farming nests becomes the optimal strategy — exactly what the bounty pays for | Philippe | block 3 |
| Q22 | Science-pack bounty: **per unit** or **per milestone** — first *N* packs of each new tier then closed (proposal)? | Per unit: a large factory prints credits and the hub becomes decorative | Philippe | block 3 |
| ~~Q23~~ | ~~What funds the federation's account?~~ → **it issues**: its negative balance is the money supply, bounded by the D29 dial. It earns the interest on the debts it holds | — | Philippe | **settled in principle 2026-10-25, ADR 0015** |
| Q24 | **Dispatch**: manual validation or automatic on quantities reached? And what happens to goods inside a warehouse on **expiry**, **destruction** or **unbinding**? | Silence here = a player silently loses hours of production | Philippe | block 3 |
| Q25 | **Printing, reformulated by `0015`**: the research unlocks what — (a) a one-off issuance, (b) a recurring issuance bounded by the dial, (c) one step up on the dial? | (b) with a loose bound is a printer with a nice name; (c) is the cleanest and the easiest to audit | Philippe | block 3 |
| Q27 | **Repository layout**: one monorepo holding the four mods (proposal) or four repositories? | Four repos: four CI, four changelogs, four places to be wrong | Philippe | block 4 |
| Q28 | **Publication**: four portal listings with the core required (proposal) or a single pack? | A pack: the player cannot choose, which voids D23 | Philippe | block 7 |
| Q29 | **Names**: `company-contracts` + `-bank` / `-bounties` / `-mint`? | Renaming after release is a migration for every existing save | Philippe | block 4 |
| ~~Q30~~ | ~~Who issues the unit?~~ → **C: the federation issues and guarantees; companies keep their own books** (D28) | — | Philippe | **settled 2026-10-25, ADR 0015** |
| ~~Q31~~ | ~~May a company pay beyond its balance?~~ → **it can go dry, and one dial (poor / rich / unlimited) sets the credit line** (D29) | — | Philippe | **settled 2026-10-25, ADR 0015** |
| Q33 | **Does a company repay its debt to the federation, and at what rate?** What happens to a company deeply in debt that never sells? | A free, never-repaid line means `unlimited` is the only honest mode and `poor` is decorative | Philippe | block 3 |
| Q32 | Moving credits between **two companies**: item conversion only, or a transfer between counters with a fee? | Free transfers: no reason to hold money anywhere; for-pay only: tedious for a legitimate player | Philippe | block 4 |
| Q09 | Exact publishing procedure on `mods.factorio.com` (upload, moderation, delay) | `[to verify]` — no credible release date without it | cadrage (research) | block 7 |

---

## Appendix B — Sources and incoming documents

| File | Origin | What was retained |
|---|---|---|
| `docs/entrants/brief-cadrage-2026-10-25.md` | Hermes `web-coder`, 2026-10-25 (French, kept verbatim) | Original request, verified technical facts (§0.2), D1–D6, balancing leads, non-goals |
| `adr/0001` … `adr/0013` | this framing | every structuring decision, with the rejected alternatives and why |
| Factorio wiki | upstream | *Modding FAQ* (dependency prefixes), *Script interfaces* (`remote`), FFF 305 (GUI) |
