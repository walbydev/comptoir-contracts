# AGENTS.md — working instructions for coding agents

`comptoir-contracts` is a Factorio 2.1 mod (Lua 5.2) adding company contracts through a commercial
hub. It is a **game mod, not a service**: nothing runs in production, nothing is supervised. Read
`docs/00-cadrage.md` before any change; the framing is the contract.

## Language

Every artefact in this repository is **English**: documentation, ADRs, code, identifiers, comments,
locale keys, commit messages. Only `docs/entrants/` may contain other languages — those files are
frozen inputs and are never edited.

## Commands

```bash
make check     # Lua syntax check over every .lua file (luac -p)
make test      # headless Factorio scenario run (arrives with the first code)
make package   # build comptoir-contracts_<version>.zip — name format is mandatory
```

Verified environment facts (2026-10-25): Factorio headless 2.1.23 runs from
`/opt/data/.local/opt/factorio/bin/x64/factorio`. **`luac` is not installed** on this machine — a
depth-6 search of `/` found no binary, despite the handoff brief claiming 5.2.4 was compiled
locally. So `make check` works only after Lua 5.2 is built, and until then a syntax error surfaces
as a headless load failure. Do not claim a syntax check passed without quoting the command.

## Rules that are not negotiable

- **Never edit `docs/00-cadrage.md` decisions in place.** A changed decision becomes a new ADR that
  supersedes the previous one. ADRs are append-only history.
- **No dependency on Space Age** in the MVP unless an ADR says otherwise (D5). Space Age may be an
  optional dependency, tested, never a hard requirement.
- **Never overwrite an existing prototype.** Reuse `rocket-silo`, `cargo-landing-pad`, `cargo-pod`;
  create new prototypes when behaviour differs.
- **`storage`, never `global`** — `global` no longer exists since Factorio 2.0.
- **`helpers.write_file`, never `game.write_file`** — the second was removed in 2.1.23 (measured
  2026-10-25: `LuaGameScript doesn't contain key write_file`). The test harness depends on it.
- **`recipe.categories`**, not `recipe.category`, in 2.1.
- **`storage` carries a version number from the first release**, with a migration path. A published
  save is real user data.
- **No secret, no path, no host name in the repository.** It is public: `FACTORIO_API_KEY` lives
  outside, and no LAN address ever appears in a document or a commit.
- **The curated technology list is the guardrail, not a comment**: a technology is purchasable only
  if it is in `config/` and therefore reviewable in a diff.
- Balancing numbers (prices, quantities, timers) live in **one data file**, never inline in logic,
  so they can be tuned without touching code.

## Definition of done

Lua syntax check green **with the real command output quoted**; the card's acceptance criteria each
proven by a command output, a log line or a measurement; the framing updated through a new ADR when a
convention changes. "It works in my game" is not evidence.
