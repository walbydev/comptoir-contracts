# Spec 001 — v1 behaviour

- **Status**: frozen for implementation, 2026-10-25
- **Traces**: `docs/00-cadrage.md` (74 decisions) and `adr/0001…0044`
- **Scope**: one mod, `comptoir-contracts`. Everything else is parked.

## 1. Actors

| Actor | What it is |
|---|---|
| **Company** | a distant trading house that posts contracts. It owns an account. It has a *character*: what it wants and how it pays, stable within a tier |
| **Cooperative** | the players, as one shared account. Not nominative: no per-player money anywhere |
| **Counter** (`comptoir`) | the building. It carries the company's contracts and its shop, and it is the only place where credits are spent |
| **Elevator** | the physical link. It must be **down** to leave, carries the goods up, and comes back |
| **Federation** | the issuer. Its balance is the money supply; it is not a shop |

## 2. Behaviour, rule by rule

**F1 — Building.** The counter is unlocked by one early technology costing red and green science. Its
recipe contains **no oil-derived item**. Two counters closer than the minimum distance are refused, and
the second is refunded. It draws a small amount of power; without power it is closed.

**F2 — Company.** Placing a counter creates one company, bound to it for life. The company gets a name, a
character, a tier and an account. Hubs are not shared between forces: each force has its own companies.

**F3 — Contracts.** A company offers between **one and three** contracts at any time. Exactly one kind
exists in v1: *an item, a quantity, a payout, a deadline*. A filled slot refills immediately, generated
from the force's **unlocked recipes**, weighted by the company's character, with a quantity taken from a
payout band and a deadline that includes the elevator's round trip.

**F4 — Acceptance.** Accepting holds **20 % of the payout** on the cooperative. Acceptance is refused when
the available balance does not cover it. The reserve is displayed before the click.

**F5 — Filling.** The player brings the goods into the counter's inventory, by inserter or by robot. The
mod never fills anything automatically. A contract can be dispatched once its goods are physically there.

**F6 — Dispatch.** Dispatch is manual, contract by contract. It requires the **car to be down**. The goods
leave the inventory with the car, and **only one dispatch may be in flight per counter**.

**F7 — Payment.** The cooperative is credited when the car returns: the payout, plus the release of the
reserve. A contract is never paid twice.

**F8 — Expiry.** A contract whose deadline passes is lost: the reserve moves to the company, the slot
refills immediately, and nothing else happens. No debt, no reputation, no cascade.

**F9 — Shop.** The counter sells catalogue items at **cost × 1.5** and buys them at **cost**. It always
buys, with or without an active contract: that is the way back from an empty pot. Buying then reselling
always loses credits.

**F10 — Ledger.** Three kinds of holder: the cooperative, the companies, the federation. All amounts are
integers. `sum(companies) + cooperative + federation` does not change except through the initial
endowment.

**F11 — Tiers.** A tier is **derived**, never configured: depth in the oil chain (no fluid → 1, one oil
step → 2, a chain → 3). The contract generator never asks for an item whose recipe is not unlocked.

**F12 — Isolation.** Companies, the cooperative, contracts and stock belong to a force. Nothing crosses.

**F13 — Interface.** One window, two tabs (*Contracts*, *Counter*), a permanent header showing the
company, its character line and `available · reserved`. The deadline shows digits **and** a bar. The
quantity control is a field with `1 / 10 / 100 / stack` presets that write into it. Every string exists in
English and French.

**F14 — Degraded states.** No power: the window says so and every action is disabled. Counter destroyed:
the goods in it are lost and the company with no counter disappears. Save loaded mid-flight: the elevator
resumes where it was.

**F15 — Multiplayer.** Solo and multiplayer behave identically. No player owns money. Contracts are
accepted and dispatched by anyone on the force.

## 3. What the mod owns

`storage` only, per force: accounts, companies, contracts, the counter's elevator state. No files, no
network, no player identity, no statistics.

## 4. Non-goals of v1 — frozen

Recurring and decaying contracts · the bank and interest · bounties · the printing right · debt and
resale · dedicated hub sites · buying technologies · transfers between companies · orbital power · the
physically travelling elevator car · a catalogue that includes buildings.

Each one has an ADR and a price. None of them are implemented, referenced by code, or half-built.

## 5. Acceptance

The 30 criteria of `docs/00-cadrage.md` §1.3, each with a proof and an owner in `docs/09-tests.md`.
