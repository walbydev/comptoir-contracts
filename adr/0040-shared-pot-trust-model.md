# 0040 — Who may act: everyone, because the engine offers no role to give

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 8
- **Depends on**: `0026` (cooperative), `0027`/`0028` (escrow), `0016` (hub is the warehouse)

## The problem

The cooperative account is **shared by every player** (`0026`). Anyone can therefore accept a contract
and let it expire, burning a reserve that belongs to the group. That is a griefing surface, and it is
not hypothetical: it costs one click.

## What the engine actually allows — measured 2026-10-25

- A prototype dump of **2.1.23** contains **no `custom-permission` type**. A mod **cannot define its
  own permission** ("may accept a contract"), and therefore cannot grant it selectively.
- The only runtime levers are `player.admin` and vanilla permission groups. Both are **admin switches**,
  not game roles: they are all-or-nothing at the level of the whole game, and nobody hands out admin
  rights to let a friend trade.
- Worse: even a "manager" role would be **unenforceable**. The hub is a `container` (`0016`): any player
  can open it, take the goods out, and deconstruct the building. A permission layer would be a promise
  the engine cannot keep.

## Decision

**Every player may act.** Accepting, delivering, buying and selling are open to all. The model is
cooperative trust, stated plainly, and **the damage is bounded by design rather than by permissions**:

| Bound | Value | Where it comes from |
|---|---|---|
| contracts a single mistake can lock | at most 3 per company | D31 (`0016`), 1–3 active contracts |
| the cost of one failure | 20 % of one payout | D47 (`0028`), escrow rate |
| the visible warning | reserve shown **before** acceptance | A13 |
| the way back | the counter always buys | D48 (`0028`) |

A player who wants to hurt the group can burn at most 60 % of three contract values, slowly, while
watching it happen — and the group can still sell goods to recover. That is the ceiling, and it is low
enough that building a permission system on a mechanism the engine does not have would buy nothing.

## Rejected alternatives, and why

| Option | Why not |
|---|---|
| **Admin-only actions** | admin is not a role, it is a switch on the whole game. Asking a co-op partner to be admin to trade is absurd |
| **A manager appointed in the mod's GUI** | it would be a permission list the engine cannot enforce: the same player can still mine the container and walk away with the goods |
| **A confirmation dialog on acceptance** | friction on the normal path to slow down a rare abuser; the reserve is already displayed, which is the honest version of the same idea |

## The consequences that matter

- The mod's portal description says it in one line: **the pot is shared, and the counter is not a
  bank.** A player who wants a private purse should not install this mod.
- The escrow rate is not only an economic lever: **it is the security parameter** (20 % is what makes
  griefing unprofitable in effort and small in effect).
- Multiplayer servers that want a stricter model can restrict *who is on the server*. That is the real
  control, and it already exists.

## What this ADR deliberately does not build

No anti-cheat. A save can be edited with the Lua console or offline; a mod cannot prevent it, and any
attempt would be theatre that breaks legitimate players. In single player, cheating is the player's own
business; on a server, it is the owner's decision.
