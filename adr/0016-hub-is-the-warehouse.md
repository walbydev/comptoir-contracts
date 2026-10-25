# 0016 — The hub is its own warehouse, and a company runs at most three contracts

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: `0010` (delivery chain with cargo warehouses bound 1:1 to a contract)

## Context

> « Un contrat, 2 ou 3 contrats actifs par compagnie en même temps, pas plus. Et le hub lui-même est
> l'entrepôt avec inventaire. Ainsi ça simplifie le nombre de bâtiments. »

Two decisions in one sentence: the warehouse building disappears, and the number of simultaneous
contracts is capped at three.

## Decision

1. **No separate cargo warehouse.** The hub entity carries the inventory. Goods are placed into the
   hub — by inserter or by logistics robot, as decided in `0010` — and a contract is served **from
   that stock**.
2. **Between one and three active contracts per company**, never more. As contracts are honoured or
   expire, the generator refills up to the cap.
3. The company remains the owner of the catalogue, the treasury and the counter (`0014`); the
   inventory now hangs on the same entity, not on a second building.

## Why this is the better design

| | Cargo warehouses (`0010`) | Hub as inventory (`0016`) |
|---|---|---|
| Buildings to build | hub + elevator + spaceport + N warehouses | one hub |
| Binding a warehouse to a contract | a GUI operation the player must understand | gone |
| "Inert inventory when unbound" | an ambiguous state to explain and to test | gone |
| Number of prototypes | one more entity, one more item | one less |
| Failure mode | goods sit in a warehouse bound to a contract that no longer exists | goods sit in the hub, visible where the contracts are read |

The requester's motive is stated and it is the right one: **simplify the building count**. It removes
a state machine (inert / bound / ready / dispatching) and one prototype, and it removes the ugliest
question of the previous design — what happens to goods in an orphaned warehouse.

## What this costs, and what must be settled

- **Stock attribution (Q36)**: one inventory, up to three contracts. If two contracts both want iron
  plates, the stock is common — either it is first-come, first-served at dispatch, or a contract
  reserves its quantities. Without a rule, the GUI cannot say "this contract is ready".
- **Dispatch (Q24)**: with a shared stock and three contracts, an **automatic** dispatch has to decide
  *which* contract is served first. There is no non-arbitrary answer. This pushes the design towards
  a **manual dispatch, contract by contract** — the player chooses which customer is served, which is
  also a decision, not a chore.
- **I2 must be re-expressed (Q35)**: the accepted indicator is written for a four-contract catalogue
  ("at least 2 of 4 from stock, at most 3 of 4 without producing"). With a cap of three, the
  faithful translation is "at least 1 of the 3 from stock, never all 3 without producing" — but an
  accepted indicator is not rewritten silently, so it waits for the requester's word.
- **A2 must be re-expressed**: it asserted that a *bound warehouse* accepts inserter and robot
  insertion. The hub's inventory does, and there is no binding to test.

## What survives from `0010`

The chain of meaning: the hub is the interface, the space elevator carries the goods, the spaceport
is the counterparty that physically takes delivery, and the hub is fed by inserter **or** logistics
robot. What dies: the warehouse entity, the 1:1 binding, and the "functional inventory" condition.
