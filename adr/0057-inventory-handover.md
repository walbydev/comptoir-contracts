# 0057 — The engine keeps the inventory, our window lends it back

- **State**: accepted
- **Status**: accepted 2026-10-25, after the requester lost access to the counter's own inventory
- **Date**: 2026-10-25
- **Block**: lot (b)
- **Amends**: `0050` (R1), `0037` (window)

## What happened

`player.opened = nil` inside `on_gui_opened` removes the vanilla container frame — that is R1, measured
and kept. The cost was not priced: the player can no longer see or touch what is inside the counter.
On a 9x9 building that holds the contract stock, that is a hole in the middle of the loop.

## Decision

**A button in the header hands the entity back to the engine.** It sets `player.opened = entity`,
destroys our frame, and lets the vanilla inventory appear. Closing it returns to the game; clicking the
counter again brings our window back.

Rejected alternatives:

- **Mirror the stock in a third tab**: Factorio has no scriptable inventory grid with drag and drop.
  A tab could only *list* the contents, never let the player move a stack. It would look like an
  inventory and behave like a receipt.
- **Never suppress the vanilla frame**: R1 showed the two frames fight for the same event, and the
  vanilla one wins the mouse. We would lose the window, not gain the inventory.

## The trap, and its guard

Setting `player.opened = entity` **raises `on_gui_opened` again** — the same event our handler
suppresses. Without a guard, the button hands over and the handler immediately takes it back: the
button appears to do nothing, and the log looks innocent.

- `handover[player_index]` is set **before** the assignment and cleared in the handler that consumes it.
- A handover is consumed exactly once; a second open in the same tick is treated as a real open.

## The player's own inventory is not affected

`E` opens the character screen independently of `player.opened`. Nothing here touches it; it is
mentioned because the requester said "l'inventaire vanilla" and the two must not be confused in the
report of the next build.
