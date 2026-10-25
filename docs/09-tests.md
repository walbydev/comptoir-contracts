# 09 — Quality: how each criterion is proven

- **Status**: specified 2026-10-25 — harness decided (ADR 0042)
- **Scope**: 28 acceptance criteria in `docs/00-cadrage.md` §1.3. This document says, for each one,
  **what proof is accepted** and **who produces it**. A criterion without a row here is not accepted.

## 1. Three layers, and why three

| Layer | Runs where | Proves | Costs |
|---|---|---|---|
| **L1 — static** | this box, Python, no game launch | the data is right: price table reproducible, no oil in the counter's recipe, locale keys complete, archive clean, no secret | seconds |
| **L2 — headless behaviour** | this box, `factorio --start-server` + a test mod | the rules hold: ledger, escrow, expiry, coverage, spread, per-force isolation, save round trip | a minute per scenario |
| **L3 — by eye** | the requester's machine | the interface is readable and nothing overflows | a minute, once per UI change |

The split exists because a claim like "the window is fine" cannot be automated, and pretending otherwise
would put a green tick on something nobody looked at. L3 is short **on purpose**: four criteria, not
forty.

## 2. The harness — a separate test mod

`test-mod/` is a **second mod**, `comptoir-test`, which depends on `comptoir-contracts`.

- It is **never packaged**: `make package` copies an explicit file list, and the test mod is not on it.
  A28-style omissions are caught by the L1 archive scan, including the test mod's name.
- It holds every in-game assertion, so the shipped mod contains **no test code** — no assertions, no dead
  branches, no hidden setting. **Nuance added 2026-10-25 (D74)**: a separate mod cannot read another
  mod's `storage`, so the shipped mod *does* expose one small remote interface (`snapshot`, `act`,
  `api_version`). That is an API, not a test, and `comptoir-freight` will need it anyway; it grants
  nothing the console does not already grant.
- It exposes one remote interface and writes its verdicts with
  **`helpers.write_file("test-results.json", ...)`**, which the runner reads back. **`game.write_file`
  does not exist in 2.1.23** — measured 2026-10-25 the hard way, in `spike/fedora-smoke/`. The game is
  not asked to report through stdout: the log is for humans.

```
make test        # L2 in both DLC configurations, exit code = verdict
make check       # L1: static checks + syntax, no game launch
make accept      # L1 + L2 + prints the L3 checklist and refuses to be green without it
```

**`make accept` never claims the manual part.** It prints the four L3 rows as `UNVERIFIED` and exits
non-zero until the requester records his check in `docs/tests.md` §5 for that release. A suite that
reports green while four criteria were never looked at is the exact failure this document exists to
prevent.

## 3. The matrix — every criterion, its proof, its owner

| ID | Criterion (short) | Proof | Layer | Owner |
|---|---|---|---|---|
| A1 | first contract end to end under 30 min | scripted run: place counter, accept, fill, dispatch, assert payout and elapsed ticks | L2 | cadrage |
| A2 | insertion by inserter **and** robot; dispatch only on request | test mod inserts with both, then asserts the contract is not auto-completed | L2 | cadrage |
| A3 | conservation of the money | sum before/after each of 9 operations, assert equality | L2 | cadrage |
| A5 | loads and runs in both DLC configurations | `make test` runs twice, different `--mod-directory` | L2 | cadrage |
| A6 | no Lua error; no desync in two-player headless | errors: L2. **Desync: not automatable here** — a real two-client session is a manual check before a release | L2 + manual | cadrage |
| A7 | a generated contract is always completable with unlocked technology | generator run 1 000×, assert every item's technology is researched | L2 | cadrage |
| A9 | two hubs below the minimum distance are refused, with refund | place two, assert refusal and the refunded amount | L2 | cadrage |
| A10 | conservation asserted in `poor` and `rich`; `unlimited` says so | three map-creation passes | L2 | cadrage |
| A13 | expiry moves exactly the reserved amount | accept, let the deadline pass, assert two balances | L2 | cadrage |
| A14 | from zero, selling goods restores the ability to accept | drive the pot to 0, sell, accept | L2 | cadrage |
| A15 | buy then resell always loses | every catalogue row: buy 1 at price, sell 1 at cost, assert negative delta | L2 | cadrage |
| A16 | no oil in the counter's recipe | `tools/cost_table.py` walks the recipe tree; `make check` fails if any ingredient has a fluid ancestor | **L1** | cadrage |
| A17 | tier-1 catalogue buildable with red/green research and no fluid | same tool: tier field + fluid flag on the 9 tier-1 items | **L1** | cadrage |
| A18 | never a contract with a locked recipe | 1 000 generations × unlocked-set = ∅ | L2 | cadrage |
| A19 | `available + reserved = total` | asserted after every mutation in the L2 scenarios | L2 | cadrage |
| A20 | nothing truncated at 100 % and 150 % GUI scale | **by eye**, two screenshots, recorded in §5 | **L3** | Philippe |
| A21 | every string in `locale/en` and `locale/fr` | key-parity scan: the two files must have identical key sets; a missing key fails | **L1** | cadrage |
| A22 | a button is never enabled when the action would fail | **by eye** (the enabled state is engine-side); the *state* that feeds it is asserted in L2 | L3 + L2 | Philippe + cadrage |
| A23 | field and presets never disagree | **by eye** for the display; the underlying value is asserted in L2 | L3 + L2 | Philippe + cadrage |
| A24 | a preset is clamped to what the balance allows | **by eye** for the display; the clamp value is asserted in L2 | L3 + L2 | Philippe + cadrage |
| A25 | archive free of keys, tokens, absolute paths; no network dependency | unzip the artefact, grep for `token`, `key`, `api`, `192.168`, `/opt/`, `%APPDATA%`; assert the file list | **L1** | cadrage |
| A26 | no player name or id in `storage` | serialise `storage` from a played save, grep for any player name | L2 | cadrage |
| A27 | save loads with the mod removed | `--start-server` on a save without the mod, assert clean stop and the engine warning | L2 | cadrage |
| A28 | two forces, one contract, the other force untouched | two-force map, digest force B's records before/after | L2 | cadrage |
| A4 | — | **withdrawn** (no conversion exists) | — | — |
| A8 | add-ons install, run, and are removed cleanly | **out of v1**: no add-on exists. Returns with the first add-on | — | — |
| A11 | bankruptcy is terminal, the company is resold | **out of v1**: parked (`0018`) | — | — |
| A12 | one contract kind per company, kind displayed | **partly v1**: one kind exists, so the "single kind" half is trivially true; the multi-kind half returns with `0019` | L2 | cadrage |

Counted honestly: **17 criteria proven automatically in game, 6 statically, 4 by eye, 4 out of v1
(A4 withdrawn, A8/A11 parked, A12 partial).**

## 4. Definition of done

A change is done when:

1. `make check` is green **and its output is quoted** in the pull request or commit;
2. `make test` is green in **both** DLC configurations;
3. every criterion touched by the change has its row in §3 updated **in the same commit** — a decision
   that changes behaviour and leaves the matrix stale is not done;
4. `make accept` has been run and its L3 rows are recorded in §5, or the change is explicitly not
   release-ready;
5. no number in `data/` was changed without re-running `make prices` and quoting the new table.

"The mod works in my game" is not evidence and never closes a criterion.

## 4bis. Environment facts measured while building this harness

| Fact | Consequence |
|---|---|
| `game.write_file` does not exist in 2.1.23 | use `helpers.write_file` (measured in `spike/fedora-smoke/`) |
| A `container` prototype has **no energy field at all** | D49 cannot hold with a container (ADR `0045`, Q58) |
| `--load` does not exist in 2.1 | the save/load cycle runs as `--benchmark <save> --benchmark-ticks 1`, and the save must live **outside** the mod directory — a `.zip` there is read as a mod |
| `prototypes.technology[...].unit` is not exposed at runtime | a test cannot read a technology's packs; the tier comes from our generated file |
| A non-recoverable error can still exit **0** in benchmark mode | the runner greps the log, and never trusts the exit code alone |
| `luac` is absent on this host | `make check` cannot pass; the syntax check is a headless load, quoted |

## 5. Release record — the by-eye criteria

Filled by the requester, one block per release. Empty means the release has not been visually accepted.

| Release | A20 (100 % / 150 %) | A22 (buttons) | A23 (field/preset) | A24 (clamp) | Date |
|---|---|---|---|---|---|
| _(none yet)_ | | | | | |

## 6. What is deliberately not tested, and why

- **Desync under real network conditions** — needs two real clients. A headless server plus one local
  connection proves the script runs, not that it is network-clean. Mitigation is by construction: one
  seeded RNG per company, no `math.random`, no iteration over unordered tables when writing state.
- **Cheating** — out of scope by ADR 0040. A save is editable, and a test that "prevents" it would only
  test the test.
- **Balance** — whether 20 % escrow feels right is a playtest question, not a test. The suite proves the
  rule is applied, never that the number is pleasant.
