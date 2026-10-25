# 0002 — Purchasable technologies: a curated list, never the full tree

- **State**: parked
- **Date**: 2026-10-25
- **Block**: 1
- **Supersedes**: —

## Context

Credits must be able to buy technologies "without research" — that is the wording of the original
request. The question is **which ones**: the whole technology tree, or a chosen list.

Philippe's decision on 2026-10-25: **curated list (2a)**.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — **Curated list**: non-critical technologies, never the hub's own unlock, never the critical path | low: a hand-maintained, versioned list of names | the list drifts when another mod adds technologies (handle by filtering, not by exhaustive enumeration) | buying the technology that advances the game |
| B — The whole technology tree | technically low (walk `prototypes.technology`) | research becomes bypassable: a rich player skips progression — exactly the shortcut Philippe wants to avoid | balance (I1, I2) and the mod's credibility |
| C — No technologies at all, credits limited to materials | very low | half of the original request disappears | buying technologies |

## Decision

**Option A.** A is chosen because the "something balanced" requirement and the ability to buy
technologies are only compatible if **the purchasable perimeter is closed**. A full tree turns the
hub into paid cheating; a curated list turns it into an opportunity tool.

Curation rules, to be written into the framing and then into code:

1. **Never** the technology that unlocks the hub itself (otherwise the hub self-funds).
2. **Never** a technology on the critical progression path (rocket, main sciences).
3. Only **peripheral** technologies: logistics comfort, modules, defensive weaponry, side
   optimisations — to be arbitrated in block 3.
4. The list is **kept in git**, not computed by exclusion: a new technology enters the catalogue only
   through a decision.

## Consequences

- **Requires**: a versioned list, and a test that fails if a listed technology name no longer exists
  in the game (otherwise a silent compatibility break).
- **Requires**: a price that makes buying a technology possible but never more profitable than
  researching it within the target play time.
- **Forbids**: selling a main-tree technology, even at a high price — the price is not the guardrail,
  the list is.
- **Makes harder**: maintenance across Factorio versions and mods that add technologies (the list
  must not become a compatibility debt).

## Review

Reopen if: (a) the curated list proves too thin for buying technologies to serve any purpose (I3),
(b) a major third-party mod imposes its own technology economy, (c) Philippe explicitly decides for
wider access in late game.
