# 0018 — Bankruptcy is terminal: the contracts go, the hub is resold

- **Status**: accepted 2026-10-25 — **the resale terms are open (Q34)**
- **Date**: 2026-10-25
- **Block**: 3
- **Operationalises**: `0015` (dial and credit line), `0014` (company)

## Context

> « Une compagnie criblée de dettes perd tous les contrats et n'en émet plus. Le hub doit être
> revendu à une autre compagnie. »

This answers the third question of the previous turn — what happens to a company that is deeply in
debt and never sells — and it answers it the hard way, which is the only way that makes the `poor`
mode mean something.

## Decision

1. **A company in default loses every contract and issues none.** Its counter closes. It does not
   recover on its own: no repayment schedule, no grace period, no interest freeze.
2. **The hub stays standing and becomes available for resale to another company.** The building is
   not destroyed; the operator is.
3. **The debt stays with the dead company**, which can no longer earn. The loss therefore lands on
   the federation — the issuer — and that is exactly why the issuance dial exists (`0015`).
4. A resold hub is operated by a **different company**: the player keeps the building and loses the
   relationship. Whether the buyer inherits the old catalogue seed or gets a fresh identity is part
   of Q34; a fresh identity is the more interesting answer, because a hub that went bankrupt should
   not come back identical.

## Why this is coherent rather than punitive

- It gives the `poor` mode teeth: a badly run company is a **loss**, not a soft reset.
- It makes the credit line a real decision: drawing on it is borrowing against future sales, and the
  player who draws without selling loses the counter.
- It removes a whole mechanic from the scope: no repayment schedule, no debt amortisation, no
  interest-on-debt simulation. Bankruptcy is a state change, not a ledger to balance.
- It keeps the federation's negative balance meaningful: **every default is a hole in the issuer's
  books**, and the sum of the holes is bounded by the dial.

## Consequences on the rest of the framing

| Document | What changes |
|---|---|
| `0015` | the "what if it never repays" question (Q33) is answered: it dies. The dial is the only bound, and it must be chosen with that in mind. |
| `0014` | the company record gains a terminal state (`defaulted`) and keeps its identity for the record, without a counter. |
| §3 acceptance | a new criterion: a company driven to default **loses its contracts, issues none, and is resale-able** — asserted headless. |
| GUI | the dead hub must **say** it is dead and how to revive it (resale), otherwise the player is left with an inert building and no explanation (fails I4). |

## Open (Q34)

- **Who buys?** The federation as broker, a pool of neutral companies, or the player paying to
  re-open under another name?
- **At what price?** A fraction of the build cost, a fixed fee, or a function of the debt?
- **What happens to the stock** inside the hub at the moment of default?
- Does the buyer start with a **fresh catalogue and a fresh line**, or inherit anything?
