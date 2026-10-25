# 0037 — The counter window: two tabs, one permanent header

- **Status**: accepted 2026-10-25 by the requester ("1 deux, 2 deux")
- **Date**: 2026-10-25
- **Block**: 6
- **Depends on**: `0022` (character), `0034` (generation), `0036` (numbers)

## Decision

1. **Two tabs**, *Contracts* and *Counter*, inside one window.
2. A **permanent header** above the tabs, visible from both: the company, its character line, and
   **two numbers — available and reserved**.

## Why two tabs and not one panel

The v1 data does not fit a comfortable single panel: **three contract rows** (item, quantity, payout,
reserve, deadline, action) plus **sixteen shop rows** (icon, name, price, quantity control, two
actions). Stacked, that is a window taller than the 1080-pixel screen at default GUI scale minus the
hotbar. Split, each tab is short enough to read without scrolling.

The header stays outside the tabs because **the balance is the one thing the player checks before every
decision**: whether he can accept a contract, and whether he can afford a purchase. Putting it inside a
tab would mean leaving the tab to answer it.

## Why two numbers, not one

`available = total − reserved`. The store shows **both**:

| Shown | Why it must be shown |
|---|---|
| **available** | the only number that can be spent |
| **reserved** | the money already committed to accepted contracts; hiding it forces the player to do mental arithmetic before every click, and then to *guess* why a purchase is refused |

A single number would be simpler to draw and would make the escrow feel like a bug.

## Consequences that are not negotiable

- **No emoji in the window's navigation or labels.** The requester's taste, and it applies here: any
  icon in the interface is a **game sprite** (the item's own icon), never a character.
- **Every string in `locale/en` and `locale/fr`** (`0036` D51). No inline English in Lua.
- **The window never resizes itself** when a number changes: fixed width, fixed row height, so a
  contract completing does not move the button the player is about to click.
- **Numbers are right-aligned and grouped by thousands** (`4 996`), because the endowment is 3 000 and
  the table reaches 2 576 for a single item.
