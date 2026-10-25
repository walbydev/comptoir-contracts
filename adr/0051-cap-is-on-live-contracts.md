# 0051 — The cap of three is on live contracts, not on offers

- **State**: accepted
- **Status**: accepted 2026-10-25, after the window code showed the rule was not enforced
- **Date**: 2026-10-25
- **Block**: lot (b)
- **Amends**: `0016` / D32 (same number, made structural)

## What happened

D32 says a company runs **one to three contracts, never more**. The shipped code enforces
`offer_slots = 3` against `count_offers` only: accepting a contract turns an offer into an accepted
one, which frees a slot, which the generator refills. A player can therefore accept ten contracts in
a row — each one holding a reserve — with three offers permanently on screen. The window then had to
hide rows to stay readable, and a hidden accepted contract cannot be dispatched. The UI capped the
list at three rows plus one empty slot, which is a workaround for a rule that was never enforced.

## Decision

**The cap counts live contracts**: `offered + accepted + in_flight ≤ 3`. The generator fills
`3 − live` slots, so a company never has more than three contracts of any state, and the window
never needs to hide one.

Consequences:

- accepting does not free a slot, so no immediate refill;
- completing or expiring frees one, and the refill is immediate (D59);
- the maximum escrow exposure is `3 × 20 %` of a contract, which is what the "bounded damage"
  argument of ADR `0040` always assumed — with six contracts it was twice that;
- the window lists at most three rows, so the "3 + 1 empty slot" display rule becomes redundant.

## What it costs

A player who wants a choice must first dispatch or finish what he holds. That is the intended
pressure: three slots are a scheduling budget, and a fourth contract would have made the elevator
cycle irrelevant — the whole point of `0043` is that you cannot do everything at once.

## Test

A31: with three live contracts, a fourth acceptance is refused with a reason, and the generator
creates no new offer while live equals three.
