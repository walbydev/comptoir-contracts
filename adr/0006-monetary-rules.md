# 0006 — Monetary rules: integer credits, fixed face value, tiered conversion cost

- **Status**: accepted — one clause proposed, awaiting Q16 (whether the improvement technologies are
  researched or bought)
- **Date**: 2026-10-25
- **Block**: 2
- **Supersedes**: —

## Context

ADR 0004 introduced a credit-item convertible both ways at the hub. The requester then fixed the
monetary rules on 2026-10-25:

> "In items, fixed values. Conversion price for each transaction fixed and variable depending on the
> converted amount. […] Conversion rules that can be improved with specific technologies which
> improve the rates and the fixed conversion fee. […] Something coherent and natural. No cents.
> Integer credits only."

These are four rules that constrain every later price decision, so they belong in one ADR rather
than scattered through the framing.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — Flat percentage on every conversion | lowest | no lever to discourage laundering; the fee is proportional, so small and large conversions behave identically | tiered pricing, a sense of banking |
| B — Flat fee per transaction | low | punishes small conversions only; a whale converts for free | proportional balance |
| C — **Fixed fee + rate depending on the amount, both improvable by technology** | medium: a versioned price table read by one function | three levers on the same variable (fee, rate, technology) → hard to balance and easy to break | — |
| D — Floating market rate driven by supply and demand | high: a price feed, a history, a lot more surface | players arbitrage the feed itself; unreadable without documentation (fails I4) | a fixed, explainable table |

## Decision

**Option C**, with these non-negotiable properties:

1. **Integer credits only.** No fractional credits anywhere: not in the ledger, not in a tooltip, not
   in a formula result. Any rate is expressed as a numerator/denominator pair of integers, and
   rounding is explicit and always in favour of the hub (documented in the GUI, not hidden).
2. **The item's face value is fixed.** One credit-item is worth a constant number of credits,
   decided in the price table, forever. A fixed face value is what makes the item a *store of value*
   and what makes gifting fair between two players.
3. **Conversion cost = fixed fee + amount-dependent rate.** The variable part is **degressive**
   (larger conversions cost proportionally less), which is the natural shape for a bank and the
   reason Q13 is settled.
4. **Two technologies, not more, may improve it** — one on the rate, one on the fixed fee. Both are
   ordinary research, **not hub purchases** (see Q16): a hub-bought improvement that lowers the cost
   of using the hub is a self-funding loop.
5. **The whole table is data, not code**: one versioned file, human-readable, reviewable in a diff.

## Consequences

- **Requires**: a price table with integer denominators, plus a test that asserts the invariants
  (rounding never creates credits, converting out and back never increases the balance).
- **Requires**: the GUI to state the fee *before* the player confirms — a conversion whose cost is
  only discovered afterwards is a trap and fails I4.
- **Forbids**: floating-point storage of money; any `/` or `*` on a credit amount without an explicit
  rounding rule.
- **Forbids**: a third improvement technology, or an improvement purchased with credits.
- **Makes harder**: balancing. Three levers interact: a degressive rate makes the fixed fee
  irrelevant for large amounts, and the technologies move both. The block 3 numeric pass must tune
  them **in this order**: face value → fixed fee → rate curve → technologies.

## Review

Reopen if: (a) the degressive curve creates an obvious lump-sum strategy that trivialises the fee
(I1 then fails on the conversion side), (b) rounding in favour of the hub is perceived as unfair in
play tests (I3/I4), (c) a second currency (another mod) requires a different arithmetic model.
