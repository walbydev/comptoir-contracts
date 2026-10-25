# 0029 — The name: a family prefix, then the feature

- **State**: accepted
  the repository was renamed to match in the same pass, before any publication
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

### Second batch — 2026-10-25, `charter` rejected by the requester

> « D'autres noms, charter me plaît pas trop. »

The first batch is kept above as the record of what was considered. Four more, each judged on the same
three criteria: does it compose with future features, does it say something about the world, is it
pronounceable in French and English.

| Family | v1 name | Future mods | Reading |
|---|---|---|---|
| **`meridian`** | `meridian-contracts` | `meridian-freight`, `meridian-bank`, `meridian-bounties` | a line that crosses a world; sounds like a trading house rather than a mechanic. Corporate, sober, pronounceable both ways. **New recommendation** |
| `convoy` | `convoy-contracts` | `convoy-freight`, `convoy-escort` | freight and movement, punchy, immediately concrete — but it points at transport more than at trade |
| `caravan` | `caravan-contracts` | `caravan-freight` | a trade route, warm and human; slightly land-based for a setting with space elevators |
| `comptoir` | `comptoir-contracts` | `comptoir-freight` | French for *trading post*, which is exactly what a hub is; unique on the portal and memorable, but exotic to an English-speaking player |

**New recommendation: `meridian`.** It is the only one of the four that reads as a **company group**
rather than as a single mechanic, which is what a family prefix has to do.

### Decision — 2026-10-25: `comptoir`

> « 1 comptoir »

The requester chose the option that was listed as the exotic one, and he is right for a reason worth
recording: **`comptoir` is already the project's word for the building.** The vocabulary settled earlier
was "comptoir rather than charter" for the hub itself, so naming the family after it is the only choice
that keeps one word for one thing. A player reads `comptoir-contracts`, walks to a *comptoir*, and the
fiction holds without a glossary.

| | |
|---|---|
| v1 mod id | **`comptoir-contracts`** |
| portal title | **Comptoir — Contracts** |
| future mods | `comptoir-freight`, `comptoir-bank`, `comptoir-bounties` |
| repository | `walbydev/comptoir-contracts` — renamed 2026-10-25, before any publication |
| package | `comptoir-contracts_<version>.zip` |

**Accepted risk**: the word is French, and an English-speaking player sees a foreign word on the portal.
It is short, it is pronounced nearly the same in both languages, and the mod's own text will introduce
it. The alternative — a neutral corporate word — was tried twice and read as generic.

## What must be checked before it is written in `info.json`

- The name is free on `mods.factorio.com` (search before publishing, not after).
- Nothing in `base` or `space-age` already uses a `charter-` prefix in a way that would collide.
- The repository is renamed in the same commit as `info.json`, never later.
