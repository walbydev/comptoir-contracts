#!/usr/bin/env python3
"""tools/check_artwork.py — the counter's two pictures, checked where the game cannot be asked.

Description: `data/counter.lua` points the entity at a 288 px sprite (9 tiles at 32 px, never scaled)
             and `data/item.lua` gives the item its own 64 px icon. A running game cannot be asked to
             hand those numbers back — `LuaEntityPrototype` has no `picture` field and
             `LuaItemPrototype` has no `icon` (measured 2026-10-25) — so this file asserts the half a
             bench cannot: the two PNG files exist, are the size and the colour type the prototypes
             claim, the prototypes still claim them, the boxes still describe a 9 x 9 building, and
             `tools/run_tests.py` still copies `graphics/` into the throwaway install (without that
             copy the data stage fails with a missing sprite, and the failure would read like a
             prototype error instead of a packaging one).

Author:      Philippe Ryf
Created:     2026-10-25
Revisions:   2026-10-25 — initial: dimensions, colour type, the four sprite numbers, the two boxes, the
                           item icon, and the packaging list (ADR 0056 §1)
Usages:      `make check` (target `check-artwork`)
Notes:       IT READS THE LUA, IT DOES NOT RUN IT: the numbers are matched with a strict pattern, so a
             rewrite of `data/counter.lua` that moves a number around has to move this file too. That
             is the point — the two are supposed to agree, and silence is not agreement.
             NO FACTORIO NEEDED: unlike `check-items`, this target is happy on a machine without the
             game, so `make check` stays usable in a bare checkout.
Licence:     MIT (see LICENSE)
"""

from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ENTITY_SPRITE = ROOT / "graphics" / "counter" / "counter.png"
ITEM_ICON = ROOT / "graphics" / "counter" / "counter-icon.png"
ENTITY_LUA = ROOT / "data" / "counter.lua"
ITEM_LUA = ROOT / "data" / "item.lua"
BALANCE_LUA = ROOT / "config" / "balance.lua"
RUNNER = ROOT / "tools" / "run_tests.py"

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
COLOUR_TYPE_RGBA = 6

failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def png_size(path: Path) -> tuple[int, int, int]:
    """Width, height and PNG colour type, read from the IHDR chunk — no image library needed."""
    if not path.is_file():
        raise SystemExit(f"check_artwork: {path.relative_to(ROOT)} is missing")
    data = path.read_bytes()
    if data[:8] != PNG_SIGNATURE:
        raise SystemExit(f"check_artwork: {path.relative_to(ROOT)} is not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    return width, height, data[25]


def number(text: str, pattern: str, what: str) -> float:
    match = re.search(pattern, text)
    if match is None:
        fail(f"{what}: not found (pattern {pattern}) — the file and this check have drifted apart")
        return float("nan")
    return float(match.group(1))


def main() -> int:
    width, height, colour_type = png_size(ENTITY_SPRITE)
    icon_width, icon_height, icon_colour_type = png_size(ITEM_ICON)

    if (width, height) != (288, 288):
        fail(f"graphics/counter/counter.png is {width}x{height}, the entity claims 288x288 (9 tiles at 32 px)")
    if colour_type != COLOUR_TYPE_RGBA:
        fail(f"graphics/counter/counter.png is not RGBA (PNG colour type {colour_type})")
    if (icon_width, icon_height) != (64, 64):
        fail(f"graphics/counter/counter-icon.png is {icon_width}x{icon_height}, the item claims 64x64")
    if icon_colour_type != COLOUR_TYPE_RGBA:
        fail(f"graphics/counter/counter-icon.png is not RGBA (PNG colour type {icon_colour_type})")

    entity = ENTITY_LUA.read_text(encoding="utf-8")
    item = ITEM_LUA.read_text(encoding="utf-8")
    balance = BALANCE_LUA.read_text(encoding="utf-8")

    if "__comptoir-contracts__/graphics/counter/counter.png" not in entity:
        fail("data/counter.lua does not point at graphics/counter/counter.png")
    if "__comptoir-contracts__/graphics/counter/counter-icon.png" not in item:
        fail("data/item.lua does not point at graphics/counter/counter-icon.png")

    for pattern, expected, name in (
        (r"width\s*=\s*(\d+)", 288, "picture width"),
        (r"height\s*=\s*(\d+)", 288, "picture height"),
        (r"scale\s*=\s*([\d.]+)", 1, "picture scale"),
        (r"shift\s*=\s*\{\s*([-\d.]+)\s*,", 0, "picture shift x"),
    ):
        found = number(entity, pattern, f"data/counter.lua {name}")
        if found != expected:
            fail(f"data/counter.lua {name} is {found}, expected {expected}")

    footprint = number(balance, r"footprint_tiles\s*=\s*(\d+)", "config/balance.lua footprint_tiles")
    half = number(entity, r"footprint_tiles\s*/\s*(\d+)", "data/counter.lua half-extent divisor")
    if half != 2:
        fail(f"data/counter.lua divides the footprint by {half}; the boxes are its halves")
    if not (footprint >= 1) or footprint % 2 != 1:
        fail(f"config/balance.lua footprint_tiles is {footprint}; it must be an odd whole number of tiles")
    # The sprite is 32 px per tile: the file and the footprint have to describe the same building.
    if (width / 32) != footprint:
        fail(f"counter.png is {width} px wide, which is {width / 32} tiles, but footprint_tiles is {footprint}")

    # The two boxes are the halves of the footprint, written as `{-half, -half}, {half, half}` — so the
    # 9 x 9 of the prototype follows from `footprint_tiles` and from this one shape. Scenario B5-sprite
    # reads the resulting boxes back from the running game (they are +/-4.5, nine tiles across).
    for name in ("collision_box", "selection_box"):
        pattern = name + r"\s*=\s*\{\s*\{\s*-half\s*,\s*-half\s*\}\s*,\s*\{\s*half\s*,\s*half\s*\}\s*\}"
        if re.search(pattern, entity) is None:
            fail(f"data/counter.lua has no `{name} = {{{{ -half, -half }}, {{ half, half }}}}`")

    icon_size = number(item, r"icon_size\s*=\s*(\d+)", "data/item.lua icon_size")
    if icon_size != 64:
        fail(f"data/item.lua icon_size is {icon_size}, expected the file's own 64")

    runner = RUNNER.read_text(encoding="utf-8")
    if '"graphics"' not in runner:
        fail("tools/run_tests.py no longer copies `graphics/`: the sprite would be missing at load")

    if failures:
        for message in failures:
            print(f"check_artwork: FAIL {message}", file=sys.stderr)
        return 1

    print(
        "artwork OK: counter.png 288x288 RGBA (9 x 32 px = "
        f"{width // 32} tiles), counter-icon.png 64x64 RGBA, boxes +/-4.5, scale 1, shift 0,0, "
        "graphics/ on the packaging list"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
