# 0036 — The three balancing numbers: 10, 20 %, 3 000

- **Status**: accepted 2026-10-25 — closes Q51
- **Date**: 2026-10-25
- **Block**: 5
- **Depends on**: `0028` (escrow), `0015` (issuer), `0032` (counter spread), `docs/05-price-table.md`

## The three numbers

| # | Number | Value | What it does |
|---|---|---|---|
| 1 | **Scale** | `10` credits per raw unit | a plate is worth 10, a cable 5, a processing unit 1 717 |
| 2 | **Escrow rate** | `20 %` of the payout | one failed contract in five eats the margin of a delivered one |
| 3 | **Initial endowment** | `3 000` credits, issued once to the cooperative | enough to accept a first contract and buy the material for it |

## Why these, and not rounder ones

**Scale 10** is what keeps the table integral. At scale 1, copper cable costs 0.5 and the game would
have to show half-credits, which contradicts D7 (integers only). At scale 10 every value in the table
is a whole number, and the smallest purchase in the shop is 8 credits.

**20 %** is the only one of the three that is a judgement. At 5 % a failed contract is a shrug; at 50 %
it is a punishment that stops the player from ever taking a risk. Twenty per cent means: *you can be
wrong, once, without dying*.

**3 000** is arithmetic, not taste. A first tier-1 contract asks for about 208 iron plates, pays
`208 × 12 = 2 496`, and therefore reserves `500`. The endowment covers that reservation six times
over, and still leaves 2 500 to buy steel or circuits with. It is not a gift: it is the minimum that
makes the first loop playable without a dry pot on day one.

## What the numbers look like in play

```
first contract:   208 iron plates       pays 2 496       reserves 500
deadline:         max(10 min, 208 × 3.2 s / 2) = 5 min 33 with two furnaces
after delivery:   pot = 3 000 + 2 496 = 5 496, reserve released
buying power:     366 iron plates, or 144 electronic circuits, or 7 processing units
```

A player who honours three contracts of that size can buy his way through the early game's tedium —
steel, circuits — but never through a technology: nothing here sells a building.
