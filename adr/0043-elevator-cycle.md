# 0043 — The elevator is a physical cycle, and only leaves from the bottom

- **Status**: accepted 2026-10-25 by the requester (Satisfactory-inspired dispatch cycle); the visual
  technique is **not yet measured** (see §5)
- **Date**: 2026-10-25
- **Block**: 10 (added mid-framing, after the summary)
- **Depends on**: `0016` (hub is the warehouse), `0034` (generation), `0036` (numbers)

## The idea, and why it is not cosmetic

Until now the space elevator was decoration: goods vanished from a container and credits appeared. The
requester asks for what Satisfactory does — **the elevator leaves, and comes back a few minutes later**,
and **it can only leave when the car is down**.

That single sentence turns the elevator into the pacing device of the whole mod:

| Before | After |
|---|---|
| a contract is dispatched instantly, any number per tick | **one dispatch at a time per hub**, and the hub is blind for the duration of the round trip |
| income limited only by production | income limited by production **and** by the cycle |
| "which contract do I fill first" was cosmetic | it becomes the **only** scheduling decision of the loop |

That last line is the real gain. With three active contracts and one elevator, filling the wrong one
first costs a full cycle — the player finally has a decision that is not arithmetic.

## The state machine

```
down ──send──> rising (animation, ~8 s) ──> up (away, travel time)
  ^                                              │
  └── descending (~8 s) <── returning <──────────┘
```

- **Only `down` accepts a send.** The button is disabled in every other state (A22 already covers it).
- A send requires: a **filled** contract, the goods **in the hub's inventory**, and the car **down**. The
  goods leave with the car, so a destroyed hub loses them (D44, unchanged).
- The contract is marked `delivered` at the moment of departure, and **paid on return** — the credits are
  the company's answer, not an instant reward. It also means a save during the trip must resume it.
- Deadline: a contract whose deadline falls while the car is away **expires and forfeits its reserve**.
  Visible in the bar, decided at acceptance.

## Numbers

One cycle = **2 minutes** of real time (proposal, one number in the data file, tunable without touching
logic). Breakdown: 8 s rising, ~104 s away, 8 s descending, the rest is turnaround.

Consequence on generation (`0034`): the deadline of a contract must include the round trip, so the formula
becomes

```
deadline = max(10 min, qty × machine_seconds / 2) + cycle
```

Without that term, a contract accepted while the car is away could be impossible to honour — and an
impossible contract is a stolen reserve (A18 in spirit).

## 5. What is measured, and what is not

**Measured**: nothing yet for this feature. The state machine, the storage, the button gating and the
deadline term are plain script and carry no risk.

**Not measured — and therefore not promised**: *how the car moves*. Two routes exist, and they cost very
differently:

| Route | Cost | Risk |
|---|---|---|
| **A — state swap**: the car is part of the hub's graphics, and the state picks one of three sprites (`down`, `away`, `returning`) | no per-tick work at all; the "movement" is implied by the sprite change | the animation is not fluid; it reads as a teleport |
| **B — real movement**: the car is a separate rendered sprite (`rendering.draw_sprite`) whose y position is updated while the car travels | an `on_tick` handler **active only during the animation**, registering itself on send and unregistering on arrival — the rule "no `on_tick`" survives because it is bounded | needs a spike: `rendering` behaviour, z-order, and what happens on save/load mid-flight |

Route B is what Satisfactory does, and it is the one worth having if it costs two seconds of script on
each send. It must be **spiked before being promised** — the previous smoke test is the reason for that
discipline: an API assumed and not measured failed on its first line.

## Open

**Q57**: route A or route B for the car? A is free and reads as a state; B is the thing the requester
described, and needs a spike (about half an hour) before it enters the plan.
