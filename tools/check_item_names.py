#!/usr/bin/env python3
"""tools/check_item_names.py — every catalogue row must resolve to a name, in both languages.

Description
-----------
Lot (b) shipped a shop row that read `Unknown key: "item-name.pipe"`: the item existed, its recipe
existed, its icon rendered, and the game simply does not name `pipe` as an item (base 2.1.23 names
it under `[entity-name]` only). ADR 0052 fixes the rule in the generator; this file is the second
half of the rule, the one a hand edit cannot walk around.

What it checks, for every item of `data/prices.lua`:

1. the name has an entry under `[item-name]` in the base locale of `en` AND of `fr` — `en` because it
   is the fallback the engine draws from, `fr` because the requester plays in French (A21: a key
   declared in one language and missing from the other is a row that reads "Unknown key");
2. `item_count` matches the number of rows actually present — a hand-edited count would otherwise
   make every loop in the mod believe a row it cannot see;
3. the file is not empty: a check that passes on an empty catalogue proves nothing.

The names come from the game's own locale files (`<install>/data/base/locale/<language>/base.cfg`),
which are READ and never written. The game is located from the `FACTORIO` binary — the same knob as
`make test` — so no second machine path enters the repository. `make check` therefore needs the game
installed, exactly like `make test`; a check that silently skips when it cannot read its evidence is
the kind of green this repository refuses.

Usage
-----
    python3 tools/check_item_names.py                                  # FACTORIO from the environment
    python3 tools/check_item_names.py --factorio /path/to/bin/x64/factorio
    python3 tools/check_item_names.py --install /path/to/factorio      # skip the binary lookup
    python3 tools/check_item_names.py --locale-root /opt/.../base/locale

Exit code 0 when every row is named in both languages, 1 otherwise (one line per refused row).

Licence: MIT (see LICENSE)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

import base_locale

ROOT = Path(__file__).resolve().parent.parent
PRICES = ROOT / "data" / "prices.lua"

# `    ["iron-plate"] = { tier = 1, … }` — one row of the generated table.
ROW = re.compile(r'^\s*\["([^"]+)"\]\s*=\s*\{')
# `  item_count = 15,`
COUNT = re.compile(r"^\s*item_count\s*=\s*(\d+)\s*,")


def catalogue(path: Path) -> tuple[int | None, list[str]]:
    """The declared count and the rows of `data/prices.lua`, read without a Lua interpreter."""
    count: int | None = None
    items: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        row = ROW.match(line)
        if row is not None:
            items.append(row.group(1))
            continue
        declared = COUNT.match(line)
        if declared is not None:
            count = int(declared.group(1))
    return count, items


def base_version(install: Path) -> str:
    """`2.1.23`, read from the game's own `data/base/info.json` (never guessed in a message)."""
    info = install / "data" / "base" / "info.json"
    try:
        return str(json.loads(info.read_text(encoding="utf-8")).get("version", "unknown"))
    except (OSError, ValueError):
        return "unknown"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prices", default=str(PRICES))
    ap.add_argument("--factorio", default=os.environ.get("FACTORIO", "factorio"),
                    help="the factorio binary, or anywhere inside the install (default: $FACTORIO)")
    ap.add_argument("--install", default=None,
                    help="the unpacked game directory, when the binary is not where the environment says")
    ap.add_argument("--locale-root", default=None,
                    help="the directory holding <language>/base.cfg, instead of the install's own")
    args = ap.parse_args()

    prices = Path(args.prices)
    if not prices.is_file():
        print(f"missing catalogue: {prices}", file=sys.stderr)
        return 1

    install = Path(args.install) if args.install is not None else base_locale.install_root_from_binary(args.factorio)

    def locale_path(language: str) -> Path:
        if args.locale_root is not None:
            return Path(args.locale_root) / language / "base.cfg"
        return base_locale.locale_file(install, language)

    problems: list[str] = []

    count, items = catalogue(prices)
    if not items:
        problems.append(f'{prices}: no catalogue row found — the table parsed as empty, so nothing '
                        'was checked')
    if count is None:
        problems.append(f"{prices}: no item_count field — the mod reads it to size its loops")
    elif count != len(items):
        problems.append(f"{prices}: item_count = {count} but the table holds {len(items)} row(s)")

    resolved: dict[str, int] = {}
    for language in base_locale.LANGUAGES:
        path = locale_path(language)
        if not path.is_file():
            problems.append(f"missing base locale: {path} (pass --install or --locale-root)")
            continue
        named = base_locale.item_names(path)
        missing = [name for name in items if name not in named]
        for name in missing:
            problems.append(f'"{name}": no [{base_locale.ITEM_SECTION}] entry in locale/{language} '
                            f'({path})')
        resolved[language] = len(items) - len(missing)

    if problems:
        print("item names REFUSED:")
        for problem in problems:
            print(f"  - {problem}")
        print(f"\n{len(problems)} problem(s): every catalogue row must be nameable in both languages, "
              'and `pipe` proved what an unnameable row reads like — "Unknown key" (ADR 0052)')
        return 1

    version = base_version(install) if args.locale_root is None else "unknown"
    print(f"item names OK: {len(items)} catalogue item(s) resolve under "
          f"[{base_locale.ITEM_SECTION}] in locale/en and locale/fr "
          f"(base {version}; " + ", ".join(f"{lang}={resolved[lang]}" for lang in base_locale.LANGUAGES)
          + f"; item_count = {count})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
