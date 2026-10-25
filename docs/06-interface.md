# 06 — The interface

- **Status**: specified 2026-10-25 — two UX choices still open (§6)
- **Depends on**: ADR `0037` (structure), `0022` (character), `0034` (generation), `0036` (numbers)
- **Screens**: one window, two tabs

## 1. Shape

```
┌──────────────────────────────────────────────────────────────────────┐
│  MÉRIDIEN TRADING                       EXPÉDITION · PAIE LARGE      │
│  disponible 4 996        réservé 500                                 │
├──────────────────────────────────────────────────────────────────────┤
│  [ CONTRATS ]   Comptoir                                             │
├──────────────────────────────────────────────────────────────────────┤
│  (icon)  208 × Iron plate                     2 496 cr               │
│          reserve 500            ▓▓▓▓▓▓░░░░  5:33      [ ACCEPT ]     │
│                                                                      │
│  (icon)   40 × Electronic circuit             1 160 cr               │
│          reserve 232           ▓▓▓▓▓▓▓▓▓░  12:04      [ DELIVER 38 ] │
│                                                                      │
│  ── empty slot ──                                                    │
└──────────────────────────────────────────────────────────────────────┘
```

- **Header**: company name (left), character line (right, one line, colour-coded), then the two
  numbers. It never moves and never changes height.
- **Tabs**: text buttons, the active one underlined. No icons in the tab strip.
- **Contract rows**: fixed height. The action button is the **only** thing in the row that responds to
  a click.

## 2. The contract row, field by field

| Field | Shown as | Notes |
|---|---|---|
| item | game sprite + name | the sprite is the game's own, never a character |
| quantity | right-aligned integer | grouped above a thousand |
| payout | `2 496 cr` | what the cooperative receives on delivery |
| reserve | `reserve 500` | what is held from acceptance until delivery |
| deadline | digits `M:SS` **and** a bar | bar turns amber under 25 % of the time, red under 10 % |
| state | implied by the action button | see below |
| action | **one** contextual button | `ACCEPT` → `DELIVER n` (n = how many the hub currently holds) |

The button is contextual rather than duplicated because a row with two buttons is a row where the
player clicks the wrong one under pressure, and the wrong one costs the reserve.

`DELIVER 38` is disabled when the hub holds nothing of that item: the number in the label is the reason.

## 3. The counter tab

Sixteen rows, one per catalogue item, in **price order** (cheapest first) so the tab reads as a ladder
rather than as an alphabetical dump.

| Field | Shown as |
|---|---|
| item | game sprite + name |
| price | `15 cr` — the price paid by the cooperative when buying |
| buy-back | `10 cr` — the price received when selling, shown in the same row, dimmed |
| quantity | the control still undecided (§6) |
| actions | `BUY` and `SELL` |

Showing both prices on the same row is deliberate: the 50 % spread (`0032`) is the counter's margin, it
is visible, and a player who sees it stops looking for an arbitrage that does not exist.

## 4. States of the whole window

The elevator adds three (ADR 0043), and they are visible in the **header**, next to the company line:
`● elevator down` / `▲ away · 1:12` / `▼ returning`. The send button is disabled whenever the car is not
down, with the remaining time on the button itself (A29).

| State | What the window shows |
|---|---|
| **cooperative at zero** | header shows `available 0 · reserved 0`, contracts cannot be accepted, the counter tab still accepts **sales** (that is the way back — A14) |
| **no contract offerable** | the slot says *nothing available* — with the reason if it is research, because a silent empty slot reads as a bug |
| **contract expired while the window is open** | the row turns red, the button becomes `ACCEPT` again after the next refill, and the reserve is already gone from the header |

## 5. Rules that make it testable

- **A19**: the header's two numbers always satisfy `available + reserved = total` for the cooperative.
- **A20**: at 100 % GUI scale and at 150 %, no text is truncated and no control is out of the window.
- **A21**: every visible string exists in both `locale/en` and `locale/fr` — a missing key shows as the
  key itself, which is a failure, not a fallback.
- **A22**: an action button is never enabled when the action would fail (no coverage, no goods).

## 6. Closed — both, in each case (ADR 0038)

- **The deadline**: digits **and** bar. The digits answer *do I have time*, the bar answers *am I in
  trouble* — and the player reads one or the other depending on how fast he is moving.
- **The quantity**: a **text field with four presets** (`1`, `10`, `100`, `stack`) sharing a single
  value. A preset writes the field, it does not bypass it: one number on screen, and the player can
  correct it to 37 when a contract asks for 208 and he wants the exact remainder.
