# 0053 — A locale key is `<section>.<key>`, and the check refuses any other shape

- **State**: accepted
- **Status**: accepted 2026-10-25, from a screenshot of lot (b): every caption of the window read
  `Unknown key: "comptoir-…"`
- **Date**: 2026-10-25
- **Block**: lot (b)
- **Amends**: `0037` (window structure), `0050` (what the bench can prove about the GUI)

## What happened

The window was correct and the strings were written. Nothing resolved. `locale/en/strings.cfg` and
`locale/fr/strings.cfg` declared:

```
[comptoir]
comptoir-available=available __1__
```

and the Lua asked for `{ "comptoir-available" }`. Factorio registers a key of a section as
`<section>.<key>`, so the file offered `comptoir.comptoir-available` — a name no line of Lua contains —
while `comptoir-available` on its own is not a key of any section and resolves to nothing. Every
caption came back `Unknown key: "comptoir-available"`, and the three contract rows, the bars, the icons
and the buttons drew perfectly around the missing text.

Three gates were green while this shipped: `luac -p` saw valid Lua, `make test` saw 42 green runs, and
`make audit` saw a framing that did not mention strings at all. No test had ever asked the engine to
render one.

## Decision

**A locale key carries no prefix of its own; the prefix is the section name.**

| where | correct | refused |
| --- | --- | --- |
| `locale/*/strings.cfg` | `[comptoir]` then `available=…` | `[comptoir]` then `comptoir-available=…` |
| Lua | `{ "comptoir.available", n }` | `{ "comptoir-available" }`, `{ "comptoir.comptoir-available" }` |

Key names are `[a-z0-9-]+`: no dot (it would read as the section separator) and no underscore (the
engine does not accept it in a key, which is why the refusal reasons go out as `reason-no-free-slot`
while the modules keep their `no_free_slot` code — the code belongs to the module, the key belongs to
the locale).

`[item-name]`, `[entity-name]`, `[recipe-name]`, `[technology-name]` and the two description sections
are untouched: their keys are prototype names and they resolve.

**A caption is a literal.** `{ "comptoir.group-" .. group }` is banned, even though it would have
worked, because no static check can see which keys it produces — and an unseeable key is the class of
bug this ADR exists to close. The groups and the refusal reasons live in `GROUP_KEYS` and
`REASON_KEYS` in `scripts/gui/window.lua`, one literal per entry; `M.REASONS` is derived from
`REASON_KEYS` so the two lists cannot drift apart.

## Why not keep the prefix inside the section

Renaming the section to `[]` is impossible, and `[comptoir]` + prefixed keys would have to be asked for
as `{"comptoir.comptoir-available"}` — a name that lies twice about where the string is. The section
already is the namespace; spelling it twice is what made the bug invisible in review: the file and the
Lua each looked right on their own.

## Consequence for the tests

Two gates, because there are two questions, and they are not the same question:

- **L1 — `tools/check_locale.py`, wired into `make check`.** Every `{"comptoir.<key>"}` literal in
  `scripts/` and `control.lua` must exist under `[comptoir]` in **both** locale files; every declared
  key must be referenced somewhere (no dead string); every key name must match `[a-z0-9-]+`; a key
  built with `..` and a bare `comptoir-…` key are refused outright. Exit 1, one line per problem with
  the file, the key and the reason.
- **L2 — B1-gui-pure, in the bench.** Four of the window's keys are handed to the engine and the text
  it resolves is read back by the runner. This is the only way to know the engine agrees with the
  check, and it is a measurement, not a reading: `helpers.write_file(path, localised_string)` writes
  the *resolved* text (measured on 2.1.23, 2026-10-25 — `{"k"}:format()` raises, there is no
  `read_file`, `localised_print` returns nothing), and a key the engine cannot find lands in the file
  as `Unknown key: "…"`, which `judge()` turns into a red run.

Both were seen red on the wrong shape before being accepted: the static check on the prefixed
declaration, the bench on `locale probe available: Unknown key: "comptoir.available"`.

## Note

`0050` concluded that the *frame* cannot be built headless (no `player.gui.screen` without a client).
That still holds, and it is why the layout stays a by-eye criterion. What `0050` did not cover is the
*text*: a localised string can be resolved headless, so "the GUI is untestable" was one conclusion too
wide, and the window shipped on it.
