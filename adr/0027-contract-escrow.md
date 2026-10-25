# 0027 — An expired contract costs credits: the amount is reserved when it is accepted

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 3
- **Depends on**: `0026` (the cooperative whose balance is reserved)

## Context

> « 1 avec pénalités en crédits, montant réservé. »

The first framing left expiry "dry" — a deadline with no consequence — and I flagged it as decoration.
The answer is a penalty, and the mechanism is an **escrow**: the sum is set aside when the contract is
accepted, not taken when it fails.

## Decision

1. **Accepting a contract reserves an amount in credits.** The reservation is a **hold** on the
   cooperative's balance: the credits are not spent, they are no longer available.
2. **On delivery before the deadline**, the hold is released and the payout is credited. Net effect on
   the cooperative: `+ payout`.
3. **On expiry**, the hold is **forfeited to the company** that offered the contract. Net effect:
   `− reserved`.
4. The reserved amount is **shown on the contract before acceptance**, in credits, next to the payout.
   A penalty the player discovers after the fact is not a penalty, it is a trap.
5. **The reservation is part of the acceptance, not an afterthought**: if the cooperative cannot cover
   it, the contract cannot be accepted (Q47 asks whether that is the rule).

## Why a hold rather than a debit

- A debit would mean paying to work: the cooperative would be out of pocket the whole time, and a
  contract honoured on time would look like a refund rather than a payment.
- A hold keeps the accounting honest in both directions and it is one field (`reserved`) on one record.
- It makes the cost of a bad decision **visible before** it happens: the contract list shows what is at
  stake, which is exactly what a player needs to choose between two offers.

## What it does to the loop

The loop becomes `commit → deliver → be paid` instead of `deliver → be paid`. Three effects, all wanted:

| Effect | Why it matters |
|---|---|
| Accepting is a decision | with three slots and a hold per contract, the player cannot accept everything just in case |
| A deadline that hurts | the 2-hour horizon now has a real clock: an ignored contract costs credits, not nothing |
| The company earns from failure | which makes its catalogue a **negotiation**: a company that offers a big payout for a tight deadline is asking for a real commitment, and it profits from the reckless |

The third point is the interesting one: the penalty is not a punishment invented by the mod, it is the
**counterparty's protection**, and it is paid to the counterparty.

## The two parameters that are still missing

- **Q46 — how much.** A percentage of the payout (the obvious candidate: the player risks a fraction of
  what he stands to gain), or a per-item amount in the price table? A percentage scales with the
  contract; a per-item value lets a cheap contract be punitive and an expensive one be free.
- **Q47 — coverage.** May a contract be accepted when the cooperative cannot cover the reservation? If
  no, a broke cooperative cannot work at all — which is a hard but honest state. If yes, the hold is
  partial and the penalty becomes symbolic.

## Acceptance

**A13** — an expired contract moves exactly the reserved amount from the cooperative to the offering
company, the hold is released on delivery, and the reserved amount is displayed before acceptance
(headless assertion plus a screenshot of the contract list).
