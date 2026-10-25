# 0050 — The GUI is not testable headless, so R1 belongs to the requester's machine

- **State**: accepted
- **Status**: accepted 2026-10-25, after a spike measured five questions and answered "impossible" to four
- **Date**: 2026-10-25
- **Block**: 6, on the eve of lot (b)

## What the spike measured, on 2.1.23

- `game.create_player` **does not exist**. Binary check: `strings` finds `get_player` twice and
  `create_player` zero times.
- A `LuaPlayer` only exists once a client connects. Headless creates none: `game.players` is empty,
  `game.player` is nil, `game.get_player(1)` returns nil.
- `game.gui` **does not exist** either, so there is no way around it.
- Consequently `player.opened`, `player.gui.screen`, `on_gui_opened` and `on_gui_closed` cannot be
  exercised at all: the handlers register fine and receive zero events.
- No graphical client is installed on this machine, so the gap cannot be closed here.

Bonus trap, paid during the spike: **`--start-server` does not tick without `"auto_pause": false`**
in the server settings. The server sat at tick 0 and no script ran, which looks exactly like a
broken mod.

## Consequence: the plan changes, and the requester is now on the critical path

1. **A20, A22, A23 and A24 stay by-eye criteria.** They cannot be automated, here or anywhere
   without a graphical client. The matrix in `docs/09-tests.md` was right to put them in layer 3.
2. **R1 — "a custom GUI on a `container`" — cannot be closed on this machine.** The first genuine
   measurement is the requester's client, on his machine, with a throwaway probe mod.
3. **Therefore R1 is a gate before the window is written, not after.** If the vanilla container frame
   cannot be suppressed, the entity type is wrong and the window code would be written against a
   dead foundation.
4. **Every visual iteration costs a trip.** The window must be built conservative and ugly-but-correct
   first: one frame, two tabs, no styling. Styling comes after the mechanism is proven.

## What the probe answers

A 30-line throwaway mod, `spike/gui-probe/`, loaded beside the real mod:

- `on_gui_opened` sets `player.opened = nil`, then adds a frame with a label to `player.gui.screen`.
- The requester places a counter, opens it, and answers one question: **does he see our frame, and
  does the vanilla inventory frame appear too?**

If our frame appears alone, R1 is closed and lot (b) proceeds as designed. If the vanilla frame
stacks on top, `0045`'s option B (an assembling machine) comes back, and that is a redesign of the
counter, not a detail of the window.
