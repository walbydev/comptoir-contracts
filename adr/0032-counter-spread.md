# 0032 — The counter buys at cost and sells at cost × 1.5

- **State**: accepted
  numbers)
- **Date**: 2026-10-25
- **Block**: 5
- **Fills**: `0028` D48 ("the shop always buys") with the price it buys at

## Context

`0028` established that the counter must **always buy**, because that is the only way out of a
cooperative at zero. It never said at what price. The price band (D46) only says:

```
raw cost  <  contract payout  <  shop selling price
100       <  115              <  150
```

The buying side was a hole, and it is a **money printer** if it is left as "the counter buys your
goods":

- if it buys at the selling price, buy → sell → buy is an infinite loop;
- the loop needs no exploit, no bug and no cleverness: it is a two-click action that a player finds
  within the first hour, and it destroys the economy of the mod permanently.

## Decision

| Operation | Price | Effect on the cooperative |
|---|---|---|
| **Contract delivered** | `payout = quantity × payout(item)`, ≈ cost × 1.15 | money **enters** the cooperative |
| **Counter sells** a stack | `price(item)` = cost × 1.5 | money **leaves** the cooperative |
| **Counter buys** a stack | `cost(item)` = price ÷ 1.5 | money **enters** the cooperative, at the worst rate in the game |

The 50 % spread is the counter's margin, and it is the price of the safety valve. Selling goods back
is always available, never attractive, and always lossy: **the player who has to sell back is being
rescued, not rewarded.**

## Consequences

- The three ways to gain credits are now ordered and non-overlapping: honour a contract (+15 % over
  raw), sell to the counter (0 % over raw, and it costs the production), and nothing else. No
  arbitrage exists because no pair of operations is profitable in both directions.
- The counter's margin is also the reason it can be a *company* with its own books: it earns, it does
  not lend.
- A test must assert it: buying then immediately reselling must always **lose** credits. That is a
  one-line invariant, and it belongs in `docs/tests.md`.
