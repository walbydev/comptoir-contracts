# 0017 — The printing research raises the dial one step

- **Status**: accepted 2026-10-25 — **completes `0012`** (Q25 = reading c)
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: nothing — it turns `0012` from a blocked question into a mechanism

## Context

`0012` recorded "printing credits is a right obtained by research" and refused to guess between two
incompatible readings. `0015` then collapsed the question: since the colonial federation is the only
issuer, printing is not a machine, it is a **licence to draw on the issuer**.

The requester's answer to the reformulated question:

> « 1c »

Which is: the research moves **one step up the dial** (`poor` → `rich` → `unlimited`).

## Decision

1. The research grants a **single step** on the D29 dial, and it applies to the **company that holds
   it**, not globally: the other companies keep their line. The dial is therefore read as "the
   company's line position", initialised at world creation and movable only by research.
2. One research, one step. Two steps require two researches; the second is not in the MVP.
3. The step is **permanent** and it is recorded in the company record (`state`, `line_level`), so it
   is auditable and it survives a save.

## Why this is the right of the three options

| Option | Verdict |
|---|---|
| (a) a one-off issuance | invisible in play: one number appears once, and nothing explains it later |
| (b) a recurring issuance bounded by the dial | a printer with a nice name: the bound has to be re-chosen, and the player will saturate it |
| **(c) one step up the dial** | **chosen**: one number moves by one notch, the effect is legible, and the whole mechanism is already modelled by D29 |

## The hole this opens, and it must be closed

If a step can reach `unlimited`, then a game started in `rich` can **end** in a mode where I1 and I2
are declared void — the sandbox becomes reachable by research, which is precisely the arbitrage the
whole framing refuses. Two answers, and one must be chosen (**Q37**):

- **stop at `rich`**: the research tops out at the last bounded mode, `unlimited` stays a choice made
  at world creation;
- **allow `unlimited`**: accepted as an endgame the player pays for with a technology — and then I1/I2
  must be declared void from the moment the step is taken, not from map creation.

The first is the conservative one and the one a player cannot abuse; the second is a design statement
("the endgame is abundance") that has to be made deliberately.
