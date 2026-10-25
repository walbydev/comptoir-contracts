# 0031 — A building cannot change role: the orbital power needs a second prototype

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 4
- **Extends**: `0030` (hub power, orbital production)

## The question

> « Un bâtiment ne peut donc pas passer de consommateur à producteur ? Ou pire, si débloqué, un second
> hub producteur est disponible. »

Two questions in one: is a role change possible, and is the second building the bad outcome?

## Answer, checked in the installed game data

1. **No.** An entity's `energy_source` is fixed by its prototype. Once a prototype declares `electric`
   with a `usage_priority` of consumer, the entity **consumes for its whole life**. There is no runtime
   call that turns it into a generator, and no amount of scripting changes the energy source of a live
   entity. The only way to "change" the building is to destroy it and create another one — which loses
   its inventory, its `unit_number` and therefore its company record.
2. **Base contains exactly one prototype that both consumes and produces**: `electric-energy-interface`.
   It is a **debug entity** — no logistics role, no real GUI, and its production and consumption are set
   by script, which is creative-mode territory. Basing a hub on it would be a cheat wearing a building's
   clothes.

## Conclusion: your "worse case" is the only honest case

The requester's instinct names the right answer while calling it the bad one. If power must come back
from orbit, it comes back through **a second building**, and that is *better* than a mutating hub:

| Mutating hub (impossible) | Second building (possible) |
|---|---|
| the player ships panels, then a number changes silently on a building he already owns | the player ships panels, then **builds or unlocks a receiver** next to his hub |
| the evolution is a flag | the evolution is **visible on the map** |
| no new prototype, but a fiction that contradicts the engine | one new prototype, and a fiction the engine supports |

So the evolution's real cost is now known, and it is not "a bonus":

- **one new prototype** (the receiver) plus its graphics and its item,
- **one new order type** at the hub (goods going up),
- **one technology**,
- and the failure mode of a lost shipment.

That is a second loop by any definition. It stays out of v1 (`0025`) unless the requester decides
otherwise — and if he does, this ADR records exactly what he is buying.

## What v1 keeps from this idea

Only the honest half, and it was already decided: the hub **consumes** a small amount of power (`0030`),
so it must be connected to a grid. The production half waits for the second prototype.
