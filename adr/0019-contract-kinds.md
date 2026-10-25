# 0019 — Every contract carries a kind: one-off, recurring at a fixed price, recurring at a decaying price

- **Status**: accepted 2026-10-25 — **the open parameters of this ADR are settled by `0020`** (floor,
  curve, tier anchor); the abandon rule (Q38-bis) and the catalogue reading (Q41) remain open
- **Date**: 2026-10-25
- **Block**: 3
- **Extends**: `0009` (contract generation), `0016` (three active contracts), `0006` (payout band)

## Context

> « J'aimerais que tu ajoutes un qualificatif à chaque contrat. Un contrat peut être unique. Il
> propose une chose à faire, livrer tant de matériaux pendant tel laps de temps, etc. Ou un contrat
> récurrent à prix fixe — j'en fais le même prix. Ou un troisième type de contrat, un prix régressif :
> récurrent, mais le prix régresse à chaque occurrence du contrat. »

A contract is no longer one shape with one price. It carries a **kind**, and the kind decides how the
price behaves over its lifetime.

## Decision

Every contract has a `kind` field, one of three. It is a qualifier on a single contract structure —
not three systems, not three prototypes, not three GUIs.

| Kind | Shape | Price | Lifetime | What it is for |
|---|---|---|---|---|
| `one_off` | deliver *N* of *X* before a deadline | one payout, agreed in advance | ends on delivery or deadline, whichever comes first | the opportunity: short, readable, it makes the 2-hour horizon |
| `recurring_fixed` | deliver *N* of *X* every *T* | **identical at every occurrence** | until cancelled by the player or the company | a salary: the player can plan, and the company gains a stable supplier |
| `recurring_decaying` | same shape as above | **decreases at each occurrence** | until it reaches its floor (`Q38`) | the pressure: the reward for standing still shrinks, so the player must climb a tier |

## Why the third kind is the useful one

`recurring_fixed` and `recurring_decaying` are the same contract with opposite signs, and the pair is
what makes the tier progression **necessary** instead of optional.

- A `recurring_fixed` contract alone lets a player park on tier 2 forever: the income is stable, the
  work is known, and nothing pushes him to build the next production line.
- A `recurring_decaying` contract alone punishes the player for an economy that works, which is
  perverse: he is doing exactly what the mod asks, and is paid less for it.
- Together they say something true: **a customer who has bought iron plates from you a hundred times
  does not keep paying the first price.** The player who wants a stable income keeps the fixed
  contract; the player who wants to grow takes the decaying one and moves on before it bottoms out.
  And that is I1's spirit — the hub complements production, it never replaces it — expressed as a
  price curve rather than as a rule.

## Naming, because the same word would confuse the code

`0006` already uses **degressive** for the credit-conversion fee. Two different curves must not share
a name in the code or in the GUI:

| Word | What it is | Where |
|---|---|---|
| `conversion_rate` (degressive) | the fee rate falls as the converted amount grows | D9, ADR `0006` |
| `payout_decay` | the contract's payout falls at each occurrence | this ADR |

## Why a qualifier rather than three contract types

One structure, one generator, one GUI, one acceptance test per kind. Three parallel systems would
triple the surface of `A6` (a generated contract is always completable) and force three price tables,
which D30 forbids.

## Required companion rules — and they are all that is missing

1. **Floor (Q38)**: the decaying payout must stop somewhere. Below the local production cost it stops
   being a contract and becomes a trap; above it, it is a gentle nudge. The floor decides which.
2. **Abandon rule (Q38)**: a recurring contract is a commitment. If it can be dropped for free, the
   decaying kind has no cost; if it cannot, the player is imprisoned by a contract signed at tier 2
   and still open at tier 4.
3. **Slot occupancy (Q39)**: a recurring contract holds one of the three active slots (D32) for its
   whole life, so three recurring contracts leave no room for an opportunity.
4. **Decay shape (Q40)**: fixed percentage per occurrence, a fixed step in credits, or a curve tied
   to the tier? And the generator's mix of the three kinds — the same proportions everywhere, or a
   company identity (`0014`) skewed towards one kind?

## Acceptance

A12 — the catalogue always contains the three kinds; a `recurring_decaying` contract's payout is
strictly lower at each occurrence and stops being offered at its floor; the GUI shows the kind and,
for the decaying one, the **next** payout before acceptance.
