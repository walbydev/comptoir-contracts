# 0049 — A2 is amended: inserter yes, robot not in v1

- **State**: accepted
- **Status**: accepted 2026-10-25, because the test bench measured the prototype instead of trusting the document
- **Date**: 2026-10-25
- **Corrects**: A2 in the acceptance criteria, and every sentence that claimed the counter is filled by robots

## What the measurement says

The test bench reported `prototypes.entity["comptoir-counter"].logistic_mode = nil`, and a logistic
robot only delivers to an entity that carries a logistic request. Our counter is a plain `container`,
so **robots cannot fill it**. The inserter path works and is proven.

## Why the first conclusion was too quick

"Robots cannot fill the counter" is true of *our prototype*, not of the engine. A
`logistic-container` with `logistic_mode = "requester"` **is** filled by robots — that is what a
requester chest is. So the engine allows it; our choice of prototype is what forbids it.

Keeping that route open costs a condition we have not decided yet: a requester only receives what it
**asks** for, so the script would have to write request slots that track the active contracts, and
clear them when a contract is done. That is a second behaviour, with its own failure modes (a stale
request that drains the base), and v1 does not have it.

## Decision

- **A2 becomes**: "the counter's inventory accepts insertion by inserter, and the stock is read by
  the contract logic" — nothing about robots.
- **Robot feeding is parked**, and its exact price is written here: clone `logistic-container`
  instead of `container`, set `logistic_mode = "requester"`, and keep request slots in step with the
  contracts. It returns with `comptoir-freight` or a dedicated evolution, not before.
- Any document, comment or criteria line that says "insertion by inserter **or** logistics robot" is
  now false and must be corrected wherever it appears.

## Consequence for the player

Goods reach the counter by belt, inserter, or a player's hands — never by air. That is consistent
with the rest of the design: the counter is a place, not a mailbox.
