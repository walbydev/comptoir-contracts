#!/usr/bin/env python3
"""Refuse a locale key the game cannot resolve, before the game is started.

Why this script exists: lot (b) shipped a window in which every caption read `Unknown key: "comptoir-…"`.
The window was right, the strings were there — and none of it resolved, because `locale/*/strings.cfg`
declared a section `[comptoir]` whose keys still carried their own prefix (`comptoir-available=…`)
while the Lua asked for the bare key `{"comptoir-available"}`. Factorio registers a section key as
`<section>.<key>`, so the engine looked for `comptoir.comptoir-available`, and `comptoir-available`
was nothing at all. Nothing failed at build time, `make check` was green, and the bench was green too:
no test had ever asked the engine to render a string.

The one form that works, everywhere (`locale/en/strings.cfg`, `locale/fr/strings.cfg`,
`scripts/gui/window.lua` — ADR 0053):

    [comptoir]
    available=available __1__          ; the key is the bare name
    caption = { "comptoir.available", n }   ; the prefix lives in the reference

What it checks, and why each one is a failure a player would see:

  1. Every `{"comptoir.<key>"}` literal in `scripts/` or `control.lua` exists under `[comptoir]` in
     BOTH locale files. A reference without a declaration is the `Unknown key` screen.
  2. Every `[comptoir]` key declared is referenced somewhere. A declaration nobody prints is a
     translation that rots, and it hides the copy-paste that produced the original bug.
  3. Every key name matches `[a-z0-9-]+`. A dot inside a key would be read as the section separator
     (`[comptoir]` + `a.b` is not a key), and an underscore is not accepted by the engine either —
     which is why the refusal reasons go out as `reason-no-free-slot`, not `reason-no_free_slot`.
  4. A key built by concatenation (`{ "comptoir.group-" .. name }`) is refused outright: no static
     check can see the result, and a key nobody can see is the class of bug this file exists to stop.
     The literal table (`GROUP_KEYS`, `REASON_KEYS` in `scripts/gui/window.lua`) is the fix.

`[item-name]`, `[entity-name]`, `[recipe-name]`, `[technology-name]` and the descriptions are left
alone: they resolve, and their keys are prototype names, not locale keys of ours.

Usage:
    python3 tools/check_locale.py      # exit 0 when the locale is consistent, 1 with one line per
                                      # problem (file, key, reason) otherwise
Wired into `make check`.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALE = ROOT / "locale"
LANGUAGES = ("en", "fr")
SECTION = "comptoir"

# Any string literal on a line; the surrounding characters decide whether it is a locale key.
LITERAL = re.compile(r'"([^"\n]*)"')
BARE = re.compile(r"^[a-z0-9-]+$")
LUA_SOURCES = ("control.lua", "scripts")
SKIP_DIRS = ("out", "spike", "test-mod", "temp")


def strip_comment(line: str) -> str:
    """Drop a Lua comment, keeping the quotes intact: `-- ...` outside a string is not code."""
    quoted = False
    index = 0
    while index < len(line):
        char = line[index]
        if char == '"':
            quoted = not quoted
        elif char == "-" and not quoted and line.startswith("--", index):
            return line[:index]
        index += 1
    return line


class Problem:
    """One refused line: where, which key, and why — the three things a reader needs."""

    def __init__(self, where: str, key: str, reason: str) -> None:
        self.where = where
        self.key = key
        self.reason = reason

    def __str__(self) -> str:
        return f"{self.where}: ERROR {self.key} — {self.reason}"


def rel(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def parse_locale(path: Path, problems: list[Problem]) -> dict[str, dict[str, tuple[str, int]]]:
    """Read a .cfg into {section: {key: (value, line)}}, and record what is not a key at all."""
    sections: dict[str, dict[str, tuple[str, int]]] = {}
    current: str | None = None
    if not path.is_file():
        problems.append(Problem(rel(path), "locale", "file is missing"))
        return sections
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
            continue
        if current is None:
            problems.append(Problem(f"{rel(path)}:{number}", line, "key outside any [section]"))
            continue
        if "=" not in line:
            problems.append(Problem(f"{rel(path)}:{number}", line, "line is neither a section nor key=value"))
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        sections[current][key] = (value.strip(), number)
    return sections


def lua_files() -> list[Path]:
    files: list[Path] = []
    control = ROOT / "control.lua"
    if control.is_file():
        files.append(control)
    scripts = ROOT / "scripts"
    if scripts.is_dir():
        files.extend(sorted(p for p in scripts.rglob("*.lua") if p.is_file()))
    return files


def references(problems: list[Problem]) -> dict[str, list[str]]:
    """Every `comptoir.<key>` a Lua file asks the engine to resolve, with where it was found.

    A dotted literal is read wherever it stands, because a caption table may be written over several
    lines (`text.caption = {` newline `"comptoir.character",`). A bare `comptoir-…` key is only read
    directly after a `{`: outside a table constructor `"comptoir-counter"` is the counter's name, not
    a string the player reads.
    """
    found: dict[str, list[str]] = {}
    for path in lua_files():
        for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            where = f"{rel(path)}:{number}"
            line = strip_comment(raw)
            for match in LITERAL.finditer(line):
                text = match.group(1)
                if text.startswith(f"{SECTION}."):
                    rest = line[match.end() :].lstrip()
                    if rest.startswith(".."):
                        problems.append(
                            Problem(
                                where,
                                text + "…",
                                "key built by concatenation — no check can see the result; write the "
                                "captions as literals (see REASON_KEYS / GROUP_KEYS in "
                                "scripts/gui/window.lua)",
                            )
                        )
                        continue
                    key = text[len(SECTION) + 1 :]
                    found.setdefault(key, []).append(where)
                elif text.startswith(f"{SECTION}-") and line[: match.start()].rstrip().endswith("{"):
                    problems.append(
                        Problem(
                            where,
                            text,
                            f'bare key — the engine registers a [{SECTION}] key as "{SECTION}.<key>", '
                            f'so this must be {{"{SECTION}.<key>"}} and the key itself must not carry '
                            f"the prefix",
                        )
                    )
    return found


def main() -> int:
    problems: list[Problem] = []
    declared: dict[str, dict[str, tuple[str, int]]] = {}
    for language in LANGUAGES:
        path = LOCALE / language / "strings.cfg"
        sections = parse_locale(path, problems)
        if SECTION not in sections:
            problems.append(Problem(rel(path), f"[{SECTION}]", f"section is missing"))
            declared[language] = {}
            continue
        declared[language] = sections[SECTION]

    # 3. Name shape, in every language.
    for language, keys in declared.items():
        for key, (_, number) in keys.items():
            if not BARE.match(key):
                hint = ""
                if "." in key:
                    hint = "; a dot is the section separator, the prefix belongs to the section name only"
                elif "_" in key:
                    hint = "; use '-' instead of '_'"
                problems.append(
                    Problem(
                        f"{rel(LOCALE / language / 'strings.cfg')}:{number}",
                        key,
                        f"key name must match [a-z0-9-]+{hint}",
                    )
                )

    # A21: the two files hold the same key set, or French silently falls back to English.
    en, fr = declared.get("en", {}), declared.get("fr", {})
    for key in sorted(set(en) - set(fr)):
        problems.append(
            Problem(
                f"{rel(LOCALE / 'en' / 'strings.cfg')}:{en[key][1]}",
                key,
                "declared in locale/en but missing from locale/fr (the French client would fall back "
                "to English)",
            )
        )
    for key in sorted(set(fr) - set(en)):
        problems.append(
            Problem(
                f"{rel(LOCALE / 'fr' / 'strings.cfg')}:{fr[key][1]}",
                key,
                "declared in locale/fr but missing from locale/en (the fallback language does not "
                "know it)",
            )
        )

    used = references(problems)

    # 1. A reference the locale does not answer, in either language.
    for key in sorted(used):
        missing = [language for language in LANGUAGES if key not in declared.get(language, {})]
        if missing:
            problems.append(
                Problem(
                    used[key][0],
                    f"{SECTION}.{key}",
                    "missing from " + " and ".join(f"locale/{language}/strings.cfg" for language in missing),
                )
            )

    # 2. A declaration nothing prints.
    for language in LANGUAGES:
        for key, (_, number) in sorted(declared.get(language, {}).items()):
            if key not in used:
                problems.append(
                    Problem(
                        f"{rel(LOCALE / language / 'strings.cfg')}:{number}",
                        key,
                        "declared under [comptoir] but referenced nowhere in scripts/ or control.lua "
                        "(dead string)",
                    )
                )

    seen = set()
    unique: list[Problem] = []
    for problem in problems:
        marker = str(problem)
        if marker not in seen:
            seen.add(marker)
            unique.append(problem)

    if unique:
        print(f"locale REFUSED: {len(unique)} problem(s)")
        for problem in unique:
            print("  - " + str(problem))
        return 1

    keys = len(en)
    print(
        f"locale OK: {keys} key(s) under [{SECTION}] in locale/en and locale/fr, "
        f"every one referenced in scripts/ and control.lua ({sum(len(v) for v in used.values())} "
        f"reference(s)), every name matches [a-z0-9-]+"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
