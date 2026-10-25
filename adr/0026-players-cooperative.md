# 0026 — The players form a cooperative: one shared account, separate company accounts

- **Status**: accepted 2026-10-25 — **settles Q45**, replaces the "company purse only" model of `0024`
- **Date**: 2026-10-25
- **Block**: 3
- **Amends**: `0024` (non-nominative contracts), `0023` (no physical currency)

## Context

Q45 asked who holds the money, and offered two branches: the company alone, or a wallet per player. The
answer is neither:

> « Non, l'argent appartient à un pot commun de tous les joueurs. Chaque compagnie a son propre compte.
> Les joueurs sont une coopérative indépendante. »

Three holders, then, and the third is the one nobody had named:

| Holder | Count | Owned by | Purpose |
|---|---|---|---|
| **The cooperative** | one | **all players together** | the players' common purse: it receives contract payouts and it pays the shop |
| **Companies** | one per hub | the company (not the players) | they pay contracts and they sell materials |
| **The federation** | one | the issuer | it endows companies; its negative balance, if any, is the money supply |

## Decision

1. **One cooperative account per save**, shared by every player, with no per-player balance anywhere.
   It is not nominative: the ledger does not know who contributed what, and it never will — the
   inventory of a chest cannot be attributed to a contributor, and neither can a deposit.
2. **One account per company.** A company's money is not the players' money: buying at a hub's shop
   moves credits from the cooperative to that company, and honouring a contract moves them back.
3. **No player wallet, still.** `0023` removed the item and `0024` removed the per-player ledger; this
   ADR does not reintroduce either. A player's economic identity is "member of the cooperative".
4. The cooperative is a **normal account**: integer balance, no interest, no credit line, no overdraft.
   The bank remains parked (`0025`) — a shared purse is not a bank.

## Why this is better than what I proposed

I had written that a player with no hub owns nothing, and that in multiplayer the first hub would have
to be a shared project for that reason. The cooperative fixes it more cleanly:

- **A new player is not destitute.** He arrives with access to the shared purse, immediately able to
  buy at a shop and to help honour a contract. Onboarding becomes one sentence: "the pot is ours".
- **Cooperation becomes the default, not a negotiation.** Two players producing for the same contract
  are paid once, into the same pot, and nobody has to split anything — which was the unsolvable
  measurement of `0024`.
- **The tension is now between the players and the companies**, which is the right tension: the
  cooperative wants to be paid well, the companies want to sell dear, and both sides are on the map.
- It keeps the founding image intact: **the hub is a company, the players are their own firm.**

## The risk this introduces, stated plainly

**A shared purse can be emptied by one player.** Anybody can accept a contract and let it expire, and
the penalty (`0027`) comes out of the pot everybody shares. Factorio gives no per-player permissions
worth relying on.

This is accepted rather than mitigated: the mod is played by people who chose to cooperate, and a
cooperative is by definition a trust model. What must not happen is that the player discovers it after
the fact — so the reservation of `0027` is **shown on the contract before acceptance**, and the hub
says whose money it is. A shared pot that is invisible would be a trap; a shared pot that is written
on the screen is a rule of the game.

## Consequences

- **`A3` restated**: the sum of company balances + the cooperative + the federation is unchanged,
  except the initial endowment.
- **The end of "a player without a hub owns nothing"** (`0024`): the cooperative is the player-side
  purse, and a hub is not a requirement to participate.
- **`0011`'s four account holders** are now three kinds: cooperative, companies, federation — and the
  bank, if it ever returns, would hold the cooperative's account, not the players'.
