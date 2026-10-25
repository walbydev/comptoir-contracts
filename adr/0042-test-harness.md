# 0042 — A separate test mod, three proof layers, and a build that refuses to lie

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 9
- **Produces**: `docs/09-tests.md`

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | The in-game assertions live in a **separate mod**, `comptoir-test`, which is **never packaged** | the shipped archive contains no test code, no dead branch, no hidden setting a player could trip over. A second mod is a second folder, not a second repository |
| 2 | **Three layers**: static (L1), headless behaviour (L2), by eye (L3) | each layer proves what the others cannot. Merging them produces the classic lie: a green suite over an interface nobody opened |
| 3 | **`make accept` refuses to be green** while any L3 row is unrecorded | a suite that passes while four criteria were never looked at is worse than no suite: it buys false confidence |
| 4 | CI is limited to **what it can actually do**: packaging, archive hygiene, price-table reproducibility | GitHub Actions cannot run Factorio without the headless binary and a licence. A CI that pretends to run gameplay tests would be a decoration |

## The number this ADR is really about

28 criteria: **17 proven in game, 6 statically, 4 by eye, 4 out of v1** (A4 withdrawn, A8 and A11
parked, A12 partial). The by-eye four are named, assigned to the requester, and given a table with one
row per release — because the honest way to handle an untestable claim is to make it **visible** and
**dated**, not to bury it.

## What would make this wrong later

- If the test mod ever needs code that the main mod does not have, it is testing a different mod.
- If an L3 criterion is recorded without a screenshot or a date, the record is worthless.
- If `make test` starts taking ten minutes, it will stop being run; the scenarios must stay small and
  targeted, and the 1 000-iteration generator checks belong to L1-style batch runs, not to the loop.
