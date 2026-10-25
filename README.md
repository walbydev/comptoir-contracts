# factorio-contrats

A Factorio 2.1 **mod set** — **company contracts** through a commercial hub (space elevator plus a
spaceport). Delivered contracts pay credits and/or technologies; credits buy stacks of materials or
technologies without research.

> Guiding rule: **the hub complements local production, it never replaces it.**

**State: framing in progress (blocks 1–3 consolidated, 37 decisions, 19 questions open).** This
repository holds the project definition, not code yet. No development before tag `v0.1-cadrage`.

| Document | Purpose |
|---|---|
| [`docs/00-cadrage.md`](docs/00-cadrage.md) | master document: ten blocks, environment, vision, scope |
| [`adr/`](adr/) | architecture decisions, numbered, never rewritten |
| [`docs/entrants/`](docs/entrants/) | frozen handoff brief (input material, original language) |
| [`spike/`](spike/) | throwaway prototypes, dated |

## The set

| Mod | Role | Trace |
|---|---|---|
| `company-contracts` | **core**: hub + elevator, spaceport, cargo warehouses bound 1:1 to a contract, contracts, credits and credit-item, conversion, ledger, shop, curated technologies, tiers | ADR 0010, 0004, 0006, 0002 |
| `company-contracts-bank` | add-on: interest, AFK gating on production, deposits | ADR 0007, 0008 |
| `company-contracts-bounties` | add-on: nests, worms, science milestones | ADR 0009 |
| `company-contracts-mint` | add-on: the printing right | ADR 0012 |

Add-ons add **behaviour, never prototypes**, so each one stays removable from an existing save. The
core never knows its add-ons: the dependency arrow points one way only — ADR 0013.

## Decisions already made

| Topic | Decision | Trace |
|---|---|---|
| Credits | virtual ledger **plus** a bearer credit-item (giftable, storable), converted both ways **at the hub only** | ADR 0004 (supersedes 0001) |
| Purchasable technologies | curated list, never the full tree | ADR 0002 |
| Space Age | plays identically **with and without** the DLC: own prototypes, DLC assets reused when present | ADR 0005 |
| Forge and licence | public GitHub `walbydev`, MIT | ADR 0003 |
| Money | integer credits only, fixed face value per item, conversion = fixed fee + degressive rate | ADR 0006 |
| Bank | **one bank**: players, companies, the colonial federation (which pays contracts and bounties), the bank itself | ADR 0011 |
| Players | solo and multiplayer; gifting only via items, never a direct credit transfer | framing §2 |
| Delivery | hub + elevator = interface, spaceport = counterparty, warehouses bound to one contract, fed by inserter **or** robot | ADR 0010 |
| Packaging | one core mod + optional add-ons | ADR 0013 |
| Hub | **one hub = one elevator = one spaceport = one company**, with a bank counter; **several hubs**, on any surface, spaced apart | ADR 0014 |
| Currency | the credit is the **only** value common to every company: prices differ, the unit does not | ADR 0014 |
| Issuer | **the colonial federation issues** (its negative balance is the money supply); companies operate with their own books and can go dry | ADR 0015 |
| Solvency | one startup dial sets each company's credit line: **poor** (0) / **rich** (default) / **unlimited** (sandbox) | ADR 0015 |
| Prices | **one** price table for the whole set | §1.1 D30 |
| Delivery | **the hub is its own warehouse** — one inventory, no second building, **1–3 active contracts** | ADR 0016 |
| Contracts | three kinds: **one-off**, **recurring at a fixed price**, **recurring at a decaying price** | ADR 0019 |
| Printing | the research raises the credit line **one step up the dial** | ADR 0017 |
| Failure | a company in default **loses its contracts and is resold**; the debt lands on the federation | ADR 0018 |

Still open and **not** defaulted: dispatch and goods lost when the hub dies (Q24), resale terms
(Q34), I2 rewritten for three contracts (Q35), one stock shared by three contracts (Q36), whether the
dial step can reach `unlimited` (Q37), credits moved between companies (Q32), science bounty unit
(Q22), multiplayer attribution of activity (Q19-bis), repository layout and names (Q27, Q29).

## Test chain

Target: Factorio **2.1.x**. The mod loads and runs **headless** (`factorio --version` → 2.1.23
verified), which allows deterministic tests without a graphical client. GUI rendering and balancing
feel can only be tested in game. `luac` is **not installed**: a syntax error surfaces as a headless
load failure until Lua 5.2 is built.

```bash
make help          # available commands
make check         # Lua syntax check (arrives with the first code)
```

## Language convention

Project definition, documentation, ADRs, code, identifiers, comments and commit messages are written
in **English**. Incoming documents are kept verbatim in their original language under
`docs/entrants/`. Conversation with the requester happens in French.

## Licence

MIT — see [`LICENSE`](LICENSE). No token, no personal data, no internal path in this repository: it
is public, history included.
