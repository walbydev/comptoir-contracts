# 0038 — The two display questions: both, in each case

- **Status**: accepted 2026-10-25 by the requester ("1 les deux, 2 les deux")
- **Date**: 2026-10-25
- **Block**: 6
- **Completes**: `docs/06-interface.md` §6

## 1. The deadline shows digits and a bar

`5:33` plus a bar, never one alone. They answer two different questions:

| Element | The question it answers | When it is read |
|---|---|---|
| **digits** `M:SS` | *do I have time to start this?* | before accepting, and while planning |
| **bar** | *am I in trouble right now?* | in passing, without reading |

A player who has to read a bar to know the minutes is slowed down; a player who has to read digits
while running does not read them at all. Both is not decoration — it is the only version that works at a
glance **and** on request.

Bar colour follows the fraction of time left: normal above 25 %, **amber** under 25 %, **red** under
10 %. The digits never change colour: the number is information, the colour is alarm.

## 2. The quantity is a field with presets, not a choice between them

The counter's quantity control is a **text field with four preset buttons beneath it**: `1`, `10`,
`100`, `stack`.

- The **field** exists because the player sometimes needs 37 — a contract asks for 208 plates, and the
  difference between 200 and 208 is a contract not delivered.
- The **presets** exist because a field-only control means clicking, selecting, typing and confirming
  for every purchase, and 95 % of purchases are round numbers.

Both share one value: a preset **writes into the field**, it does not bypass it. So there is one number
on screen to trust, and the player can correct it.

Rules:

- The field accepts digits only, is clamped to `[1, 2 147]` (a wagon's worth of anything, and the
  game's inventory transfer limit).
- A preset larger than the balance is **clamped at the maximum affordable**, and the button shows that
  maximum instead of lying.
- `stack` means the stack size of that item, not the inventory's contents.

## Testable

- **A23**: the quantity field and the presets never disagree — a preset writes the field, and the
  action button always acts on the value displayed.
- **A24**: no preset can produce a value above what the balance allows, and a preset that would is
  clamped and **displays the clamped value** before the click.
