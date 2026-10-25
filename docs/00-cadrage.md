# Framing — Company contracts (Factorio 2.1 mod)

> Version: 0.2 · Date: 2026-10-25 · Requested by: Philippe Ryf
> Status: **blocks 1–2 closed 2026-10-25; block 3 open** (decisions D1–D17 recorded, questions
> Q04–Q05, Q08–Q09, Q15–Q22 awaiting the requester). Block 3 (scope) next.
> Repository: `walbydev/factorio-contrats` (public GitHub, MIT) — created and verified 2026-10-25.
> No development before tag `v0.1-cadrage`.

**Language convention:** this document, all ADRs and all source code are written in **English**.
Conversation with the requester happens in French; deliverables do not.

---

## 0. Phase 0 — Project environment

Declared 2026-10-25, before any substantive decision. **Every environment question is now settled**
(forge, licence, distribution): Phase 0 is closed.

### 0.1 Nature of the deliverable

This is **not a service**: it is a **Factorio game mod** (Lua 5.2, data API + runtime API). The
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
| Distribution channel | Official portal `mods.factorio.com` | Manual upload of `factorio-contrats_x.y.z.zip`. Exact upload and moderation procedure: `[to verify]` in block 7 (Q09). |
| Required account | Philippe's factorio.com account + publishing API token | Token stored **outside the repository**, named `FACTORIO_API_KEY`; never committed, never copied into a document. |
| Code licence | **MIT — decided 2026-10-25** (Q07 closed) | ADR `0003`. LGPL-3 rejected: a publicly distributed mod benefits from showing its code. |
| Target game version | Factorio **2.1.x**, base only for the MVP (D5) | `info.json`: `"factorio_version": "2.1"`. Space Age as an optional dependency, never a hard one in the MVP. |
| Cost | 0 (no service, no cloud) | Philippe already owns the Factorio licence; headless test binaries do not require one. |

### 0.4 Code repository — settled

**Decision of 2026-10-25: public GitHub `walbydev/factorio-contrats`** (option 3a), MIT licence.
ADR `0003`. Verified through the API: public repository created, `HTTP 201`, `visibility: public`.
The "private Gitea" option is rejected: a publicly distributed mod whose code is private loses its
community value, and the homelab gains nothing from it.

Consequence: this document is **now versioned**. The handoff brief becomes a frozen input
(`docs/entrants/`), not a living source.

### 0.5 How Phase 0 reshapes the remaining blocks

- Block 2 (users and usage): one real user (Philippe, the player) plus the anonymous portal
  population → usage is described in **play sessions**, not requests per day.
- Block 5 (data): "data" means persistent `storage` state plus the mod's prototypes. Data contract =
  `storage` schema with a save version. Retention = the player's save lifetime.
  **Constraint added by D1**: the schema must keep an extension point for a complementary
  credit-item, without migrating contract history.
- Block 7 (operations): reduced to save compatibility and the release procedure (§0.1, §0.3).
- Block 8 (security): no permissions, no authentication; the only concerns are **the publishing
  token** and **not overwriting other mods' prototypes**.

---

## 1. Vision and non-goals

**Raw vision statement (requester's own words, original French):**

> « J'aime bien l'idée des contrats de compagnies via un hub de communication commerciale ce qui
> permet d'obtenir des crédits et/ou des technologies. Les crédits accumulés permettent d'acheter
> des stacks de matériaux ou des technologies se passant de recherche. J'aimerais quelque chose
> d'équilibré. Le hub est un ascenseur spatial relié à un spatioport qui permet aux marchands de
> venir chercher les commandes des contrats réalisés. »

**Restated vision:** a commercial hub (space elevator plus a spaceport) offers delivery contracts to
the company; delivering them earns credits and/or technologies, and credits buy stacks of materials
or technologies without research — a **complement** to local production, never a substitute.

**What this is not (to prevent drift across blocks):** it is not an economy mod, it is not an
alternative tech tree, it is not a new planet or a new production chain. The added loop is **an
exchange loop** grafted onto what already exists.

### 1.1 Decisions already settled in block 1

| ID | Question | Philippe's decision (2026-10-25) | Trace |
|---|---|---|---|
| D1 | Nature of credits, first answer | **Virtual currency** (1a) — *superseded the same day* | ADR `0001` (superseded) |
| D1-bis | Credit-item, final answer | **The item exists in the MVP**, convertible **both ways at the hub only**; bearer asset: giftable to another player, storable in a chest | ADR `0004` |
| D3 | Purchasable technologies | **Curated list** (2a): never the technology that unlocks the hub, never a tech on the critical path | ADR `0002` |
| D5 | Space Age | **Works with and without the DLC**: prototypes owned by the mod, SA assets reused only when the DLC is present | ADR `0005` |
| D6 | Repository forge | **Public GitHub `walbydev`** (3a) | ADR `0003` |
| — | Licence | **MIT** (requester's choice, option 3a) | ADR `0003` |
| D7 | Money format | **Integer credits only** — no cents, no fractional credit anywhere, explicit rounding | ADR `0006` |
| D8 | Credit-item value | **Fixed face value**, forever, set in the price table | ADR `0006` |
| D9 | Conversion cost | **Fixed fee + amount-dependent (degressive) rate** | ADR `0006` |
| D10 | Rate improvements | **Two technologies** improve rate and fixed fee — *proposal to validate*: researched normally rather than bought with credits (Q16) | ADR `0006` |
| D11 | Bank | **Deposit, withdraw, regular interest**; interest funded by the hub's own margin — the exact funding rule is an **open prerequisite (Q15)** | ADR `0007` |
| D12 | Players | **Solo and multiplayer**; gifting exists **only via credit-items**, never a direct credit transfer | §2 |
| D13 | Game horizon | **2 h speedrun to 100 h long game** — the economy scales by **progression tier**, not by wall-clock time | §2 |
| D14 | Passive player | **No income without activity**: interest pauses when the player neither moves nor builds — *signal to settle*: production, not movement (Q19) | ADR `0008` |
| D15 | Bounties | **Nests, worms and science packs pay escalating bonuses**; escalation anchored on tier, not evolution factor | ADR `0009` |
| D16 | Money source | **One treasury funds every credit payout** — contracts, bounties, interest (proposal, Q20) | ADR `0009` |
| D17 | Contract mix | **Most contracts on technologies the player already has**; a minority are "motivation" contracts requiring the next tier, so the player must research or buy forward | block 3 |

### 1.2 Success indicators (observable) — **accepted by Philippe on 2026-10-25**

| # | Indicator | Measurement | Status |
|---|---|---|---|
| I1 | The hub does not replace production | On a reference save, buying a material from the hub costs **strictly more** than producing it locally (ratio ≥ 1.5), measured on 10 reference items | accepted |
| I2 | Contracts remain a choice | At any time the player can honour at least **2 contracts out of 4** from current stock, and **at most 3 out of 4** without producing — so production is required to keep the pace | accepted |
| I3 | The hub is used, not ignored | Philippe opens it at least **once per play session** across 5 consecutive test sessions | accepted |
| I4 | The hub is understandable without documentation | First contract delivered **without reading external docs**, using only tooltips and the GUI | accepted |
| I5 | No technical regression | No Lua error on load, 0 errors across headless scenarios, a save from version N reloadable in N+1 | accepted |

I1 and I2 carry the "balanced" requirement on their own: they will decide success, and they must be
turned into concrete numbers in block 3 and tested in block 9. **The I1 threshold (ratio ≥ 1.5) was
confirmed by Philippe on 2026-10-25** along with the whole set.

### 1.3 Non-goals (what this project will never do)

- No new planet, no new surface, no rework of base recipes.
- No competitive multiplayer economy: no PvP, no player market, no leaderboard.
- No configuration where the mod requires the DLC: it plays identically with and without Space Age
  (ADR 0005), and **both configurations are tested**. "Works in my setup" is not a claim.
- No final artwork in v0.1: placeholders accepted, art pass later.
- No replacement of research: no technology on the critical path can be bought at the hub.
  **Direct consequence of 2a**: the curated list is the guardrail, not an intention.
- No second hub per surface, no multi-force, in the MVP (D4, to confirm in block 3).
- ~~No credit-item in the MVP~~ — **reversed 2026-10-25** (ADR 0004): the item is in the MVP, as a
  bearer asset convertible both ways at the hub. What stays forbidden is **minting credits outside
  the hub** — no recipe, no chest trick, no script, no third path.

---

## 2. Users and usage

### 2.1 Who actually uses it

| Population | Reality | Consequence |
|---|---|---|
| **Philippe, solo** | the primary user: the mod is built for his games first | every acceptance criterion is measured on his saves (I1–I5) |
| **Other players, multiplayer** | each player has their **own** ledger and bank; credits are per player, not shared | a conversion and a deposit must be deterministic and re-entrant (same tick, two players) |
| **Anonymous portal users** | install the mod from `mods.factorio.com`, never contact us | I4 (understandable without documentation) is a hard requirement, not a nicety |
| **A player without the mod** | **cannot receive credits**: the credit-item has no meaning in a save where the mod is absent | gifting is only meaningful between equipped players — stated in the mod description |

### 2.2 The usage gestures (what the mod must make possible)

Open the hub · read a contract and its requirements · deliver · be paid in credits and/or a
technology · buy materials or a curated technology · **convert credits into credit-items** ·
**convert credit-items into credits** · **deposit into the bank** · **withdraw** · **hand items to
another player** (chest, ground, direct insertion). Nothing else.

Every one of these gestures must be reachable from the hub GUI (or the item itself for the item
form) without reading a wiki.

### 2.3 Time horizon: 2 hours to 100 hours

The requester plays anything from a **2-hour run** to a **100-hour long game**. A single static
catalogue cannot serve both: at 2 hours the player has barely launched a rocket, at 100 hours
everything is unlocked.

**Design consequence, settled here:** the economy scales by **progression tier**, never by
wall-clock time. Contracts and purchasable goods are gated on what the player has already
accomplished (technologies researched, science packs produced), so the same table serves a short and
a long game. A timer-based economy would make the 2-hour run see one contract and the 100-hour run
see everything too early.

### 2.4 What usage is *not*

No API, no external consumer, no other mod is required to consume anything. Nothing is scheduled: a
contract expires or it does not, but **nothing runs while the game is closed**. There is no
"it worked overnight" metric — the only clock is game time.

### 2.5 What this implies for the following blocks

- Block 3 (scope): the tier model is part of the MVP, otherwise I1/I2 cannot hold across 2 h and 100 h.
- Block 5 (data): per-player ledger and bank in `storage`, plus the hub's margin account.
- Block 6 (UI): the fee must be visible **before** confirming a conversion, and the tier of a
  contract must be readable at a glance.
- Block 9 (quality): multiplayer determinism tests, and two run lengths (short and long) as test
  scenarios.

## 3. Scope

`[TO FILL — block 3]` MVP / wave 2 / out of scope. D2 (delivery by insertion or by rocket), D4
(number of hubs) and D5 (Space Age) are settled here with acceptance criteria.

## 4. Technical constraints and reuse

`[TO FILL — block 4]` See §0.2 for the verified test chain. Already certain:

- Language: **Lua 5.2** (Factorio API), no .NET, no PostgreSQL — the preferred stack does not apply.
- Persistent state: `storage` (not `global`, since 2.0 — a trap confirmed by the game).
- In 2.1, `recipe.categories` replaces `recipe.category` (a trap confirmed by the game).
- Reuse: **base assets by default** — `rocket-silo` exists in base 2.1 and can serve as a visual
  anchor. `cargo-landing-pad` and `cargo-pod` are **Space Age prototypes**: usable only in the DLC
  configuration (ADR 0005). The hub's own prototypes carry the behaviour in both cases. No existing
  prototype may be overwritten.

## 5. Data

`[TO FILL — block 5]` Contract = `storage` schema + save version number + migrations.
D1 constraint: the credit ledger must accept a future funding source (a physical item) without
changing the contract schema.

## 6. UI/UX

`[TO FILL — block 6]` Known constraints: Lua GUI, no full rebuild every tick.

## 7. Operations

`[TO FILL — block 7]` Reduced to three commitments, see §0.1.

## 8. Security and permissions

`[TO FILL — block 8]` Two concerns only: publishing token outside the repository, and not
overwriting third-party prototypes.

## 9. Quality

`[TO FILL — block 9]` Headless harness operational (§0.2), `luac -p` in pre-commit, deterministic
scenarios with Lua assertions.

## 10. Risks, decisions, schedule

`[TO FILL — block 10]` Main risk already identified: balancing (I1, I2).

---

## Appendix A — Open questions `[TO SETTLE]`

| ID | Question | Impact if we get it wrong | Owner | State |
|---|---|---|---|---|
| ~~Q01 (D1)~~ | ~~Virtual credits or physical item?~~ → **virtual (1a) + future item extension** | — | Philippe | **settled 2026-10-25** |
| ~~Q02 (D3)~~ | ~~Curated list or full tree?~~ → **curated list (2a)** | — | Philippe | **settled 2026-10-25** |
| ~~Q03 (D6)~~ | ~~Public GitHub or private Gitea?~~ → **public GitHub `walbydev` (3a)** | — | Philippe | **settled 2026-10-25** |
| ~~Q07~~ | ~~MIT or LGPL-3 licence?~~ → **MIT** | — | Philippe | **settled 2026-10-25** |
| ~~Q10~~ | ~~Are the 5 indicators accepted? Is the I1 ratio ≥ 1.5 right?~~ → **all accepted 2026-10-25** | — | Philippe | **settled** |
| ~~Q11~~ | ~~1b: extension point or planned wave 2?~~ → **the item is in the MVP, both conversion directions (D1-bis)** | — | Philippe | **settled, see ADR 0004** |
| ~~Q12~~ | ~~Is a conversion spread applied?~~ → **yes: fixed fee + amount-dependent rate (D9)** | — | Philippe | **settled 2026-10-25** |
| ~~Q13~~ | ~~Fixed rate or floating market rate?~~ → **fixed numeric table; the *cost* varies with the amount, the rate is not a market** | — | Philippe | **settled 2026-10-25** |
| ~~Q14~~ | ~~Multiplayer in the MVP?~~ → **solo and multiplayer, gifting only via items** | — | Philippe | **settled 2026-10-25** |
| Q15 | **What funds the interest?** Cadence in game time? What does the bank show when the margin is empty? | Without a bound, interest creates credits out of nothing and I1 (hub must not replace production) cannot hold | Philippe | block 3 |
| Q16 | Rate-improvement technologies: **researched normally** (proposal) or **bought at the hub**? | Bought: the hub funds its own discount — a self-financing loop | Philippe | block 3 |
| Q17 | Does the catalogue scale by **progression tier** (proposal) or by time/random draw? | Time-based: a 2 h run sees one contract, a 100 h run rushes everything, and neither keeps I1/I2 | Philippe | block 3 |
| Q18 | Where do the numbers come from: price table anchored on **production cost (raw + energy + time) × ≥ 1.5**, in integers? | Ad-hoc numbers: I1 is unmeasurable and the table gets rewritten three times | Philippe | block 3 |
| Q19 | **AFK signal**: literal "does not move + does not build" (spoofed by a walking loop) or **production-based** (proposal)? And how is a shared multiplayer factory attributed to a player? | Wrong signal: either twitch farming, or a planning player is punished; ADR 0008 stays blocked | Philippe | block 3 |
| Q20 | **One treasury** for every payout (contracts + bounties + interest), or separate faucets? | Separate faucets: any of them can mint credits, and I1 dies by the richest one | Philippe | block 3 |
| Q21 | Escalation of bounties anchored on **tier** (proposal) rather than **evolution factor**? | Evolution: the optimal strategy is nest farming, which is exactly what the bounty pays for | Philippe | block 3 |
| Q22 | Science-pack bounty: **per unit** (unbounded in a 100 h game) or **per milestone** — first *N* packs of each new tier then closed (proposal)? | Per unit: a large factory prints credits and the hub becomes decorative | Philippe | block 3 |
| Q04 (D2) | Delivery to the hub by **physical insertion** or **rocket launch**? | Rocket: the silo enters the MVP, tracking and testing change | Philippe | block 3 |
| Q05 (D4) | **A single hub** or several (per surface, per force)? | Several: multi-surface and multi-force from the MVP | Philippe | block 3 |
| ~~Q06 (D5)~~ | ~~Space Age optional or a hard dependency?~~ → **plays with and without the DLC (D5)** | — | Philippe | **settled 2026-10-25, ADR 0005** |
| Q08 | Late penalty or **dry expiry** of a contract? | Penalty: needs a debt or reputation mechanic, otherwise the contract is neutral | Philippe | block 3 |
| Q09 | Exact publishing procedure on `mods.factorio.com` (upload, moderation, delay) | `[to verify]` — no credible "release date" without it | cadrage (research) | block 7 |

---

## Appendix B — Sources and incoming documents

| File | Origin | What was retained |
|---|---|---|
| `docs/entrants/brief-cadrage-2026-10-25.md` | Hermes `web-coder`, 2026-10-25 (French, kept verbatim) | Original request, verified technical facts (§0.2), D1–D6, balancing leads, non-goals |
