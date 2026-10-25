# 0011 — One bank, several account holders: players, companies, the colonial federation

- **State**: superseded-by 0026
  **revised by `0014`** (one hub = one company, one treasury per holder); see Q30 for the issuer
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: clarifies `0007` and `0009` (it does not replace them)

## Context

The requester answered the treasury question on 2026-10-25:

> "Yes, one single bank for the players and the companies and the colonial federation which pays the
> bounties."

That settles the shape ADR 0009 was waiting for: there is not one treasury per channel, there is **one
institution with a ledger of accounts**. It also introduces the fiction that makes the money coherent:
the hub's commercial counterparty is not an abstract machine, it is a **colonial federation** with an
account, and that account is what pays bounties.

## Decision

1. **A single bank** holds every account: one account per player, one per company, one for the colonial
   federation, one for the bank itself (its own operating margin).
2. **Interest is paid from the bank's own account**, i.e. from what it actually earned on conversion
   spreads. If that account is empty, no interest is paid, and the bank **says so**.
3. **Contracts and bounties are paid by the federation's account**, not by the bank's. The federation is
   the commercial actor: it buys delivered goods and it sells materials and technologies.
4. **Credits are conserved** across every operation of the mod, with exactly one possible exception:
   whatever the printing right of ADR 0012 authorises, and only that.
5. **Every account is visible** in the bank GUI. A player must be able to see that the federation is
   short of funds *before* accepting a contract it cannot pay.

## Consequences

- **Requires**: a ledger keyed by account holder, integer only (ADR 0006), with a conservation test —
  the sum of all accounts plus credits in item form must not increase through any operation.
- **Requires**: the federation's account to be **funded by something**. That is **Q23** and it is the
  one real hole left in the economy: a federation that pays without revenue is a money printer with a
  nice name. The natural source is its own commercial margin — it buys delivered goods below the price
  at which it resells materials — but that must be stated as a decision, not assumed.
- **Forbids**: a player-side account that goes negative; a company account that exists without a defined
  owner; interest paid by the federation (two actors, two budgets).
- **Makes harder**: the block 3 numeric pass — every price now has two sides (what the federation pays,
  what it charges) and the difference is the federation's survival, which is also the interest fund's
  survival.

## Review

Reopen if: (a) the federation's account cannot be kept positive without breaking I1, in which case
bounties close and contracts are paid first-come-first-served, (b) the fiction of companies is never
used and should be removed rather than simulated.
