# 05 — The price table, computed from the game's own recipes

- **Status**: measured 2026-10-25 — the table is derived, not invented; three numbers await
  arbitration (§4)
- **Source**: `factorio --mod-directory <empty> --dump-data` → **217 recipes**, base **2.1.23
  build 87750**, Space Age, Quality, Elevated rails and Recycler **disabled** (they change the
  recipes of the very items we price)
- **Tool**: `tools/cost_table.py` — re-run it when the game version moves; the table follows

## 1. The cost model

```
raw(item) = sum over raw resources of amount × weight
credits   = ceil(raw × 10)
payout    = ceil(credits × 1.15)
price     = ceil(credits × 1.50)
```

- **One raw resource = one unit.** Iron ore, copper ore, stone, coal, crude oil and wood weigh 1;
  uranium weighs 4; water weighs 0 (free and infinite).
- Oil gets **no special weight**. Its real cost is already inside the recipes: basic oil
  processing turns 100 crude oil into 45 petroleum gas, and that 55 % loss *is* the cost. Adding a
  weight would count it twice.
- **Machine time and energy are measured but not charged.** Time is a throughput constraint, not a
  material cost, and energy is free for a player who builds solar. Charging either would punish the
  player who builds well.
- `× 10` keeps the smallest item (copper cable, 0.5) at 5 credits instead of 0.5, so the whole table
  stays integral — D7 says integers only.

### Two traps found on real data

| Trap | What it produced | Fix |
|---|---|---|
| Picking the recipe with the fewest ingredients | a **plastic bar worth 140 iron plates** | prefer the recipe **named after the item**, then plain crafting |
| Barrel recipes exist for every fluid (`empty-petroleum-gas-barrel` has **one** ingredient) | a unit of **petroleum gas worth 0.1**, i.e. oil was almost free and every oil-based item was underpriced | barrel fill/empty recipes are excluded: they are storage, not production |

Both were caught by comparing the output against arithmetic that can be checked by hand (one
electronic circuit = 1 iron plate + 3 copper cable = 2.5 units). That comparison is the reason this
document exists in a repository rather than in someone's memory.

## 2. The v1 counter list — measured

Materials only, no buildings (decided 2026-10-25).

| Item | Raw | Credits | s (speed 1) | kJ | Payout | Shop price | Tier |
|---|---|---|---|---|---|---|---|
| `copper-cable` | 0.5 | 5 | 0.25 | 37.5 | 6 | 8 | 1 |
| `iron-plate` | 1.0 | 10 | 3.2 | 288 | 12 | 15 | 1 |
| `copper-plate` | 1.0 | 10 | 3.2 | 288 | 12 | 15 | 1 |
| `pipe` | 1.0 | 10 | 0.5 | 75 | 12 | 15 | 1 |
| `stone-brick` | 2.0 | 20 | 3.2 | 288 | 23 | 30 | 1 |
| `iron-gear-wheel` | 2.0 | 20 | 0.5 | 75 | 23 | 30 | 1 |
| `electronic-circuit` | 2.5 | 25 | 0.5 | 75 | 29 | 38 | 1 |
| `steel-plate` | 5.0 | 50 | 16.0 | 1440 | 58 | 75 | 1 |
| `engine-unit` | 9.0 | 90 | 10.0 | 1500 | 104 | 135 | 1 |
| `plastic-bar` | 22.7 | 228 | 0.5 | 90 | 263 | 342 | 2 |
| `sulfur` | 33.3 | 334 | 0.5 | 90 | 385 | 501 | 2 |
| `electric-engine-unit` | 41.3 | 413 | 10.0 | 1800 | 475 | 620 | 2 |
| `advanced-circuit` | 52.4 | 525 | 6.0 | 900 | 604 | 788 | 2 |
| `battery` | 69.1 | 691 | 4.0 | 720 | 795 | 1037 | 2 |
| `low-density-structure` | 143.6 | 1437 | 15.0 | 2250 | 1653 | 2156 | 2 |
| `processing-unit` | 171.7 | 1717 | 10.0 | 1800 | 1975 | 2576 | 3 |

The spread from copper cable to processing unit is **343×**, and that is the truth of the game: a
processing unit really is worth hundreds of cables. A single credit currency handled it without a
per-tier multiplier, which is what we wanted.

## 3. What the table settles by itself

- **A contract is a quantity of one item**: `payout = quantity × payout(item)`. Nothing else needs
  pricing, and the band is respected per item rather than per contract.
- **The share of the counter is 50 %**: it sells at `cost × 1.5`. For the shop to buy back without
  printing money, it must buy at **`cost`** — the price divided by 1.5. Selling at the price and
  buying at the price would be an infinite credit loop, and the loop would be discovered by a player
  within an hour.
- **The cooperative's income is 15 % above raw cost** on a delivered contract. That is thin by
  design: contracts pay for *transformation*, and the shop is where credits leave the cooperative.

## 4. The three numbers — arbitrated 2026-10-25

| # | Number | Adopted | Why |
|---|---|---|---|
| 1 | **Scale** (credits per raw unit) | **10** | keeps every item integral and the smallest one at 5 credits |
| 2 | **Escrow rate** (D47) | **20 %** of the payout | one failed contract out of five wipes the margin; below 10 % it stops being a deterrent |
| 3 | **Initial endowment** (D28) | **3 000** | covers a first contract's reserve (500) six times over and still buys a stack: `208 × 12 × 1.2 ≈ 3 000` |

Numbers 1 and 3 are arithmetic. Number 2 is the only judgement in the trio.

## 6. What gates a contract — measured, not chosen

The tier of an item is **how deep it sits in the oil chain**, because that is what decides whether a
player can build it. Science packs were tried first and they lie: in base 2.1.23 `advanced-circuit` is
unlocked by a technology costing only red and green science, while the item needs plastic — a contract
would have asked for it with no refinery on the map.

| Tier | Meaning | Items |
|---|---|---|
| **1** | no fluid anywhere in the recipe tree — buildable before oil | 9: cable, both plates, pipe, brick, gear, circuit, steel, engine |
| **2** | one oil step, or one item away from oil | 6: plastic, sulfur, electric engine, advanced circuit, battery, LDS |
| **3** | a chain of oil-based items | 1: processing unit |

The counter itself is **tier 1 by construction**: its recipe contains no oil-derived item (ADR 0033),
so the loop exists before the refinery does.

Tier 3 holds a single item today. That is the data, not a mistake: only the processing unit sits three
oil steps deep. The catalogue grows by adding items, and the tier follows automatically.

## 7. Closed at the end of block 5

All three numbers are arbitrated — **scale 10, escrow 20 %, endowment 3 000** (ADR 0036) — and the
refill is immediate, with no timer (ADR 0035). What a first contract looks like with these numbers:

```
208 iron plates    pays 2 496    reserves 500    deadline 5 min 33 at two furnaces
```

That is the whole loop in one line: cheap to accept, quick to deliver, and worth roughly a third of the
endowment. The economy has no free parameter left except the shapes of the UI, which is block 6.
