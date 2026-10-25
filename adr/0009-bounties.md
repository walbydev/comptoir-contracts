# 0009 — Bounties: nests, worms and science packs pay escalating bonuses

- **Status**: accepted — **the funding source and the science-pack unit are open (Q20, Q22)**
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: —

## Context

The requester added a second reward channel on 2026-10-25:

> "Some actions like destroying nests and worms offer escalating bonuses. Same for creating science
> packs. A passive player earns nothing."

This is a *bounty board*: the player is paid for doing things the game already rewards, but which the
hub can also encourage. It is legitimate — it gives active play a second reason to interact with the
hub — but it opens a third and fourth money faucet on top of contracts and interest.

## The risk: an unbounded faucet

If a bounty **creates** credits instead of moving them, then the optimal strategy is no longer
"produce and deliver" but "farm the bounty": destroy nests in a loop, or build the largest possible
science-pack factory and let it run. "Escalating" makes it worse — the more the player advances, the
more each unit pays, so the faucet grows with the player's ability to exploit it. That ends with the
hub being irrelevant and I1 dead.

Escalation must therefore hang on a **bounded** variable. Evolution factor is *not* bounded in spirit:
it rises with time and with nest destruction, which is precisely the farming loop. Progression tier
is bounded and one-way.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — Credits created from nothing, escalating with evolution factor | lowest | the farming loop above; I1 fails | any economic coherence |
| B — **Payouts drawn from the hub's treasury** (the same pool that funds contracts) | medium: a treasury account, and a visible "the hub is dry" state | a drained hub stops paying contracts — which is the honest behaviour, but must be explained | infinite bounties |
| C — Bounties paid in **items or technologies**, never credits | medium | no money creation at all, but "bonus" is then less legible | credit bounties |
| D — Credits created but capped per tier | low | the cap becomes a target the player optimises around; still inflation | nothing, but it breaks I1 softly |

## Decision

**Bounties exist for nests, worms and science packs, and they escalate.** Option **B** is the intended
funding rule: every credit the hub hands out — contract payout, bounty, interest — comes out of **one
treasury**, so the hub can never pay more than it has taken in. That single rule is what keeps I1
true without a spreadsheet of exceptions.

**Escalation variable: progression tier, not evolution factor** (proposal, to confirm). Tier is bounded
and monotone; evolution is exactly what a farmer raises.

**Two prerequisites remain open:**

- **Q20** — is the treasury rule accepted? If not, this ADR degrades to option D and I1 must be
  re-argued rather than assumed.
- **Q22** — science packs: paid **per unit** (a faucet proportional to factory size — in a 100 h game
  this is unbounded) or **per milestone** (first *N* packs of each new tier, then the channel closes
  for that tier — bounded, and it pushes toward *new* science rather than *more* science).

Until Q20 is settled, no bounty code is written: the payout function depends entirely on where the
money comes from.

## Consequences

- **Requires**: a treasury in `storage`, its income and its expenditure, and a **visible** drained
  state (a hub that cannot pay must say so, not silently pay zero).
- **Requires**: bounties to be announced by the hub (the player must know before acting, or the reward
  is a lottery).
- **Forbids**: an escalating variable tied to evolution factor, pollution, or time.
- **Forbids**: an unbounded per-unit science-pack payout.
- **Makes harder**: balancing. With a treasury, contracts, bounties and interest compete for the same
  pool; the block 3 numeric pass must decide the split explicitly (proposal: contracts ≥ 50 % of the
  pool, bounties ≤ 30 %, interest ≤ 20 %).

## Review

Reopen if: (a) the treasury proves too abstract and players cannot understand why the hub is dry,
(b) play tests show bounties dominate the loop (the hub becomes a bounty terminal, not a market),
(c) per-unit science payouts are kept, in which case I1 must be re-measured explicitly.
