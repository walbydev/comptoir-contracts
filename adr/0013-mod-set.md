# 0013 — A set: one core mod plus optional extension mods

- **Status**: accepted by the requester's proposal (2026-10-25) — **naming, repository and publication
  details open (Q27–Q29)**
- **Date**: 2026-10-25
- **Block**: 3
- **Supersedes**: the "wave 2" phrasing of §3.2 (features are no longer deferred, they get their own mod)

## Context

The requester asked whether the whole thing could be organised as "a set of mods that add
functionality to a base concept". That question follows a real problem: twelve decisions deep, the
mechanism count had grown past what one release can carry and measure (§3.1). Cutting features into a
hypothetical "wave 2" postpones them; a mod set **delivers the core now and leaves the door open**,
which is the honest answer to the same problem.

## Verified platform facts (not assumptions)

- Dependency prefixes in `info.json`: **none** = required (loads before), `?` = optional, `(?)` =
  hidden optional, `!` = incompatible, `~` = no load-order effect. Source: Factorio wiki *Modding FAQ*.
- The control stage **cannot touch another mod** without a remote interface: `remote.add_interface`,
  `remote.call`, discovery through `remote.interfaces`. Source: wiki *Script interfaces*.
- A mod **cannot modify another mod's GUI** the way it would its own — there is no cross-mod widget
  ownership. The reliable patterns are: the add-on draws **its own** window, or the core **hands over**
  a container element (a `LuaGuiElement` survives a remote call) that the add-on fills.

## Options

| Option | Cost | Risk | What it forbids |
|---|---|---|---|
| A — One mod, features behind **startup settings** (`bool-setting`) | lowest: one listing, one test matrix | a setting is not a choice of *installation*; a risky feature still ships in the same binary; disabling it mid-save is a settings change, not an uninstall | independent release cycles |
| B — **Core + one add-on per feature family**, hard dependency of the add-ons on the core | N listings, N releases, an API to keep stable | the core turns into a platform for its own add-ons; four GUIs instead of one | a single zip |
| C — Forks/separable branches | low to start | divergent codebases, no shared ledger semantics | one shared economy |

## Decision

**Option B**, with four rules that make it survivable:

1. **The core never knows about its add-ons.** No `?` dependency in the core, no `mods["..."]` check,
   no `if bank then`. The dependency arrow points one way only: add-on → core, as a **hard** requirement
   (`"company-contracts >= 0.1.0"`). If the player removes the core, the game refuses to load the add-on:
   that is the correct, loud failure.
2. **Add-ons add behaviour, never prototypes.** No new item, entity, recipe or technology in an add-on,
   unless that content is designed to vanish cleanly. This is what makes an add-on **removable from a
   save**: removing a mod whose only trace is keys in `storage` is harmless; removing a mod that owned
   an entity or an item leaves orphans and an unloadable save.
3. **A versioned documented API**, exposed through `remote.add_interface("company-contracts", …)` with
   an `api_version` integer and named events for the mutations the add-ons need (a credit added, a
   contract dispatched, an account read). Add-ons never write the core's ledger directly — otherwise
   the conservation invariant (ADR 0011) is only a convention.
4. **The hub stays the single entry point.** An add-on that needs a screen opens it **from the hub
   GUI** through an element the core hands over, or from a hotkey if the coupling would be fragile.
   Two mods must never fight over the same widget.

## The set

| Mod | Contains | Why it is separate |
|---|---|---|
| **`company-contracts`** (core) | hub + space elevator, spaceport, cargo warehouses bound 1:1, contract generator (current tier + motivation), virtual credits + credit-item, two-way conversion with fixed fee + degressive rate, ledger with accounts, shop, curated technologies, tier model | the concept: deliver → get paid → convert → buy |
| `company-contracts-bank` | interest, AFK gating on production, deposit/withdraw screens | it is the only mechanism that creates credit volume (ADR 0007/0008) |
| `company-contracts-bounties` | nests, worms, science milestones, escalation on tier | a second faucet on the same treasury; a player may want contracts without bounties (ADR 0009) |
| `company-contracts-mint` | the printing right (ADR 0012) | the most dangerous switch of the design; it must be absent by default |

## Consequences

- **Requires**: the core's API and event names to be frozen before the first add-on exists, or the
  add-ons will be rewritten twice.
- **Requires**: a test matrix **per configuration** (core alone, core + each add-on) — not the full
  power set. Only pairs that the core's API makes interact are tested together.
- **Requires**: the conversion/ledger invariant to be testable **with and without** each add-on, since
  an add-on can break conservation without touching the core's code.
- **Forbids**: an add-on that patches a core prototype in `data-updates` to change core behaviour. That
  is not an add-on, that is a fork.
- **Makes harder**: player comprehension (four listings, one of which is required) and the release
  process (four versions to bump, four changelogs). This is accepted as the price of shipping a
  measurable core now.
- **Does not solve**: the balancing problem. Four mods do not make one economy easier to tune; they
  make it tunable in stages.

## Review

Reopen if: (a) the add-on API needs a breaking change twice within a minor cycle (then the split was in
the wrong place), (b) players install a subset that the core cannot explain, (c) an add-on cannot exist
without adding prototypes, which would invalidate rule 2 and force a different cut.
