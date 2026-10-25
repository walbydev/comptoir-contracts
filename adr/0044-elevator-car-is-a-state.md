# 0044 — The car is a state, not a sprite that travels

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 10
- **Completes**: `0043`

## Decision

**Route A** for v1: the car is a **state**, and each state selects one of three graphics. No per-tick
handler, no `rendering` API, no position to reconcile after a save.

## Why A, and not the better-looking thing

| Argument | Route A | Route B |
|---|---|---|
| per-tick cost | **none** | an `on_tick` alive during every animation |
| new API surface | none | `rendering.draw_sprite`, z-order, save/load reconciliation mid-flight |
| failure mode | reads as a teleport | a sprite stuck at the wrong height after a reload |
| knowns | `entity.active` / graphics variation are old, boring, documented | unmeasured on 2.1.23 |

The last line decides it. This project has already been bitten once in one afternoon by an API that was
assumed and not measured (`game.write_file`, ADR `0043`'s sibling finding in `spike/fedora-smoke/`).
Route A ships without a spike; route B ships after one, and the spike is **not** on the critical path.

## What route A owes the player

A state change must still **read** as travel, so the three states are not interchangeable:

- **down** — the car sits at the bottom of the shaft, visible, with a warm idle light. This is the only
  state where the send button exists.
- **rising / away** — the car is gone and the shaft reads as *empty*, while the header says `▲ away · 1:12`.
  Emptiness is the information: nothing to send, nothing to collect.
- **returning** — the car is visible at the top, descending, and the header counts down. The payout lands
  when it reaches the bottom, so the last seconds are tense on purpose.

The difference between A and B is smoothness, not information. **Every fact B would show, A shows.**

## Route B is parked, with its price written down

`0043` §5 already prices it: one spike (z-order, save/load mid-flight, animation lifetime), then a
bounded `on_tick` that unregisters itself. It returns as an evolution — in `comptoir-freight`, which is
already the name reserved for the elevator's second life (`0029`), and where orbital power would live
(`0030`). Two visual features, one add-on, one spike.
