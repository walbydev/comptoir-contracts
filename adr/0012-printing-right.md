# 0012 — Printing credits is a right obtained by research

- **Status**: **blocked** — two readings are incompatible and the choice is Q25
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: —

## Context

Answering the science-pack bounty question, the requester wrote:

> "Printing credits is a right obtained from a technology research."

This is either a small, coherent gate or the end of the economy, depending on one word. The two
readings cannot both be implemented, and this ADR refuses to pick one silently.

## The two readings

| | Reading A — **creation** | Reading B — **materialisation** |
|---|---|---|
| What the technology unlocks | the ability to **create new credits** | the ability to **turn an existing balance into credit-items** (and back) |
| Effect on the money supply | increases it | unchanged — value is conserved |
| Cost of the operation | decides everything: below the printed value it is an infinite loop, above it nobody uses it | a fee, integer, in favour of the bank (ADR 0006) |
| Coherence with D1-bis, D8, D11 | breaks all three | fits all three |
| Effect on I1 | the hub becomes optional once the technology is in | none |

## Why reading A is refused unless explicitly chosen

A recipe that prints credits is an arbitrage machine. If printing *n* credits costs less than *n*, the
player prints forever and every other mechanic — contracts, bounties, production — is decoration. If it
costs more, nobody prints and the technology is dead weight. The only way out is a cap (per minute, per
tier), and a cap is a target: the player will saturate it, which is another name for a fixed income.
That is the exact failure mode ADR 0008 was written to close.

**Reading A is therefore possible, but it must be chosen knowingly, with its cap, and I1 must be
re-argued rather than assumed.**

## Recommended reading: B

The technology unlocks the **credit-item form** — converting virtual credits into bearer items and back
— not new value. Everything already decided then lines up: the item has a fixed face value (D8), the
conversion has a fee (D9), value is conserved across the bank (0011), and gifting stays a transfer.

Bonus property: it gives the item a **progression gate**. Early game the player deals in virtual credits
only; the research opens the physical form, hence banks-in-item, gifting, and carrying value between
sessions. That is a motivation technology in the exact spirit of D17.

## Consequences (identical under both readings)

- **Requires**: a technology flag checked at every conversion entry point, and a GUI state for
  "conversion locked — research *X*".
- **Requires**: a conservation test regardless of the reading: sum of accounts + credits held in items
  must not increase, unless reading A is chosen and then only through the printing operation itself.
- **Forbids**: printing without a research; printing that ignores the bank's ledger.

## Review

Reopen when Q25 is answered. If reading A: this ADR is rewritten as a new one describing the cap, the
cost and the I1 re-argument. If reading B: the status becomes *accepted*, and the technology enters the
curated catalogue (ADR 0002) with its price in block 3.
