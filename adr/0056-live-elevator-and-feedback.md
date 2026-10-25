# 0056 — A live elevator needs a bounded clock, and every action says what it did

- **State**: accepted
- **Status**: accepted 2026-10-25, from the requester's first look at the window
- **Date**: 2026-10-25
- **Block**: lot (b)
- **Amends**: `0043` (elevator cycle), `0037` (window), `0044` (car is a state)

## Three complaints, three decisions

### 1. The car must be visible in motion

The requester asked for a "montée/descente" indicator, and for everything to pause while the car
moves. `0043` already forbade any send when the car is not down, but the window said nothing about
*why* a button was dead.

Decision: the header carries the elevator state — `down`, `rising`, `away`, `descending` — with the
remaining time, and the send button carries the same countdown when the car is not down.

### 2. A countdown cannot be drawn without a clock

The "no `on_tick`" rule (docs/arborescence.md §4.2) is what keeps a hub free at rest. A countdown
that never moves is worse than no countdown: it tells the player the wrong number.

Decision, and this is the amendment: **a bounded clock is allowed while a window is open.**
`script.on_nth_tick(30)` is registered when the first window opens and unregistered when the last one
closes. Cost: half a second of work, only while a player is looking, and nothing at all when idle.
The rule becomes "no tick when nothing is happening", not "no tick ever".

### 3. Buy and sell must answer

An action that only changes one number on screen is indistinguishable from a misclick, and the
requester clicked twice to be sure.

Decision: every action writes a **feedback line** under the tabs: what was bought or sold, how many,
and the amount. It survives until the next action, and it is the same line that carries a refusal
reason, so the player sees one place where the counter speaks.

## Consequences

- The pause covers **every** action, not only dispatch: accept, buy and sell are dead while the car
  is not down, and the reason is on the button.
- A refusal and a success share one line, which means one layout path to test instead of two.
- The bounded clock is the first `on_tick`-family registration in the mod: it must be unregistered in
  `on_gui_closed` **and** when a window is destroyed or the player is gone, or a save carries a timer
  nobody asked for.
