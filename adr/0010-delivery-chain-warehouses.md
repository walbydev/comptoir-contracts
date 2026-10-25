# 0010 — Delivery chain: hub and space elevator, spaceport, cargo warehouses bound to a contract

- **Status**: **superseded by `0016`** (2026-10-25) — the separate cargo warehouse is removed; the hub
  carries the inventory. Kept for the record: the elevator/spaceport chain and the inserter/robot
  feeding still hold
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: —

## Context

The requester described the physical architecture on 2026-10-25:

> "The hub / space elevator is the means of communication with the spaceport. Dedicated cargo
> warehouses allow sending crafted or assembled materials. Same for receiving purchased materials. A
> warehouse must be associated with a contract for its inventory to be functional. A warehouse can be
> fed with a robotic arm or a drone directly. So it is tied to logistics."

This replaces the vague "insertion into the hub" model carried in §3 until now. It also fixes the
division of roles: the **hub + elevator** is the *interface* (contracts are negotiated there), the
**spaceport** is the *counterparty* (goods leave and arrive there), and the **cargo warehouses** are
the *physical buffer* where the player's factory meets the contract.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — Insert directly into a hub chest | lowest | the hub becomes a dump; no notion of a prepared shipment; contracts and goods are decoupled | warehouses, staged deliveries |
| B — **Dedicated warehouses, each bound to one contract, logistics-fed, then dispatched** | medium: an association model, a GUI per warehouse, expiry and destruction handling | the player builds a warehouse and fills it for a contract that expires underneath them | a single global stock |
| C — Rocket launch per delivery | high: silo, launch tracking, and a much heavier test story | — | short sessions |

## Decision

**Option B**, with these properties:

1. **One binding per warehouse**: a warehouse's inventory is **inert** until it is associated with a
   contract. An unbound warehouse must **say** it is inert and why — a silent warehouse that accepts
   items and does nothing is the worst outcome for the player.
2. **Logistics-native**: the warehouse accepts insertion from inserters and from logistics robots
   (requester chests included). No special belt, no special loader. If it works by inserter, it works
   by robot — otherwise the "tied to logistics" requirement is only half met.
3. **The warehouse is a buffer, not a payment**: filling it counts for nothing until dispatch. The
   contract is honoured at dispatch, not at insertion.
4. **Two flows, one building family**: outbound (deliver crafted/assembled materials) and inbound
   (receive purchased materials) use the same warehouse prototypes with a direction, or two
   prototypes if the GUI is clearer. Decided in block 6.

## Consequences

- **Requires**: a binding stored by `unit_number`, a GUI to bind and unbind, and a visible state per
  warehouse (inert / bound / ready / dispatching).
- **Requires**: a **loss rule** (Q24): what happens to goods inside when the contract expires, when the
  warehouse is destroyed, or when the binding is removed. Any silence here means a player loses hours
  of production without explanation.
- **Requires**: a dispatch trigger (Q24) — manual validation or automatic on quantities reached. This is
  the single biggest UX decision of the block: automatic dispatch cannot be undone, manual dispatch
  needs a confirmation that is not a trap.
- **Forbids**: several contracts sharing one warehouse in the MVP (an ambiguous inventory is unaccountable).
- **Makes harder**: the 2-hour run — a player must build a warehouse *and* fill it *and* dispatch within
  the session. The first contract must be reachable without a warehouse, or the short game never starts.
  **This is a scope constraint to settle in block 3, not an implementation detail.**

## Review

Reopen if: (a) binding per contract proves too rigid in play (a player wants one warehouse fed by one
factory for three successive contracts), (b) the first contract cannot be honoured in under 30 minutes
of a fresh game, which would kill the 2-hour horizon, (c) transit time between elevator and spaceport
is wanted — it is not modelled today.
