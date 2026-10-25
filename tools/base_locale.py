#!/usr/bin/env python3
"""Read the names the game gives its own items, from the game's own locale files.

Why this module exists (ADR 0052): the catalogue of the counter may only hold items the game names
as **items**. `pipe` proves the rule the hard way — base 2.1.23 localises it under `[entity-name]`
only, so `item-name.pipe` resolves to nothing and the shop row read `Unknown key: "item-name.pipe"`.
The evidence is therefore not in the price dump (`--dump-data` carries prototypes and no strings at
all): it is in `<install>/data/base/locale/<language>/base.cfg`.

Two callers, one rule:

- `tools/cost_table.py` refuses a candidate with no `[item-name]` entry, so an item that cannot be
  displayed never enters `data/prices.lua`;
- `tools/check_item_names.py` refuses a catalogue row that cannot be named in BOTH languages, so the
  same item cannot come back through a hand edit.

Nothing here writes to the game's directory: these files are read, never modified.

The install is not configured twice. `--dump-data` writes to `<install>/script-output/`, and the base
locale sits next to it, so a caller that already knows the dump path knows the locale path too.
"""

from __future__ import annotations

import os
from pathlib import Path

# Where `factorio --dump-data` writes, when nobody says otherwise. A machine path in a public
# repository is a wart; it is here once, and every caller can override it (--dump, --install,
# --locale-file) instead of carrying a second copy.
DEFAULT_DUMP = "/opt/data/.local/opt/factorio/script-output/data-raw-dump.json"

# The item namespace: the section a shop row asks for as { "item-name.<prototype name>" }.
ITEM_SECTION = "item-name"

# `en` is the fallback language and the one the generator checks against; `fr` is checked too, because
# a name present in one language and missing from the other is a row that reads "Unknown key" in the
# requester's own client (A21).
LANGUAGES = ("en", "fr")

LOCALE_PARTS = ("data", "base", "locale")


def _is_install(path: Path) -> bool:
    """An unpacked game directory: it holds `data/` and `config/` side by side."""
    return (path / "data").is_dir() and (path / "config").is_dir()


def install_root_from_dump(dump_path: str | Path) -> Path:
    """`<install>/script-output/data-raw-dump.json` -> `<install>`."""
    dump = Path(dump_path).resolve()
    root = dump.parent.parent
    if not _is_install(root):
        raise SystemExit(
            f"no game directory above {dump} (expected {root} to hold data/ and config/) — "
            "pass --locale-file instead"
        )
    return root


def install_root_from_binary(binary: str | Path) -> Path:
    """`<install>/bin/x64/factorio` -> `<install>`, wherever the binary was installed."""
    path = Path(binary)
    if path.is_file():
        candidates = [path.parent, *path.parents]
    else:
        # A bare name: resolve it against PATH before giving up on it.
        found = None
        for directory in os.environ.get("PATH", "").split(os.pathsep):
            candidate = Path(directory) / str(binary)
            if candidate.is_file():
                found = candidate
                break
        if found is None:
            raise SystemExit(
                f"factorio binary not found: {binary} — set FACTORIO=/path/to/bin/x64/factorio "
                "(the item-name check reads the game's own locale, ADR 0052)"
            )
        candidates = [found.parent, *found.parents]
    for candidate in candidates:
        if _is_install(candidate):
            return candidate
    raise SystemExit(
        f"no game directory above {binary} (expected a folder with data/ and config/) — "
        "pass --install instead"
    )


def locale_file(install_root: Path, language: str) -> Path:
    """`<install>/data/base/locale/<language>/base.cfg` — base's strings, in one file."""
    return install_root.joinpath(*LOCALE_PARTS, language, "base.cfg")


def item_names(path: str | Path) -> set[str]:
    """Every key of the `[item-name]` section of a locale file.

    The format is the game's own `strings.cfg`: a section header in brackets, then `key=value` lines;
    `;` and `#` start a comment. A key here is a prototype name (`iron-plate`), not one of our
    `comptoir.…` keys.
    """
    names: set[str] = set()
    section: str | None = None
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section == ITEM_SECTION and "=" in line:
            names.add(line.split("=", 1)[0].strip())
    return names
