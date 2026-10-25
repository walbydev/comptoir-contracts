# 0014 — One hub is one company: several hubs, one currency

- **State**: accepted
  **can a company pay beyond its balance (Q31)** are open
- **Date**: 2026-10-25
- **Block**: 3
- **Revises**: `0011` (the "one bank for everybody" clause) and D16 ("one treasury")

## Context

The requester's voice note of 2026-10-25:

> « Chaque hub, qui est un ascenseur spatial lié à un spatioport, est une société qui propose des
> contrats, et qui est également une banque — qui fasse les deux choses en même temps. Le joueur a la
> possibilité de créer plusieurs hubs sur n'importe quelle planète, avec des limitations spatiales :
> on ne peut pas créer de hub côte à côte, il faut les espacer d'une grande distance. Le concept :
> un hub = un ascenseur spatial = un spatioport = une compagnie, qui propose des contrats basés sur
> les technologies actuelles ou juste les suivantes. Et le crédit est le seul élément unique commun à
> toutes les compagnies. »

This contradicts two recorded decisions, and the contradiction is deliberate on the requester's part:
ADR `0011` says **one bank** with the accounts of players, companies and the federation, and D16 says
**one treasury funds every payout**. A company per hub means several treasuries by construction. What
survives from `0011` is the part that matters for the economy: **the unit of account is unique**.

## Decision

1. **A hub is a company.** The player places a hub entity; that entity *is* a space elevator wired to
   a spaceport, run by a named company that (a) offers delivery contracts and (b) holds a bank counter.
   There is no separate "hub" and "company" object: one `unit_number`, one company record.
2. **Several hubs per surface, on any surface.** No single hub, no multi-force.
3. **The credit is the only thing common to every company.** No company scrip, no company-bound item,
   no company-locked price unit. Prices and contract terms **may** differ between companies; the unit
   may not. A credit-item bought at one hub spends at any other.
4. **The contract catalogue is per company.** The generator is seeded per company, so two hubs do not
   offer the same four contracts. D17 still governs the mix: a majority on technologies the player
   already has, a minority of "motivation" contracts pointing at the next tier.
5. **Accounts are keyed by holder *and* company.** A player's balance is held **at** a company, so
   "where is my money" becomes a real question — and moving it means either a conversion to items or a
   transfer between counters (transfer rule: `[À TRANCHER — Q32]`).

## Why this is better than one hub

| | One hub | One hub per company |
|---|---|---|
| Reason to explore | none: everything is at home | the best contract or the best price may be elsewhere |
| Contract variety | one catalogue for the whole game | N catalogues, each with its own bias |
| Money | a single faucet to audit | N faucets, but each is visible on its own counter |
| Failure mode | the hub is ignored (I3) | a poorly placed hub is a wasted investment — which is a *decision* |

It is also **cheaper to build than a central screen**: each hub is an entity, so its GUI opens by
clicking it. No hub selector, no "which company am I looking at" screen.

## The consequence nobody asked for, but that the design needs: solvency

If every company can pay contracts and take deposits, then every company is a potential money printer.
The only mechanism that bounds it without an arbitrary cap is **its own balance**:

- a company pays contracts and interest **out of its own account**;
- its account only grows when it **sells** something (materials, technologies);
- a company at zero **cannot** offer a new contract until it sells.

Under that rule, contract volume is bounded by real demand, and the spacing constraint becomes
secondary: the strong brake is solvency, not distance. This is a **proposal (Q31)** — the alternative
is unlimited issuance, which puts us back to an unauditable printer multiplied by the number of hubs.

## The issuer (Q30)

Three readings, mutually exclusive:

- **A — the colonial federation issues the unit**, and every hub is a *counter of the same bank*.
  Keeps `0011` intact, single ledger, conservation trivial. But then a company cannot go bankrupt, and
  "the hub is a company" is decorative.
- **B — every company issues its own credits.** Then the "common unit" is a pure convention with no
  guarantor, and there is no reason the sums should mean anything.
- **C (recommended) — the federation issues and guarantees the unit and pays the bounties; each hub is
  a company with its own books, which can go dry and can borrow from the federation.** One issuer, N
  operators, interest paid by borrowers, and the printing right (ADR `0012`) stays where it belongs:
  at the issuer, never at a counter.

## Consequences on the rest of the framing

- `0011`'s "one bank" clause is **revised**: one *unit* and one *issuer*, N books. The rest of `0011`
  (contracts and bounties paid by the federation, interest paid by the bank) survives under reading C.
- D16 ("one treasury") is **replaced** by: one treasury **per holder**, and the federation's treasury
  is the only one that can grow without selling — and only through the declared printing channel.
- §5 (data): the company record becomes a first-class object: `id`, `name`, `surface`, `position`,
  `treasury`, `catalogue_seed`, `state`.
- The conservation invariant becomes: `sum(company treasuries) + sum(player accounts) + credits held
  as items` is constant, except through the issuer.
- The bank add-on (`-bank`) becomes **per company**: interest competes between companies, which is a
  feature, and another reason it must be funded by each company's own margin.

## Rejected alternatives

- **One hub, one catalogue, forever** — no reason to explore, and the hub is one more menu (fails I3).
- **N hubs sharing a single treasury** — players would arbitrage two counters of the same purse; the
  "company" would be a skin.
- **Company scrip (a separate token per company)** — destroys the one property the requester asked
  for: credits as the common element.
- **A hard cap on the number of hubs** — arbitrary, and unnecessary once solvency is enforced.

## What must be proven in a spike (block 4)

The engine has **no native minimum distance between two entities**. Placement must be validated by
script: `on_pre_build` gives the position before the entity exists, and `on_built_entity` allows an
undo (destroy + refund the item + a message). `LuaSurface.find_entities_filtered{position, radius}`
does the distance check. A spike must decide which hook gives a clean refusal without a one-frame
flash or a duplicated item — and must do it on a surface where another hub already exists.
