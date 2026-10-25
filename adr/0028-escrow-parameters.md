# 0028 — The escrow is a percentage of the payout, and the pot must cover it

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 3
- **Completes**: `0027` (contract escrow)

## Context

Two parameters were left open by `0027`. Two answers:

> « 1 pourcentage. 2. Non. »

## Decision

### 1. The reserved amount is a percentage of the payout

`reserved = ceil(payout × rate)`, where `rate` is **one number in the price table** — not per item,
not per company, not per tier. One rate for the whole set keeps the comparison between two offers
honest: a big payout is always a bigger commitment, and the player never has to compute per-item
exceptions.

Two details fixed here rather than later:

- **Integer, rounded up.** The reservation is never *less* than the announced percentage: the company's
  protection is not eroded by rounding, and the displayed number is one the player can verify.
- The rate itself is **a balancing number**, set in block 5 with the payout band (D46). Recording the
  mechanism without inventing the figure is the point: the code reads it from the table.

### 2. Coverage is required

A contract **cannot be accepted** if `cooperative balance − already reserved < reserved amount`. The
acceptance button says why, in one line, rather than failing silently.

This is the hard state, and it is chosen deliberately: a cooperative that has spent everything cannot
commit to anything. It is honest, it is readable, and it makes the pot a real constraint instead of a
number that goes up.

## The consequence that had to be checked: the deadlock

With coverage required, a cooperative at zero cannot accept any contract — and accepting contracts is
how it earns. Is the game stuck?

**No, because the shop buys.** The escape route is `shop → sell goods → pot refills → a contract
becomes acceptable`. And the escape route only exists because the shop **buys** as well as sells.

That is therefore not a detail of the shop's design, it is the **safety valve of the whole economy**:

- if the shop only sold, a broke cooperative would be locked out forever;
- if the shop bought nothing from the player, `0025`'s loop would have no way back from zero;
- the shop must therefore buy **always**, including with no contract active, and at a price that
  respects the band (`cost < payout < shop price`).

Recorded as **D48** and asserted as **A14**: from a cooperative at zero, selling goods to a hub restores
the ability to accept a contract.

## What this closes

Q46 (how much) and Q47 (coverage) — the last two questions blocking v1. Block 3 is closed with them.
