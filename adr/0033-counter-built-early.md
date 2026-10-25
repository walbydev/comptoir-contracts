# 0033 — The counter is built early, before oil

- **Status**: accepted 2026-10-25 by the requester ("bien avant le pétrole")
- **Date**: 2026-10-25
- **Block**: 5
- **Refines**: `0025` (v1 scope, "three tiers"), `0033` replaces the idea of a tier as a gate

## Context

> « J'aimerais que le hub de base puisse être construit assez rapidement. Bien avant le pétrole. »

This is a placement in the progression, and it has consequences far beyond the recipe.

## Decision

1. **The counter's recipe contains no oil-derived item.** Not "few": none. Plastic, advanced
   circuits, batteries and lubricant are forbidden in it, because any of them would silently move the
   building behind the oil wall it is supposed to precede.
2. **A dedicated technology, red and green science only**, positioned after steel and electronics. It
   unlocks the building, not the economy — the economy is unlocked by the building.
3. **Measured cost target**: about **600 raw units**, roughly 50 steel plates + 100 electronic
   circuits + 50 stone bricks + some pipe. That is a real investment at the red/green stage — not a
   starter chest — and it is reachable without oil.
4. **Tier 1 contracts ask only pre-oil items**, so the loop closes before the refinery exists: 9 of
   the 16 catalogue items have no fluid anywhere in their recipe tree (see `docs/05-price-table.md`).

## Why this is the right place in the progression, not just a preference

| Without an early counter | With it |
|---|---|
| the first hour is pure vanilla; the mod is invisible until oil | the mod is present from the moment the base exists |
| credits can only buy oil-era goods, so they never help the early game | credits buy **steel, circuits and plates**, which is exactly what a player about to build a refinery needs |
| the counter is a late-game convenience | the counter is part of how the base is built |

The second line is the real argument: selling materials before oil is useful **only** if you can earn
before oil. The two halves have to arrive together or neither works.

## Testable consequences

- **A16**: no ingredient of the counter's recipe has oil anywhere in its tree — checked against the
  same measurement that produces the price table, not against a hand-written list.
- **A17**: with a tier-1 catalogue only, every item offered can be produced with red/green research
  and no fluid.
- The counter's recipe is priced like any other item by `tools/cost_table.py`: if it drifts out of the
  band, the tool says so.
