# 0022 — Companies have a character, and it must stay readable

- **State**: accepted
- **Date**: 2026-10-25
- **Extends**: `0014` (hub = company), `0019` (contract kinds), `0016` (three contracts)

## Context

> « J'aimerais que les compagnies aient du caractère mais restent lisibles. »

Two requirements that pull in opposite directions, and both are right. A company that behaves like
every other is a vending machine with a name. A company whose behaviour the player cannot predict is
noise. The answer is not a compromise between them; it is **one strong identity per company, stable
enough to be learned, and stated in one line**.

## Decision

### 1. Reading A: a company offers one contract kind at a time

Q41 was ambiguous. It is settled as **A**: the catalogue of a company is **homogeneous in kind**. A
company that currently offers `recurring_decaying` offers only that; a company that offers `one_off`
offers only that. Reading B (at most one of each kind among the three slots) is **rejected**: it gives
every company the same three shapes and therefore no character at all.

### 2. Character = two axes, both visible

A company's identity is the pair:

- **what it wants** — a domain of goods (raw, intermediates, fluids, science, military), and
- **how it pays** — its current contract kind.

So "Ferrum & Fils — intermediate goods, recurring at a fixed price" is a character the player can
state in one sentence, and it is enough to decide whether to walk to that hub.

### 3. Legibility is a rule, not an intention

Four constraints, each of which exists because its absence makes the feature hostile:

| Constraint | Why |
|---|---|
| The kind **cannot change more than once per tier** | a company that switches kind every time its catalogue regenerates cannot be learned |
| The identity is written **on the hub's tooltip and at the top of the contract list** | the player must not have to infer it from three contracts |
| A **colour and an icon** per company, reused everywhere it appears | recognition beats reading |
| At most **three contracts**, so the identity is one line plus three rows | the catalogue stays scannable at a glance |

### 4. Consequences

- **A12 restated**: the contract list of a company contains the **single kind of that company**; the
  kind is displayed; and across two companies on the same surface the kinds **differ** (this is what
  A9's "different contract sets" now means, concretely).
- **The generator** (ADR `0009`) gains a per-company seed that fixes the domain and the kind. The
  degenerate case — every company on a map drawing the same pair — must be excluded by the seed:
  A9 already requires two hubs to differ, and a difference in kind is the cheapest one to see.
- **The price table is untouched** (D30): character is expressed by *what* is offered and *how* it is
  paid, never by a second price table.

## What this gives up

A player can no longer shop for "the same item, better paid, two hubs away" — that was reading B's
appeal, and `0014`'s "go elsewhere for a better price" loses its price dimension. What remains is
"go elsewhere for something else", which is weaker commercially and stronger narratively. That is the
trade the requester just chose by asking for character, and it is recorded here so it is not
rediscovered later as a defect.
