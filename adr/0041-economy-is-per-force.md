# 0041 — The economy is per force

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 8
- **Closes**: Q56
- **Completes**: `0040`, `0026`

## Decision

Companies, the cooperative account, contracts, and the counter's stock are **owned by a force**. Each
force has its own ledger: its own cooperative balance, its own companies, its own contracts. Nothing
crosses a force boundary, ever.

## Why

- **Coherence.** A company "belongs to nobody in particular and is operated by everybody" (`0024`) — but
  *everybody* means everybody on the same side. Sharing credits with an opponent on a PvP map is not a
  co-op, it is a subsidy.
- **The engine already does it.** Entities belong to a force, inserters work per force, and the map's
  safety logic is already force-scoped. Mirroring that in `storage` means the mod's state has the same
  shape as the world it describes.
- **It is the cheap moment.** The shape of `storage` is decided once. Changing it after release means a
  migration that splits an existing global ledger across forces — with no correct rule for the split.

## Consequences

| Area | Effect |
|---|---|
| `storage` | keyed by `force.index` (or `force.name`), never a flat global table |
| contract generation | each force's companies generate from **that force's** research state |
| the counter | an entity, therefore already force-owned; its stock follows |
| single player | one force, so the behaviour is exactly as specified — the neutral case is unchanged |
| PvP | two independent economies; a player can be rich in one and broke in the other |

## Accepted test criterion

**A28**: on a map with two forces, a contract completed by force A leaves force B's cooperative balance
and company records **byte-identical** — compared before and after, not assumed.
