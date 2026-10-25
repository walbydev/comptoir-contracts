# 0046 — The counter draws no power: the spaceport feeds it

- **Status**: accepted 2026-10-25 by the requester ("on abandonne la consommation pour le hub. Il est alimenté par le spatioport")
- **Date**: 2026-10-25
- **Supersedes**: `0030` on the consumption point (D49) — `0030`'s orbital-production half stays parked in `comptoir-freight`
- **Rejects**: option B of `0045`
- **Closes**: Q58

## Decision

The counter has **no electric draw**. It is a `container` (D31 / `0016` holds, unchanged), it needs no
pole, no grid, no fuel. The fiction carries it: **the spaceport powers it**, from orbit. A counter is a
concession granted by a company; a company that runs a space elevator can supply a trading post, and it
would be odd for the colony to wire it.

## What this costs, stated plainly

1. **The anchor is gone.** D49 bought a placement constraint for free: a powered counter cannot stand in
   the wilderness. What remains is **the minimum distance between two counters** and the recipe's cost.
   A player can now put a counter anywhere, before the first steam engine. That is the price of the
   decision, not a side effect to discover later.
2. **The closed state disappears.** `docs/06-interface.md` listed four window states; *unpowered* is no
   longer one of them. A22 loses its "no power" clause. Three states remain: a cooperative at zero,
   nothing to offer, and an expiry while the window is open.
3. **The working animation is lost.** Option B would have borrowed the `active` flag of an
   assembling-machine to animate the elevator car. A container has none. **The car therefore still needs
   a carrier** (§ below) — the decision does not remove that work, it moves it to lot (b) as a purely
   visual spike.

## What replaces the anchor (and why it is acceptable)

Placement was never a goal in itself; it protected two things — that a counter is a *settlement* and not
a field object, and that two counters are far apart. The second is kept by the minimum-distance rule
(A9). The first now rests on the recipe: steel, circuits, stone brick — around 600 raw units, which is a
real investment at the moment a player would build one, even with no power.

## The elevator car, after this decision

Route A (D73) is still "a state, not a travelling sprite", but the state has to be carried by something,
because a container cannot animate. Two candidates for lot (b), to be settled by a spike:

- **A child decorative entity** placed by the script when the counter is built (a `simple-entity` with
  the car's graphics), whose look is derived from the elevator state. Cost: one prototype, one entity to
  keep aligned with its parent, and destruction to handle.
- **A rendering sprite** drawn above the counter, position derived from the state — no entity, no
  collision, nothing to clean up on destruction, but rendering objects must be re-created after a load.

Neither needs `on_tick`. Nothing here changes the decision above; it changes what lot (b) has to measure.

## Traceability

- D49 is struck; D75 records the replacement.
- ADR `0030` keeps its worth for the orbital *production* question; its consumption clause is void.
- A22 amended, `docs/06-interface.md` §4 amended, `docs/08-security-and-rights.md` unaffected,
  `docs/10-risks-and-plan.md` risk R1 rewritten (no longer about a machine GUI).
