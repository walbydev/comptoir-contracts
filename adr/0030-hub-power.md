# 0030 — The hub draws little power, and one day it could produce it

- **State**: parked
- **Superseded in part**: 0046 (the consumption clause; the orbital-production half is parked with `comptoir-freight`)
- **Status**: accepted 2026-10-25 for the consumption; **the orbital production is submitted as a
  v1-or-evolution question (Q48)**
- **Date**: 2026-10-25
- **Block**: 4
- **Extends**: `0016` (the hub is the building), `0014` (hub = company)

## Context

> « Oui, conso faible. Mais peut devenir producteur depuis l'espace si on envoie des panneaux solaires.
> Évolution techno. Palier 1. »

Two things in one answer: a small **electric draw**, and an **evolution** in which the hub becomes a
power *producer* because the player shipped solar panels into orbit.

## Decision 1 — the hub consumes a small amount of electricity

- It has an `electric` energy source with a **low** draw: enough to require a pole and a connection,
  small enough never to be a build-order problem.
- **Why**, and it is not cosmetic: a powered hub **must be connected to a grid**, so it cannot be
  dropped in untouched wilderness. That single property does the work of a placement rule, and it
  survives the fact that hub sites are parked (`0021`).
- It also gives the hub a visible state — no power means a closed counter — which costs nothing to
  display and reads instantly.

## Decision 2 — orbital production, as an evolution

The idea: **send solar panels up the elevator, and later receive power back down.** It is attractive
because it gives the space elevator a second job (until now it only carries contracted goods), and
because it turns the hub from a shop into infrastructure.

But it is not a flavour line, and this is where the ADR becomes a warning:

| It looks like | What it actually adds |
|---|---|
| "a bonus once you ship some panels" | a **second flow direction** — goods going up, not down |
| "a single order" | a second order type, a second failure mode (a lost shipment), a second tab or a second section in the contract list |
| "an evolution" | a technology that changes the energy balance of the whole base, and therefore interacts with every power mod |

v1 was cut to **one loop** (`0025`): contract → fill → dispatch → paid → shop. A shipment order is a
second loop. That does not make it wrong — it makes it **not v1**.

**Recommendation: park it with the rest of the evolution.** If the requester wants it in v1 anyway, the
cheapest honest form is one order that consumes a fixed count of a single item (solar panels) and grants
a permanent power output to that hub — no GUI tab of its own, one line in the shop panel. That is
defensible; anything larger is the second loop coming back.

## The one precision this answer did not give

> « Palier 1 »

Read literally, it says the *power evolution* belongs to tier 1 — which would make an orbital plant
available before the player has blue science. That is possible (it is only a number) but it is worth
confirming, because it changes what a tier-1 save looks like.

Also unanswered, and it belongs to block 5 rather than here: **what marks the three tiers**. Those are
balancing numbers tied to the price table, and they will be fixed with it rather than by memory.
