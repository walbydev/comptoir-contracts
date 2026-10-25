# 0008 — Income is gated on activity: a passive player earns nothing

- **State**: parked
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: —

## Context

ADR 0007 recorded a bank paying regular interest. The requester immediately bounded it:

> "If the player is AFK — does not move, does not build anything — the interest on his bank account
> is paused. […] A passive player earns nothing."

The requirement is clear and it is the right instinct: it closes the "park credits and wait" hole that
threatens I1. What is not clear is **how AFK is detected**, and the naive reading ("does not move, does
not build") is not a safe signal.

## The trap: movement is a spoofable signal

- A player holding one movement key, or walking a two-tile loop, "moves" forever without doing
  anything. **Movement is not activity, it is input.**
- A player who places and removes one belt every ten minutes "builds" without producing anything.
- Conversely, a player deep in a logistics rethink can stand still for twenty minutes while their
  factory runs — and by the literal rule they would earn nothing, which is exactly backwards: their
  factory *is* the activity.

So the literal signal punishes thinking and rewards twitching. It measures the wrong thing.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — Literal: no movement + no build event | low | spoofed by a walking loop or a belt toggled every ten minutes; punishes the player who stops to plan | a robust anti-AFK claim |
| B — **Production-based: income accrues only while the player's production statistics move** | medium: a sampler, a per-player attribution rule | in multiplayer, force-wide statistics do not say *whose* factory produced | idle wealth |
| C — Hybrid: production counts, movement alone does not | medium | same attribution problem as B, plus a second signal to explain | twitch farming |
| D — No interest at all in the MVP (ADR 0007 option A) | lowest | loses the requested feature | the whole question |

## Decision

**The requirement is accepted: no income without activity.** Among the options, **B (production) is
the intended signal**, because it is the only one that matches the intent ("a passive player earns
nothing") rather than the gesture, and because it cannot be spoofed by input alone.

**B is not yet specified** — the per-player attribution in multiplayer (force statistics are shared)
and the sampling cadence must be decided before any code:

1. what exactly counts as production (raw extraction? intermediates? science packs? all of them?),
2. how a player is credited for a shared factory when several players build one,
3. how the pause is **shown** (the bank must say "paused — no activity", never a silent flat balance).

Until Q19 is settled, no interest code is written. ADR 0007 already blocks interest on its funding
rule; this ADR blocks it on its signal. Both must be closed for the feature to exist.

## Consequences

- **Requires**: a per-player activity stamp in `storage`, updated by a tick sampler, and recomputed
  consistently after a save load (a player who quits for a week must not be paid for the week).
- **Requires**: interest expressed in **game time**, and a pause that stops the accrual clock without
  destroying accrued value.
- **Forbids**: any definition of activity based on player input, camera or movement alone.
- **Forbids**: an invisible pause. A bank that shows a growing balance while paused is lying (I4).
- **Makes harder**: multiplayer. Attributing production to a player is the hard part of the feature,
  and it is not optional now that gifting exists.

## Review

Reopen if: (a) per-player attribution proves impossible without absurd bookkeeping, in which case
interest ships **solo only** and is disabled in multiplayer with a visible explanation, (b) the
sampler costs measurable UPS at scale (measure in block 9), (c) play tests show the pause is
unnoticeable, which would mean the signal is wrong.
