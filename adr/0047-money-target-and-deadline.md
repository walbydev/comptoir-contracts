# 0047 — The economy was inconsistent: a money target, a quantity floor of 1, and a deadline that varies

- **State**: accepted
  `docs/05-price-table.md`
- **Date**: 2026-10-25
- **Reported by**: the coding agent, while implementing a7. Both defects are mine.

## Defect 1 — the deadline never depended on the work

The formula was `max(10 min, qty × machine_seconds / 2) + cycle`. Applied to the real table it gives
**720 seconds for all sixteen items**: `qty` is derived from a payout target of 2 500 credits, and no
item needs more than 600 seconds of machine time to earn that. The quantity term was therefore dead
code, and every contract had exactly the same deadline.

The worked example in `docs/05` said *7 min 33* for 208 iron plates. The true value is
`max(600, 208 × 3.2 / 2) + 120 = 600 + 120 = 720 s = 12:00`. **The example was arithmetically wrong**,
and it hid the fact that the floor was swallowing the formula.

### Fix

```
production = qty × machine_seconds / 2 × 1.5      -- two machines, 50 % slack
deadline   = max(4 min, production) + cycle        -- cycle = 2 min (D72)
```

With the same table: iron plates → 8:19 of production, 10:19 total; steel 43 units → 8:36, 10:36;
copper cable 417 units → floor, 6:00; processing unit 1 unit → floor, 6:00. **The deadline now moves with
the work**, which is what it was supposed to do, and the floor only catches the cheap fast items.

## Defect 2 — half the catalogue was unpurchasable

The quantity band was `[30, 500]` around a 2 500-credit target. For an item at 1 975 credits per unit,
30 units means a payout of **59 250** and a reserve of **11 850** — against a starting endowment of
**3 000**. Eight of the sixteen items were in that position: the contract existed, and no cooperative
could ever accept it.

### Fix

**The contract targets an amount of money, and the quantity is derived from it**:

```
qty = clamp(round(target_payout / payout_per_unit), 1, 500)
target_payout = 2 500   -- one number, in the data file
```

The floor is **1 unit**, not 30. A processing-unit contract is *one* unit that pays 1 975 with a 395
reserve: small in tonnage, large in money, and affordable from the first hour. A plate contract is 208
units paying 2 496. The floor on quantity was a leftover from thinking about tonnage; the floor belongs
on the **money**, not on the count.

`target_payout` was never written in any document — the agent had to infer it. It is now a number in
`config/balance.lua`, generated into the data file and printed by `make prices`.

## Consequences

- The escrow stays 20 % of the payout, so it ranges from 395 to 500 credits in v1: the 3 000 endowment
  covers several contracts at once, which is what it was for.
- The tier-scaled payout target (a bigger target at tier 2 and 3) is **not** in v1: one number, one
  behaviour, and the pot grows by playing.
- `docs/05` §7, `specs/001-v1/design.md` §5 and `docs/arborescence.md` are corrected in the same commit.
  An example that contradicts its own formula is worse than no example.

## Lesson worth keeping

Both defects were arithmetically checkable from documents I had already written, and neither was checked
until code met the numbers. **A formula in a framing document must be evaluated once against a real
row of its own table** — the cost of doing it is one line of arithmetic, and the cost of not doing it was
two defects that reached code.
