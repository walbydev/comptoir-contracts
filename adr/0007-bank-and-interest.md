# 0007 — A bank exists at the hub: deposits accrue interest

- **Status**: accepted in principle — **the funding rule is an open prerequisite (Q15)**
- **Date**: 2026-10-25
- **Block**: 2
- **Supersedes**: —

## Context

The requester stated on 2026-10-25 that credit-items let each player "buy, store, or bank", and that
"deposited in banks, regular interest" is added. So the hub holds a bank: a player deposits credits
and they grow over time.

This is the first mechanic in the design that **creates money**. Every other path is a transfer:
contracts move value from the hub's margin to the player, purchases move it back, conversion moves it
between two forms. Interest creates credits from nothing, and in Factorio **waiting costs nothing** —
a player can build nothing, park credits and come back richer. That directly threatens I1 (the hub
must not replace production) and makes "do nothing" a strategy.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — **Vault, no interest, in the MVP** | low: deposit/withdraw only | loses the requested feature | interest, banking as a strategy |
| B — **Interest paid out of the hub's margin** (spread + contract margin), capped | medium: a margin account to track | if the margin account is empty, no interest is paid — the bank can "run dry", which must be visible, not silent | unlimited interest |
| C — Interest created from nothing, capped percentage | low | pure inflation; with a cap it becomes a fixed free-income trickle the player will optimise around | nothing, but it breaks I1 |
| D — Interest indexed on delivered contract volume (a loyalty rebate, not a yield) | medium | it is no longer interest, it is a rebate — but it cannot print money | passive income |

## Decision

**The bank exists: deposit, withdraw, and regular interest.** Option **B** is the intended funding
rule — interest is paid out of the margin the hub actually earned — because it is the only shape that
cannot create credits and therefore cannot break I1.

**But B is not yet specified**, so this ADR carries a prerequisite: **no interest code is written
until Q15 is settled** (what funds the interest, what is its cadence, what happens when the margin is
empty). Until then the bank is a vault. Recording the decision and its missing half together is the
honest way to avoid a mechanic that silently mints money.

## Consequences

- **Requires**: a margin account in `storage` (how many credits the hub has actually taken in), and a
  rule for the empty case. A bank that pays nothing must **say so** — the source-is-not-a-metric rule:
  a failure must never be displayed as a healthy zero.
- **Requires**: interest cadence expressed in **game time**, not real time, and computed on load so a
  player who leaves the game for a week is not paid for the week (otherwise: leave the game running,
  come back rich).
- **Requires**: a per-deposit cap, decided in block 3, so the optimum strategy is not "deposit
  everything and stop playing".
- **Forbids**: interest on credit-**items** (only virtual credits can be deposited; the item is the
  transport and gift form, not a yield instrument).
- **Makes harder**: I1 and I2 measurement — a yield changes the value of every other price.

## Review

Reopen if: (a) Q15 cannot be settled without breaking I1, in which case the bank ships as a vault and
interest moves to wave 2, (b) play tests show the bank is used as a waiting strategy, (c) the margin
account proves impossible to keep meaningful (it always overflows, so interest becomes option C by
accident).
