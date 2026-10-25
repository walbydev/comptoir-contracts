# 0015 — The federation issues, the companies operate: one dial from poor to unlimited

- **State**: accepted
  transfer) still open
- **Date**: 2026-10-25
- **Block**: 3
- **Operationalises**: `0007`, `0009`, `0011`, `0012`, `0014`

## Context

Two answers, one turn apart:

> « 1c » — the federation issues and guarantees the unit; each company keeps its own books and can go
> dry; if it needs funds it borrows from the federation.

> « 2 peut être à sec ce qui permet d'effectuer un paramétrage de pauvre à riche ou illimité. »

So solvency is not a fixed rule: it is a **dial**. That is a better answer than mine, because the
same code serves a hard economy and a sandbox, and the balance lives in one number instead of in the
mechanism.

## Decision

1. **The colonial federation is the only issuer.** Its own account may go **negative**, and that
   negative balance *is* the credit supply in circulation. No other holder may go negative — a player
   or a company at zero is at zero.
2. **Companies are operators.** Each one pays contracts, bounties and interest out of its own balance
   **plus a credit line drawn on the federation**. A company at zero, with its line exhausted, stops
   offering new contracts. It does not disappear: it keeps its counter, its catalogue and its debts.
3. **The credit line is set by one dial**, chosen at world creation: `poor` (line = 0 — a company can
   only spend what it earns), `rich` (a large endowment) or `unlimited` (no bound). The three names
   map to numbers in the **data file**, not in code, so the balance is editable without a build.
   Default: **rich** — with `poor` as the default, the first contracts are unpayable and the mod does
   nothing on a fresh save (A1 fails for the wrong reason).
4. **The dial is a startup setting, not a runtime one.** A player who can flip to `unlimited` when
   the treasury is empty has no economy; a startup setting forces the choice once, at map creation,
   and then it is honest.
5. **Interest and bounties are no longer free money.** They are paid by a company, and a company that
   cannot pay draws on its line — so they become **debt**, not creation. This closes the funding
   question of `0007` and the revenue question of `0009`: the federation's revenue is the interest on
   the debts it holds, plus its commercial spread.
6. **The printing right (`0012`) collapses into the same mechanism.** Under reading C there is no
   separate machine: printing is **drawing on the federation's account**. Reading A (creation) is
   therefore confined to the issuer and bounded by the dial; reading B (materialising an existing
   balance) is just the ordinary conversion and is not printing at all. **Q25 is reformulated**: what
   does the research unlock — a one-off issuance, a recurring issuance bounded by the dial, or one
   step up on the dial?

## Consequences

| Document | What changes |
|---|---|
| `0011` | "one bank, several holders" → **one issuer, N books**. The ledger is no longer a single table. |
| `0007` (interest) | funded by the company's margin, then by its credit line. The remaining unknown is the **rate**, which belongs in the price table (Q18). |
| `0009` (bounties) | paid by a company out of its line: **bounties are issuance like everything else**, so the bound question (Q22, per unit or per milestone) becomes *more* important, not less. |
| `0012` (printing) | becomes "a licence to draw on the issuer", not a machine. Q25 rewritten. |
| `0014` | the solvency proposal it carried is replaced by the dial; the rest stands. |
| Indicators | **I1 and I2 hold in `poor` and `rich`, and are void in `unlimited`**, which is declared a sandbox mode with the conservation test disabled. A mode that voids an indicator must say so in the GUI, not in a wiki. |
| Tests | the conservation invariant is asserted in `poor` and `rich`; in `unlimited` the harness asserts only that nothing crashes. |

## What this does **not** settle

- **The size of the endowment** (`rich`) and the numeric shape of the line — a balance number, in the
  price table, to be tuned with I1/I2. Not a code decision.
- **Whether a company repays its debt**, and what happens to a company that is deeply in debt and
  never sells (`[À TRANCHER — Q33]`). Bankruptcy without consequence is a free loan.
- **Whether a rate exists on company debt** — if the line is free, `unlimited` is the only honest
  mode and `poor` is pointless.
