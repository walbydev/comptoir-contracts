# 0025 — v1 scope: one mod, one hub, one contract kind, one shop

- **State**: accepted
  autres idées pour évolution ») — the boundary below is submitted item by item for approval
- **Date**: 2026-10-25
- **Block**: 3
- **Defers**: `0007`, `0008`, `0009` (bounties), `0011`, `0012`, `0013` (multi-mod), `0017`, `0018`,
  `0019`, `0020`, `0021` — all of them stay written, none of them is in v1

## Context

The framing has produced 40 decisions in one day. That is not a sign of progress; it is a sign that the
project grew while it was being described. The requester's instruction is therefore taken literally:
**cut v1, keep the rest as evolution.**

The test applied to every line: *can the loop be played end to end, measured, and shipped without it?*
If yes, it leaves v1.

## What v1 is

A player builds a hub, finds a company inside it, takes a contract, fills the hub with what the
contract asks, dispatches it, is paid on the company's balance, and spends that balance in the same
hub's shop. Repeat. Everything else is later.

| # | In v1 | Trace |
|---|---|---|
| 1 | **One hub entity = one company**, carrying its own inventory, fed by inserter or robot | D31, D32, `0016` |
| 2 | Hubs spaced by a **minimum distance**, any surface | D25, `0014` |
| 3 | **Non-nominative contracts**, company purse, any player may feed and dispatch | D40, `0024` |
| 4 | **One contract kind only: one-off with a deadline**, one to three active per company | `0019` reduced to its first row |
| 5 | **One shop**: it buys your goods, it sells materials at `cost × 1.5`, one price table | D30, `0006` |
| 6 | **Company balances + one federation balance**, integers, **no item, no conversion** | D39, `0023` |
| 7 | The federation starts with an **endowment** — one number per company, in the data file (the three presets of D29 become three numbers) | `0015` reduced |
| 8 | **Three tiers**, sized by progression, which set contract quantities and payouts | D13, D15 |
| 9 | Solo and multiplayer, with and without Space Age, on Nauvis | D5, D12 |

That is **one mod**, not a set. `0013`'s packaging, naming and API questions do not exist in v1.

## What is parked, and honestly labelled as an idea

| Parked | Why it is not in v1 | ADR |
|---|---|---|
| Recurring fixed and recurring decaying contracts, logarithmic decay, per-item floor, abandon rule | a second and third shape of contract double the generator, the GUI and the balancing | `0019`, `0020` |
| Bank: deposits, withdrawal, interest, activity gate | it needs player wallets, and `0023` gives the money to the company | `0007`, `0008`, `0011` |
| Bounties: nests, worms, science packs | an entire second reward channel, plus its escalation model | `0009` |
| Printing right, dial by research, mint add-on | it needs the credit-line machinery to have something to raise | `0012`, `0017` |
| Debt, credit line, bankruptcy, resale | a whole state machine; v1 simply has no borrowing | `0018`, `0015` (part 2) |
| Buying technologies at the hub | a second shop with a research subsystem behind it | `0002` |
| **Hub sites** (dedicated zones, map generation) | the two unknowns — a guaranteed spawn site and existing saves — are not worth v1 | `0021` |
| Credit transfers between companies | nothing to transfer while the shop is the only sink | Q32 |
| The four-mod set (`-bank`, `-bounties`, `-mint`) | a set of one has no packaging problem | `0013` |

**Parked is not deleted.** Every parked ADR stays in `adr/`, accepted as a design, with a line saying
it is outside v1. The evolution path is therefore written down instead of remembered.

## What this does to the open questions

From **21 open to 6**. The six that still block v1:

| # | Question | Why it cannot wait |
|---|---|---|
| Q08 | Does an expired contract cost anything? | a deadline with no consequence is decoration |
| Q18 | Is the band `cost < payout < price (= cost × 1.5)` the rule for every number? | the price table cannot be written without it |
| Q24 | Manual dispatch contract by contract, and what happens to the goods if the hub dies? | it is the core interaction |
| Q35 | I2 rewritten for three contracts | I2 is an accepted indicator |
| Q36 | Shared stock, three contracts: first-come or reserved? | the GUI cannot say "ready" without a rule |
| Q45 | Who holds the money: the company alone (v1's assumption) or a player wallet? | `0023` + `0024` force "company alone"; a wallet would need a mechanism nobody has defined |

The other 15 are parked with their features.

## What v1 no longer promises

Two of the eight balancing levers of `0006` are gone with the conversion, four more are parked with
interest, bounties and decay. v1 balances **three** numbers: the payout band, the shop multiplier, and
the federation endowment. That is a scope a single person can test in a weekend, which is the point of
this ADR.
