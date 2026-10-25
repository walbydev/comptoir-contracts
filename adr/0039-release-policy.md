# 0039 — Release and support policy: 0.x, public issues, immutable releases

- **State**: accepted
- **Date**: 2026-10-25
- **Block**: 7
- **Closes**: Q09 (publication procedure, verified from the official wiki, not assumed)

## The four decisions

| # | Decision | Why |
|---|---|---|
| 1 | **0.x until proven**: `1.0.0` only after non-author players have run it and it has survived a game version bump | a mod that calls itself 1.0 is promising that saves will keep working. That promise is only credible after other people have tried it |
| 2 | **Public GitHub Issues**, linked from the portal page, with a four-field template | the alternative — silence — means bugs are reported in portal comments where they cannot be tracked, closed, or searched |
| 3 | **A release is immutable**: never deleted, never overwritten; fixes are new versions | a save that installed `0.1.0` must still be able to fetch `0.1.0` in two years |
| 4 | **Local testing is the default path**, and the headless box is a filter, not the last word | see below |

## Why the local-testing decision is written down

The question was "can I test on my computer before publishing anything?", and the answer is yes: the
portal distributes, it does not gate. But the shape of the answer matters:

- the mod is developed in a **separate mod directory** (`--mod-directory`), never in the real one,
  because a half-finished mod enabled in a main save leaves that save with missing entities when it is
  removed;
- **two directories**: one without Space Age, one with — D5 asks for both configurations and this is the
  only way to actually exercise them;
- **headless here** proves the prototypes load and `control.lua` runs (`--create`, `--start-server`);
- **the window can only be judged by eye**, so the GUI-scale criterion (A20) is manual and happens on
  the player's machine.

The last line is the honest limit of this setup: everything except the visual result is verifiable
before publication, and the visual result never is.

## What publication requires — verified 2026-10-25

- factorio.com account with a **verified purchase**;
- API key with the **`ModPortal: Publish Mods`** scope;
- archive `comptoir-contracts_<version>.zip` containing the folder `comptoir-contracts_<version>/`;
- release visible in game **in about 5 minutes**.

The key never enters the repository or `.git/config`; `make package` builds offline and `make publish`
takes the key from the environment.
