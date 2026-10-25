# 0001 — Credits are a virtual currency, with an extension point towards an item

- **Status**: superseded by `0004` (2026-10-25) — the credit item moved into the MVP
- **Date**: 2026-10-25
- **Block**: 1
- **Supersedes**: —

## Context

The mod's loop rests on an intermediate reward: delivered contracts pay credits, which are then
spent on stacks of materials or on technologies. Two natures were possible: a counter stored in the
save (virtual currency), or a physical "credit" item moving on belts and inserted into chests.

Philippe's decision on 2026-10-25: **virtual currency (1a), with a future complementary extension
towards a physical item (1b)**.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — **Virtual currency** (`storage`): a counter shown in the hub GUI | low: one integer, one write at the GUI | the player may "forget" they have credits if the GUI is poor | paying a merchant with an item you carry |
| B — Physical "credit" item | medium: item, icon, recipe, storage handling | duplication through splitters, partial insertion, stack-size arbitration, and contract tracking depends on a container's state | counting credits without logistics |
| C — Both in the MVP | high: two payment paths, two GUIs, two test sets | doubles the balancing bug surface | MVP simplicity |

## Decision

**Option A**, with an explicit **extension point** towards B: the credit ledger must be able to
accept a second funding source later (an item converted into credits) without changing the contract
schema or forcing a history migration.

A is chosen because a virtual currency is **the only form that does not move the balancing problem
into logistics**: with an item, part of the player's work becomes hauling money, which is not the
requested loop. The item extension stays possible because Philippe explicitly asked for it as a
complement, not a replacement.

## Consequences

- **Requires**: the balance lives in `storage`, with a save version number and a migration from the
  very first published version — not afterwards.
- **Requires**: the hub GUI shows the balance and its history legibly, since nothing physical
  materialises the player's wealth any more (indicator I4).
- **Forbids**: making payment depend on a container or belt state in the MVP.
- **Makes harder**: adding the item later — we will have to decide what a credit-item *means* (face
  value? conversion rate?) and test it against duplication.

## Review

Reopen if: (a) Philippe asks for the credit-item as the primary mechanic (not a complement), (b) the
lack of physical materialisation makes the hub unattractive in use (I3 fails for that precise
reason), (c) a third-party mod imposes an item currency for interoperability.
