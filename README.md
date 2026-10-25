# comptoir-contracts

A Factorio 2.1 mod — **company contracts** through a commercial hub (space elevator plus a spaceport).
A company posts contracts, the players' cooperative fills them and is paid in credits; credits buy
stacks of materials at the counter.

> Guiding rule: **the hub complements local production, it never replaces it.**

## v1 (ADR 0025)

**One mod.** One hub = one company carrying its own inventory. **One contract kind**: one-off with a
deadline, one to three active, **escrowed on acceptance**. **One shop.** **One cooperative account for
all players plus one account per company** — no physical currency, no player wallet. Three tiers.
Minimum distance between hubs.

Everything else is **parked as evolution**, written in `adr/` and out of v1: the bank and its interest,
bounties, the printing right, recurring and decaying contracts, debt and resale, dedicated hub sites,
buying technologies, credit transfers, and the four-mod set.

State: **blocks 1–5 closed** (2026-10-25) — 63 decisions (4 withdrawn), 37 ADRs,
22 acceptance criteria, **no question left blocking v1**, 15 parked with their features. The
repository holds the project definition, not code yet. No development before tag `v0.1-cadrage`.

| Document | Purpose |
|---|---|
| [`docs/00-cadrage.md`](docs/00-cadrage.md) | master document: ten blocks, environment, vision, scope |
| [`docs/05-price-table.md`](docs/05-price-table.md) | the price table, computed from the game's own recipes |
| [`docs/06-interface.md`](docs/06-interface.md) | the window: two tabs, one header, every field specified |
| [`tools/cost_table.py`](tools/cost_table.py) | the instrument that computes it (`make prices`) |
| [`adr/`](adr/) | architecture decisions, numbered, never rewritten |
| [`docs/entrants/`](docs/entrants/) | frozen handoff brief (input material, original language) |
| [`spike/`](spike/) | throwaway prototypes, dated |

## The family

| Mod | State | Role |
|---|---|---|
| **`comptoir-contracts`** | **v1** | the hub, the contracts, the cooperative, the counter |
| `comptoir-freight` | evolution | goods going up the elevator, orbital power (ADR 0030, 0031) |
| `comptoir-bank` | evolution | interest, deposits, activity-gated income (ADR 0007, 0008) |
| `comptoir-bounties` | evolution | nests, worms, science milestones (ADR 0009) |
| `comptoir-mint` | evolution | the printing right (ADR 0012) |

The family is a **name**, not a dependency graph: v1 is one mod and knows nothing of the others. When
an add-on returns, it depends on the core and the arrow never points back (ADR 0013, amended by
0025 and 0029).

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
| Solvency | **one cooperative account for all players**, one account per company, one federation; no player wallet | ADR 0026 |
| Contracts | escrowed on acceptance: expired means the reserved amount goes to the company | ADR 0027 |
| Prices | **one** price table for the whole set | §1.1 D30 |
| Delivery | **the hub is its own warehouse** — one inventory, no second building, **1–3 active contracts** | ADR 0016 |
| Contract kinds | three kinds: **one-off**, **recurring at a fixed price**, **recurring at a decaying price** — *v1 keeps the one-off only* | ADR 0019, 0020 |
| Companies | a company has a **character**: what it wants + how it pays, one kind of contract at a time, stated in one line | ADR 0022 |
| Printing | **parked** — the research raises the credit line one step up the dial | ADR 0017 (parked) |
| Failure | **parked** — a company in default loses its contracts and is resold | ADR 0018 (parked) |

**Nothing blocks v1 any more.** The last two — how much the escrow reserves, and whether a contract can
be accepted without covering it — are closed by ADR 0028: a percentage of the payout, and coverage
required, with the shop's buying side as the way back from zero.

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
