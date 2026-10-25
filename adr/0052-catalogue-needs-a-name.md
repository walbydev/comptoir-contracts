# 0052 — An item enters the catalogue only if the game names it as an item

- **State**: accepted
- **Status**: accepted 2026-10-25, from a screenshot: the shop row for `pipe` read "Unknown key: item-name.pipe"
- **Date**: 2026-10-25
- **Block**: lot (b)
- **Amends**: D55 (catalogue), `0032`

## What happened

The counter listed `pipe` and the window showed `Unknown key: "item-name.pipe"`. The item exists,
the recipe exists, the icon renders — but base 2.1.23 localises `pipe` **under `[entity-name]`
only**: there is no `item-name.pipe` string to find. The generator had selected the recipe and
assumed the item would be nameable.

## Decision

**The catalogue only holds items the game names as items.** The generator checks, for every
candidate, that a name exists in the item namespace; an item localised only as an entity is
excluded, because the counter sells *goods*, and a good without a name is a broken row.

`pipe` therefore leaves the catalogue. The table goes from **16 to 15 items**, and the tier
distribution becomes 8 / 6 / 1.

## Why not patch the locale instead

Adding `[item-name] pipe=Pipe` in our mod would work — the key is additive, not an override — but
it would hide the real problem: a generator that admits items without checking they can be
displayed. The next such item would arrive with the same silence. Excluding it keeps the rule in
the tool rather than in a patch.

## Consequence for the tests

The static layer (L1) gains a check: every item of `data/prices.lua` must resolve to a name in
`en` and `fr`, through the item namespace. A row that cannot be named fails `make check`, not the
requester's eye.

## Note

The other fifteen entries render correctly in French in the same screenshot — the base locale
covers them — which is what made `pipe` visible as the single exception.
