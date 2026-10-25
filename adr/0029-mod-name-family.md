# 0029 — The name: a family prefix, then the feature

- **Status**: **proposed** 2026-10-25 — the rule is accepted by the requester, **the prefix itself is
  his to choose**; nothing is named until he does
- **Date**: 2026-10-25
- **Block**: 4
- **Amends**: `0013` (the four-mod set is parked, but the naming question survives it)

## Context

> « Je voudrais un nom composé d'une partie générique avec d'autres mods complémentaires futurs. »

Even with v1 reduced to one mod, the naming decision is the one that cannot be changed later: renaming
after publication is a migration for every save that ever installed it.

The requirement is precise: a **generic part** that future complementary mods can share, and a
**specific part** that says what the mod does.

## Decision

1. **Pattern: `<family>-<feature>`**, lowercase, hyphen-separated, no spaces. The family is what the
   future mods share; the feature is what each one adds.
2. The portal title keeps the family visible: `Family — Feature`.
3. The family must be **meaningful for the fiction**, not an author signature. `walby-contracts` would
   be accurate and would tell the player nothing; a family is a world, not a vendor label.
4. The family is chosen **once**, before the first release, and never after.

## Candidates

| Family | v1 name | Future mods | Why it works | Why it might not |
|---|---|---|---|---|
| **`charter`** | `charter-contracts` | `charter-bank`, `charter-bounties`, `charter-freight` | a charter is exactly what a hub is: **a granted right to operate** in a place. Short, pronounceable in French and English, and it gives the family a meaning instead of a logo | the word is slightly formal; it does not suggest a game on its own |
| `concord` | `concord-contracts` | `concord-bank`, … | evokes an agreement between distant parties, which is the whole premise | reads like a political treaty; longer to type |
| `outpost` | `outpost-contracts` | `outpost-*` | immediately understood, very Factorio | already used by several mods on the portal; the family would be ambiguous |

**Recommendation: `charter`.** It says *why* a hub exists — someone granted the right to trade here —
it carries the concession idea of `0021` even though hub sites are parked, and it composes cleanly:
`charter-bank`, `charter-bounties`, `charter-freight`.

## What must be checked before it is written in `info.json`

- The name is free on `mods.factorio.com` (search before publishing, not after).
- Nothing in `base` or `space-age` already uses a `charter-` prefix in a way that would collide.
- The repository is renamed in the same commit as `info.json`, never later.
