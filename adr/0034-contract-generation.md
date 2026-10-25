# 0034 — Contracts are generated from research, never from a dice roll alone

- **Status**: accepted 2026-10-25 — answers "comment génères-tu les contrats ?"
- **Date**: 2026-10-25
- **Block**: 5
- **Refines**: `0022` (company character), `0025` (one contract kind in v1)

## Context

> « Comment génères-tu les contrats ? Au hasard en fonction de recherches ? »

Partly. Randomness chooses *within* a pool, and the pool is decided by three things that are not
random at all: what the player can build, what the company wants, and what the price table says a
contract of that item is worth.

## The generation, in full

```
for a company C, when a slot is free:
  pool  = items in the catalogue
            where recipe unlocked by C's force        (research)
            and tier(item) <= C.tier                  (oil chain, measured)
  if pool is empty -> nothing to offer, and the counter says so
  item  = weighted pick from pool, weights from C's character
  qty   = round(target_payout / payout(item)), clamped to [30, 500]
  pay   = qty x payout(item)
  dead  = max(10 min, qty x seconds(item) / 2)
  hold  = ceil(pay x escrow_rate)
```

### 1. The pool comes from research, and it must

A contract asking for a processing unit from a player who has not researched it is not a hard
contract, it is a **stolen escrow**: the player accepts, cannot deliver, and pays for a failure that
was decided before he clicked. The filter is therefore not a nicety — it is the difference between a
game and a trap.

**A18** asserts it: no generated contract ever contains an item whose recipe is not unlocked.

### 2. The tiers are a consequence, not a gate

The first attempt defined tiers by science packs ("the highest pack that unlocks the recipe"). It
lies, and the data proves it: in base 2.1.23 `advanced-circuit` is unlocked by a technology costing
**only red and green science**, while the item needs **plastic**, therefore oil. A tier copied from
the tech tree would offer advanced circuits to a player with no refinery.

So the tier is read from the **oil chain depth** of the item instead: no fluid → tier 1, one oil step →
tier 2, a chain of oil steps → tier 3. Nine catalogue items are tier 1, six are tier 2, one is tier 3.

This means the "three tiers" of `0025` survive as a **commercial band** — what a company is willing to
ask, and how much it pays — not as a padlock. The padlock is research, which the game already tracks.

### 3. Character decides the weighting, not the pool

`0022` gave each company a character: what it wants and how it pays. In the generator that is a
**weight vector** over item groups, fixed per company and stable within a tier (at most one change per
tier). It never removes an item from a pool, it only makes some more likely — so a player is never
locked out of a company because of its taste.

### 4. Quantity and deadline are derived from the measured table

- **Quantity** targets a payout band, so a contract on cheap cable asks for hundreds and a contract on
  a processing unit asks for a handful. The player sees comparable money for comparable work, whatever
  the item.
- **Deadline** assumes the player dedicates **two machines** to the contract:
  `deadline = max(10 min, quantity × machine_seconds / 2)`. Both inputs come from
  `tools/cost_table.py`, so when the game changes its recipes the deadlines follow.

### 5. Randomness is seeded per company, never `math.random`

Multiplayer desyncs when two clients draw from different random streams, and a save reload must
reproduce the contracts the player already sees. Each company therefore owns a generator in `storage`,
seeded once at creation, advanced only when a contract is generated. Same save, same seed, same
contracts — always.

## Still open

- **The cadence**: does an empty slot refill the moment a contract is completed or expired, or does
  the catalogue refresh on a timer? Immediate is simpler (no clock, no `on_tick`) but removes the
  pleasure of "waiting for a good contract".
- Whether the player can **refuse** a contract without cost (he can: not accepting is free; only
  accepting and failing costs the reserve).
