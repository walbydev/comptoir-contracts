# Framing — Company contracts (Factorio 2.1 mod)

> Version: 0.2 · Date: 2026-10-25 · Requested by: Philippe Ryf
> Status: **block 1 closed 2026-10-25** — Phase 0 done; decisions D1, D1-bis, D3, D5, D6 and the
> success indicators I1–I5 are settled by the requester.
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

`[TO FILL — block 2]` Frame set in §0.5: one real user (Philippe, the player) plus the anonymous
portal population. Usage is described in play sessions, not requests per day.

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
| Q12 | Is a **conversion spread** applied at the hub? | Free symmetric conversion makes the item pointless as a store of value and opens a laundering loop | Philippe | block 3 |
| Q13 | Fixed rate (1 item = N credits) or a floating market rate? | Floating: needs a price feed and multiplies the balancing surface | Philippe | block 3 |
| Q14 | **Multiplayer**: must the mod be correct with several players in the MVP? Gifting implies yes — how many, LAN or internet? | Yes: determinism, desync and same-tick conversion tests enter block 9. No: the gifting requirement is moot | Philippe | block 2 |
| Q04 (D2) | Delivery to the hub by **physical insertion** or **rocket launch**? | Rocket: the silo enters the MVP, tracking and testing change | Philippe | block 3 |
| Q05 (D4) | **A single hub** or several (per surface, per force)? | Several: multi-surface and multi-force from the MVP | Philippe | block 3 |
| Q06 (D5) | Space Age **optional** or a hard dependency? | Hard: smaller audience, planets frozen into scope | Philippe | block 3 |
| Q08 | Late penalty or **dry expiry** of a contract? | Penalty: needs a debt or reputation mechanic, otherwise the contract is neutral | Philippe | block 3 |
| Q09 | Exact publishing procedure on `mods.factorio.com` (upload, moderation, delay) | `[to verify]` — no credible "release date" without it | cadrage (research) | block 7 |

---

## Appendix B — Sources and incoming documents

| File | Origin | What was retained |
|---|---|---|
| `docs/entrants/brief-cadrage-2026-10-25.md` | Hermes `web-coder`, 2026-10-25 (French, kept verbatim) | Original request, verified technical facts (§0.2), D1–D6, balancing leads, non-goals |
