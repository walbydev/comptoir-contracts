# 0004 — Credit items exist in the MVP, convertible both ways at the hub

- **Status**: accepted
- **Date**: 2026-10-25
- **Block**: 1
- **Supersedes**: `0001`

## Context

ADR 0001 settled on a purely virtual currency with a *future* extension point towards an item.
Philippe then stated the actual requirement on 2026-10-25:

> credits in item form must be handable to another player or storable in a chest, so conversion from
> credit-item to virtual credits, and the reverse.

That is not an extension point any more: **the item is in scope for the MVP**. ADR 0001 is therefore
superseded, not edited — it stays as the record of why a single-currency ledger was the first
intuition, and of the exact risk that made it attractive.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — Virtual only, item later (ADR 0001) | lowest | fails the requirement: credits cannot leave the save's ledger, no gifting, no chest | gifting, physical saving, trade |
| B — **Both, converted only at the hub** | medium: one conversion entity, two functions, one price table, extra tests | duplication by belt/splitter games, and a laundering loop if conversion is free and symmetric | nothing from the requirement |
| C — Both, converted by an assembling-machine recipe | low to build, high to balance | the item becomes craftable anywhere → credits can be minted with a recipe, the hub stops controlling the supply | the hub's control over the currency |
| D — Item only (no ledger) | medium | logistics become the whole game (see 0001), and a save with 2000 loose credit items is unmanageable | counting without hauling |

## Decision

**Option B.** The credit-item exists, and conversion happens **only at the hub**, in both directions,
through a dedicated entity. No assembling-machine recipe ever produces or consumes a credit item:
the recipe path is option C and it destroys the hub's control over supply.

The item is a **bearer asset**: whoever holds it owns it. That is the property that makes gifting and
chest storage work, and it is exactly the property option A could not provide.

## Consequences

- **Requires**: a single conversion rate table in one data file, with a **conversion spread** —
  converting out and back must not be free, otherwise the loop is a no-op and the item is pointless
  as a store of value (Q12, Q13 in the framing).
- **Requires**: the conversion entity refuses partial operations cleanly (no credits destroyed, no
  items voided) — a Lua state machine with assertions, not a heuristic.
- **Requires**: multiplayer correctness from the MVP, since gifting only exists in multiplayer
  (Q14). A conversion triggered by two players in the same tick must be deterministic.
- **Requires**: `storage` schema version 1 to already hold both the ledger and the item statistics,
  so no migration is needed when the spread is tuned.
- **Forbids**: any recipe, chest interaction or script that mints credits outside the hub.
- **Makes harder**: the balancing of I1/I2 (a store of value competes with hoarding materials), and
  the duplication review — every new path that touches a credit item must be tested against
  splitter/inserter duplication.

## Review

Reopen if: (a) duplication is proven reachable despite the hub-only rule, (b) the conversion spread
turns out to make one direction useless (players never convert back), (c) a third-party mod
introduces a compatible item currency, in which case interoperability replaces this design.
