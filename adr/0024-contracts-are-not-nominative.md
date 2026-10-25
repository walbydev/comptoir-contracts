# 0024 — A contract belongs to the company, never to a player

- **Status**: accepted 2026-10-25 — **supersedes the per-player account model of §2**
- **Date**: 2026-10-25
- **Block**: 3
- **Extends**: `0014` (hub = company), `0016` (three contracts), `0023` (no physical currency)

## Context

> « J'aimerais bien que pour la première version du mod, que chaque hub avec la compagnie associée
> soit disponible pour tous les joueurs. Ce n'est pas nominatif aux joueurs. »

The catalogue is not personal. A contract is an offer made by a **company** to whoever walks into its
hub.

## Decision

1. A contract belongs to the **company**. It is never assigned to, reserved by, or duplicated for a
   player.
2. **Any player may feed the hub and dispatch.** The payment goes to the **company's** balance.
3. The cap of one to three active contracts (D32) is per **company**, not per player.
4. In multiplayer the catalogue is **shared and single**: four players at one hub see the same three
   contracts, not twelve.

## Why this is the right model and not just the simple one

- **The alternative does not survive contact with reality.** Per-player contracts mean a payment split
  between everyone who contributed goods, which requires measuring who put what in the hub. Factorio
  cannot attribute the contents of a chest to a contributor — the inventory is an aggregate. Any split
  rule would be a fabrication, and the players would learn to game it within an hour.
- **It makes multiplayer cooperation real.** One player mines, another hauls, a third buys at the shop;
  the company is paid once and all three act on the same purse. Parallel per-player worlds — the
  default of most mods — are the boring outcome.
- **It removes a whole state machine**: no per-player contract record, no reassignment when a player
  leaves, no orphaned contract when a player is deleted from the save.
- **It matches `0014`**: the hub is the company, the company owns the catalogue, and the catalogue is
  on the map, visible to everyone. Ownership by a player would have contradicted the founding image.

## What it breaks, and it must be said

- **§2 said the opposite**: « each player has their own ledger and bank; credits are per player, not
  shared ». That row is superseded. Money is now attached to a company, and §2's per-player ledger
  disappears with `0023`'s item.
- **D12 (gifting only via credit-items) is dead twice**: there is no item (`0023`), and there is no
  player purse to gift from.
- **A player who owns no hub owns nothing.** In multiplayer, a player with no company cannot buy at a
  shop and cannot be paid. This is coherent ("the company is the economic actor") but it changes the
  opening of a multiplayer game: the first hub is a shared project, not a personal purchase.

## The question this opens

If the company holds the money and nobody else does, then a player's relationship to a balance is
undefined: **he directs a company, he does not possess credits.** That is Q45, and it decides whether
the bank add-on and the activity rule of `0008` still have a subject.
