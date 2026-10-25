# 0005 — The mod works with and without the Space Age DLC

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 1
- **Supersedes**: —

## Context

D5 said "no hard Space Age dependency in the MVP". Investigation of the framing revealed that the
reuse list was inconsistent with it: `cargo-landing-pad` and `cargo-pod` are **Space Age
prototypes**, so a base-only MVP cannot reuse them, and a Space-Age-only MVP would exclude every
player without the DLC.

Philippe's decision on 2026-10-25: the mod must be **complementary, with or without Space Age**.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — Base only, own prototypes | medium: the spaceport and elevator are entities we build | art and behaviour must be convincing without SA assets | reusing SA visuals |
| B — Space Age required | low | excludes the base-only audience; the DLC becomes a prerequisite for a mod that adds no planet | players without the DLC |
| C — **Soft optional dependency, own prototypes, SA assets reused only when present** | medium: two configurations to test | divergence between configurations if the branches are not isolated | nothing |

## Decision

**Option C.** The hub is built from **prototypes owned by the mod**, so that its behaviour is
identical in both configurations. Space Age is declared as an **optional dependency**
(`"? space-age"` in `info.json`): when it is present, the mod may reuse SA entities and visuals
(landing pad, cargo pods) instead of its own placeholders; when absent, the mod's own prototypes are
used and nothing is missing.

One behaviour, two skins. A configuration is never a second code path for the rules.

## Consequences

- **Requires**: a single data-stage branch (`if mods["space-age"]`), the exact availability of that
  table in the control stage to be **verified in block 4** — do not assume it.
- **Requires**: the test matrix to run **twice** (base only, base + Space Age) from block 9 onward.
  A green base-only run proves half the promise.
- **Requires**: no recipe, technology or item of the mod may reference an SA prototype unconditionally
  — a base-only load must not fail on a missing prototype.
- **Forbids**: selling or unlocking an SA-only technology through the curated list (ADR 0002).
- **Makes harder**: art. Placeholders must look acceptable in base, and must not clash when SA
  entities appear next to them.

## Review

Reopen if: (a) maintaining two configurations doubles the test cost beyond what the audience
justifies, (b) Wube changes the dependency semantics in 2.2, (c) SA assets become impossible to reuse
because of licensing or prototype identity.
