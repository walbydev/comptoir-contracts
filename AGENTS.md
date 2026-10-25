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
make check     # L1 static gate: Lua syntax over every .lua file (luac -p) + locale keys
               # (tools/check_locale.py: a reference with no string, a string nobody prints, a
               # key name that is not [a-z0-9-]+)
make test      # headless Factorio scenario run (arrives with the first code)
make package   # build comptoir-contracts_<version>.zip — name format is mandatory
```

Verified environment facts (2026-10-25): Factorio headless 2.1.23 runs from
`/opt/data/.local/opt/factorio/bin/x64/factorio`. **`luac` 5.2.4 IS available**, symlinked at
`/opt/data/.local/bin/luac` to `/opt/data/.local/opt/lua-5.2.4/lua-5.2.4/src/luac` — moved out of the
profile cache on 2026-10-25 so a cache prune cannot break `make check`. A syntax error also surfaces as
a headless load failure; quote the command output, never the claim.

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
- **A locale key is `<section>.<key>`: the prefix belongs to the section, never to the key.**
  `[comptoir]` + `available=…` is read as `{"comptoir.available"}`; `comptoir-available=…` under
  `[comptoir]` becomes `comptoir.comptoir-available`, which nothing asks for, and the window fills with
  `Unknown key` (it did, lot (b)). References are **literals**: a caption built with
  `"comptoir.reason-" .. reason` is invisible to every check. `make check` refuses both shapes (ADR 0053).
- **`storage` carries a version number from the first release**, with a migration path. A published
  save is real user data.
- **No secret, no path, no host name in the repository.** It is public: `FACTORIO_API_KEY` lives
  outside, and no LAN address ever appears in a document or a commit.
- **The curated technology list is the guardrail, not a comment**: a technology is purchasable only
  if it is in `config/` and therefore reviewable in a diff.
- Balancing numbers (prices, quantities, timers) live in **one data file**, never inline in logic,
  so they can be tuned without touching code.

## Definition of done

Lua syntax check green **with the real command output quoted**; `make audit` clean (it is the gate —
a document that contradicts itself blocks the lot, not just the release); the card's acceptance criteria
each proven by a command output, a log line or a measurement; the framing updated through a new ADR when
a convention changes. "It works in my game" is not evidence.

## The one language exception

`docs/reader/` holds **reader digests written for the requester in his own language** (French), with
their rendered PDF. They summarise decisions taken elsewhere and are never a source of truth: the ADRs
and the master framing are. Everything else in this repository stays English.

## One writer at a time

**The framing owns `docs/`, `adr/`, `specs/` and this file.** A coding agent edits code, tests and
build files; when a document looks wrong it says so in its report. Measured 2026-10-25: an agent
corrected a real defect and, in the same commit, rewrote a criteria row, bumped a header counter and
authored an ADR. The content was right and was kept — the boundary is not about competence, it is
about who signs the definition. A rule that bends for a good edit is not a rule.

Measured the hard way on 2026-10-25: the framing committed with `git add -A` while a coding agent was
mid-task, and the commit swept the agent's half-finished `info.json`, `data.lua` and `control.lua` into
a commit titled `docs: …`. Nothing was lost, but the history now lies about what that commit contains.

Rules, therefore:

- **The framing commits explicit paths** (`git add docs adr specs README.md AGENTS.md`), never `-A`,
  whenever a coding agent may be working in the same tree.
- **A coding agent commits only what it touched**, and says so in its report.
- Before `git add`, look at `git status` and at the author of the last commit. If someone else's work
  is staged, unstage it rather than adopting it.

One writer, one commit, one message that matches the diff. A history that needs a footnote is a
history that will be misread.

## Branches

Lot (a) went straight to `main` because the repository had a single writer and no CI. **From
lot (b) on, code lands on `feature/<lot>` and is merged after review** — the framing reviews, the coding
agent does not merge its own work. History is never rewritten to move commits that already exist on
`main`: a straight-line history with an honest message beats a tidy one that was silently rearranged.
