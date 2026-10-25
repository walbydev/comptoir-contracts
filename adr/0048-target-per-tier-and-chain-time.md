# 0048 — The payout target follows the tier, and the deadline follows the whole chain

- **State**: accepted
- **Status**: accepted 2026-10-25 by the requester ("2 par palier"), after the single-target version of
  `0047` had been written; the deadline half is a self-correction found while computing the table
- **Date**: 2026-10-25
- **Corrects**: `0047` on two points (one target for everything, and the wrong time unit)
- **Depends on**: `0047` (quantity derived from money), `0036` (the three numbers), `0043` (the cycle)

## 1. The target scales with the tier

The requester's reading was right: a tier-3 contract paying what a tier-1 contract pays feels poor at
the moment the player has everything else. The target becomes:

| Tier | Payout target | Multiplier | Typical reserve |
|---|---|---|---|
| 1 | **2 500** | ×1 | 499 – 500 |
| 2 | **7 500** | ×3 | 1 450 – 1 653 |
| 3 | **20 000** | ×8 | 3 950 |

**A company's tier is not stored.** It is read from the player's research: the highest tier of an item
whose recipe is unlocked. That is already D57 ("the real gate is the player's research") applied to the
generator, and it costs no new state and no new migration. Consequence to accept: the day the player
researches oil, **every** company raises its target at once. That reads as the companies noticing the
colony grew up — a step, not a slide.

The endowment stays at 3 000, so it covers tier 1 and tier 2 comfortably and **cannot** cover a tier-3
reserve. That is deliberate: a cooperative that has reached tier 3 has been earning for hours, and a
contract the pot cannot afford is refused **visibly** (D47, A22), not silently.

## 2. The deadline was measuring the wrong thing

`0047` used `qty × machine_seconds`, where `machine_seconds` is the crafting time of the **item
itself**. Computing the tier-2 and tier-3 rows exposed the defect: ten processing units came out at
**6:00**, because ten units × 10 s is almost nothing — while their real chain is 20 circuits, 2 advanced
circuits and 5 sulfuric acid per unit, i.e. **266 seconds of furnace, assembler and chemical plant per
unit**, and 17 170 raw units for ten.

The fix is a measurement, not a coefficient: `tools/cost_table.py` now walks the recipe tree and emits
**`chain`** — the total machine-seconds to produce one unit, all intermediates included. The price data
carries it, the generator reads it.

```
production = qty × chain_seconds / 2 × 1.5      -- two machines, 50 % slack
deadline   = max(4 min, production) + cycle     -- cycle = 2 min (D72)
```

| Contract | Units | Pays | Reserves | Chain/unit | Deadline |
|---|---|---|---|---|---|
| iron plate | 208 | 2 496 | 500 | 3.2 s | 10:19 |
| steel plate | 43 | 2 494 | 499 | 32.0 s | 19:12 |
| electronic circuit | 86 | 2 494 | 499 | 9.2 s | 11:56 |
| plastic bar | 29 | 7 627 | 1 526 | 1.6 s | 6:00 |
| advanced circuit | 12 | 7 248 | 1 450 | 35.1 s | 7:16 |
| low-density structure | 5 | 8 265 | 1 653 | 151.1 s | 11:26 |
| processing unit | 10 | 19 750 | 3 950 | 266.7 s | 35:20 |

Steel against processing unit is the sanity check: 43 steel plates earn about an eighth of ten
processing units and take **half the time**, which is exactly what a player who has ever smelted steel
would say.

## 3. What this assumes, written down

The chain figure counts **machine time**, not the mining and hauling behind it. A deadline therefore
assumes the player's supply chain is already running — a contract is not a bootstrap test. The first
contract of a fresh save is 208 iron plates at 10:19, which a two-furnace base can do, and A1 caps the
whole first loop at 30 minutes.

If playtesting shows the deadlines are tight in practice, the lever is the **1.5 slack factor**, one
number, not the table.

## 4. Consequence for the code

`config/balance.lua` must carry three targets and the slack factor, not one target; the generator must
read `chain` from the price data rather than `seconds`. The task was already running with the old
values when this ADR was written, so the delta is applied as a correction, not as a rewrite — and the
test that guards A30 must assert against `chain`, otherwise it would keep passing on the wrong unit.
