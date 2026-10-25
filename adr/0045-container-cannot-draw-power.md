# 0045 — A container cannot draw power: the counter's entity type has to move

- **Status**: **proposed** 2026-10-25 — blocked on a GUI spike and on Q58
- **Date**: 2026-10-25
- **Reported by**: the coding agent, while implementing task a3
- **Contradicts**: D31 / `0016` (the hub is a container) versus D49 / `0030` (the hub draws power)

## What was measured

The coding agent reported that a `container` silently ignores `energy_source`. Re-measured here on
2.1.23, from the prototype dump:

| Prototype | Energy fields exposed |
|---|---|
| `container/wooden-chest` | **none** — the dump has no `energy_source`, no `energy_usage`, no `power` key of any kind |
| `assembling-machine/assembling-machine-1` | `energy_source` (electric, usage priority, emissions), `energy_usage = 75 kW` |

So the finding is real and it is not a version detail: **the container prototype family has no energy
model at all.** Setting `energy_source` on a container at the data stage is accepted and then dropped.

## Why this is a framing problem and not a coding problem

Two accepted decisions cannot both hold:

- **D31** (`0016`): the hub **is** the warehouse — one entity, its own inventory, no second building.
  A container is the natural type: inserters and robots fill it natively, no script involved.
- **D49** (`0030`): the hub has a **small electric draw**, which is what makes it a placement
  constraint (no counter in the wilderness) and gives the unpowered state its meaning (D49, A22).

A container gives the first and forbids the second.

## The two honest options

### Option A — drop the draw, keep the container

The counter works anywhere, powered or not. Cost: we lose the placement constraint that came free with
the draw, the *counter closed* state disappears, and an elevator with no power supply is a small lie in
a game where everything else hums.

Cheapest path, zero new risk. It is what I would choose if the only criterion were the calendar.

### Option B — change the type to an energy-capable entity with an inventory

An `assembling-machine` with no recipe, a dummy `crafting_categories`, a large `inventory_size`, and
`energy_source = electric` at about 30 kW. Inserters still insert (into the input inventory), robots
still deliver, and the entity gains three things a container can never offer:

1. **power**, therefore the placement constraint and the closed state;
2. **an `active` flag that drives a working animation** — which is exactly what route A (D73) needs for
   the elevator: the car's state becomes a sprite that already exists in the game's machine graphics,
   with no per-tick work;
3. a credible "the elevator is running" tell in the world, not only in the window.

Cost: a GUI spike. A machine opens its own crafting frame on click, and we must be sure that
`on_gui_opened` lets us draw our own window without the vanilla frame appearing behind it, and that
`inventory_size` can be made large enough to hold a contract's worth of goods.

## Recommendation

**Option B, conditional on the spike.** The draw is not cosmetic: it is the only thing that anchors the
counter to a base, and the animation bonus turns a risk (route A reads as a teleport) into a gain. If
the spike shows the vanilla frame cannot be suppressed, fall back to Option A and delete D49 in a
follow-up ADR rather than living with a dead field.

## What the spike must answer, with output

1. Does `on_gui_opened` on an `assembling-machine` with no recipe open **only** our frame?
2. Do inserters insert into its input inventory when `inventory_size` is raised, and do robots deliver?
3. Does setting `entity.active` play the working animation with no recipe and no power?
4. Does an unpowered machine report a state we can read without an `on_tick`?

Until those four lines exist, this ADR stays **proposed** and the code keeps the container, with no
decorative energy field.
