# 0023 — No physical currency: credits exist only as balances

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: `0004` (credit-item, two-way conversion at the hub)

## Context

> « Et pas de monnaie physique. »

This reverses **D1-bis**, decided the same day at block 1 and defended then: « the item exists in the
MVP, convertible both ways at the hub only; bearer asset: giftable, storable in a chest » (`0004`).

A reversal is legitimate — the framing is young and the requester is allowed to simplify his own
game. What is not legitimate is to write it as if nothing had changed, so here is the full account.

## Decision

There is **no credit item**. Credits are integers on a balance and nothing else:

- no item, no prototype, no icon;
- no face value;
- no conversion in either direction, therefore no conversion fee and no degressive conversion rate;
- no technology that improves a rate, because there is no rate;
- nothing giftable, nothing storable in a chest, nothing to lose in a destroyed container.

## What dies with it

| ID | What it said | Status |
|---|---|---|
| D1-bis | credit-item in the MVP, convertible both ways at the hub | **superseded** |
| D8 | fixed face value of the credit-item | **withdrawn** |
| D9 | conversion cost = fixed fee + degressive rate | **withdrawn** |
| D10 | two technologies improving the rate and the fee | **withdrawn** |
| D12 | gifting exists **only via credit-items** | **dead** — there is no item to gift |
| A3 | converting credits to items and back never increases the total | **replaced** |
| A4 | the conversion fee is displayed before confirmation | **withdrawn** |
| A6 | no desync across conversions and dispatches in the same tick | **reworded** — dispatches and balance reads only |
| §2 row | a player without the set cannot receive credits | **dead** — nothing travels between saves |

## What it buys, and it is a lot

- **One prototype, one item, one icon, two conversion paths gone.** The set gets smaller.
- **The conservation invariant becomes one number.** It was `sum(balances) + credits held as items`;
  it is now `sum(balances)`, and it can be asserted without walking the map.
- **The rounding rule disappears.** `0006` had to round in the hub's favour and defend it; with no
  conversion there is nothing to round.
- **No arbitrage between an item and a balance**, therefore no loop to close, therefore one fewer
  class of exploit.
- It reinforces `0021`/`0016`: the hub is a building and a book, and nothing else.
- It reinforces `0015`: the issuer's negative balance becomes the **only** channel by which the money
  supply changes. Every other operation is a transfer.

## What it costs, and this is not a detail

The item was the only thing that let value **leave** a company's books. A credit-item in a chest was
money that had escaped the ledger; a gift between players moved value without any account changing.

With it gone, **every credit stays on a company's balance, forever, and only a transfer can move it.**
Three consequences follow, and none of them is automatic:

1. **Who holds the money (Q45).** If credits live on company balances and contracts are open to every
   player (D40), then a player holds nothing. The ledger shrinks to two kinds of holder — companies
   and the federation — and a player is an operator with no purse.
2. **The bank loses its subject.** `0007` and `0011` model **player deposits earning interest** while
   the player is active. No player wallet, no deposits, no interest to pay: what remains of the
   `-bank` add-on is the company credit line, which belongs to `0015`, not to a bank.
3. **The activity rule loses its subject.** `0008` pays interest only to a player who produces. If no
   player holds anything, "a passive player earns nothing" has nothing to earn from.

Consequences 2 and 3 are exactly the kind of scope the guiding rule of this project says to remove
rather than to preserve. But they are **decisions**, not deductions, and they are asked before being
written.
