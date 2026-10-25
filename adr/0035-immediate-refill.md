# 0035 — A freed slot refills immediately; there is no refresh timer

- **Status**: accepted 2026-10-25 — closes the last open point of `0034`
- **Date**: 2026-10-25
- **Block**: 5

## Decision

When a contract is completed or expires, **its slot is refilled at once**, with a new contract
generated on the spot. The catalogue never sits empty and no timer exists.

## Why

- **No clock, no `on_tick`.** This is the fourth decision to fall out of "the mod must cost nothing
  per tick" (§4.2). A refresh timer would be the only reason to want a clock in v1.
- **The limiter is production, not patience.** The player's constraint is what he can build, and a
  timer would add a second, artificial constraint on top of it. Waiting is not gameplay.
- **A simple rule the player can learn in one glance**: finish, get a new offer. Nothing to track,
  nothing to miss.

## The risk, and why it is not a problem

An always-fresh catalogue usually invites **farming**: refuse offers until a good one appears. Here it
gains nothing, because the generator targets a **payout band per slot**, not a per-item jackpot
(`0034`, §4). A slot pays roughly the same whatever it asks for — so rerolling changes the *work*, not
the *money*.

If a future evolution introduces per-item margins, this decision has to be revisited in the same
change: it is the payout band that protects it, not the refill rule.
