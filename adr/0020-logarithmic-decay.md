# 0020 — The decay is logarithmic, anchored on the tier, floored per delivered item

- **State**: parked
  are still open (Q38-bis, Q41)
- **Date**: 2026-10-25
- **Block**: 3
- **Completes**: `0019` (`payout_decay`), `0009` (tier-anchored escalation)

## Context

Three questions were asked about the `recurring_decaying` kind. Three answers:

> « 1 régression logarithmique s'arrête à un palier minimal par item livré. 2 non, 1 type de contrat à
> la fois. 3 palier. »

## Decision

### 1. The curve is logarithmic

`payout(n)` for the n-th occurrence falls **logarithmically**: a steep drop in the first occurrences,
then a long, slow tail. The shape is the point:

- **linear** decay takes as long to become painful at the start as at the end, so the player feels
  nothing for ten occurrences;
- **exponential** decay collapses: by occurrence ten the contract pays nothing and the player never
  sees the squeeze, only the wall;
- **logarithmic** squeezes early and then holds: the player *feels* the contract get worse while it
  is still worth doing, which is the only window in which leaving is a decision rather than a reflex.

### 2. It is anchored on the tier

The first payout `p0` and the decay constant are read from **the tier at which the contract was
generated** (`0009`). A contract generated at tier 3 never decays towards tier-1 prices, and when the
player reaches tier 4 the decaying offer is **regenerated at tier 4**. Climbing a tier is therefore
the way out of a decay — which is exactly what this kind was introduced to encourage.

### 3. The floor is a minimum price per delivered item

The decay stops at a **minimum price per item**, and that number lives in the price table (D30): one
value per item, not per contract, not per company. When the next payout would fall below
`min_price_per_item × quantity`, the contract **stops being offered**. The company does not keep
advertising a price it will not pay.

### 4. The number of occurrences is derived, not configured

Because the curve, the tier anchor and the floor are all data, the number of occurrences before the
contract reaches its floor **falls out of them**. There is no "max occurrences" setting to balance,
and no way for the table to contradict itself: change the floor, and the contract's life changes with
it. One fewer number in a design that already has eight.

### 5. Where the floor sits decides whether the contract ever ends

| Floor relative to local production cost | Behaviour |
|---|---|
| **above** cost | the contract stays marginally profitable forever — it can be farmed indefinitely at a thin margin, and the player is never pushed to move |
| **below** cost (recommended) | the contract **ends by itself in the player's interest**: at some occurrence, delivering costs more than the payment, and leaving is the rational act |

The second is the only one that delivers the purpose stated in `0019`. It is recorded as Q38-ter
because it is a balance decision, not an implementation detail.

## The ambiguity this ADR cannot resolve (Q41)

> « 2 non, 1 type de contrat à la fois »

Two readings, and they are not the same game:

- **A — a homogeneous catalogue**: at any moment a company offers contracts of **one single kind**.
  The kind changes when the catalogue is regenerated (all contracts consumed, expired or cancelled).
  Consequence: a company has a "mood", and A12 ("the catalogue contains the three kinds") is wrong.
- **B — one of each kind at most**: the three slots of D32 hold **at most one `one_off`, one
  `recurring_fixed`, one `recurring_decaying`**. Consequence: the three slots map exactly onto the
  three kinds, and a recurring contract *does* occupy a slot.

Both are coherent; the second is the more legible on screen (three slots, three kinds, no explanation
needed), the first gives companies an identity. This must be said before the GUI is drawn.

## Still open

- **Q38-bis**: can the player **abandon** a recurring contract — freely, with a penalty, or never?
  Without an answer, a contract signed at tier 2 is a prison at tier 4.
- **Q38-ter**: is the floor below the local cost (the contract dies by itself) or above it?
- **Q41**: reading A or reading B.
