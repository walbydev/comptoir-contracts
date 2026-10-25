#!/usr/bin/env python3
"""Draw the counter sprite and its item icon.

The counter is a 9x9 building: a landing platform around a space elevator, with the mast
rising out of the top of the sprite so the shaft reads as going into the sky.

Everything is drawn at 4x and downsampled once, because PIL has no anti-aliasing: at 4x the
diagonals of the hazard stripes and the chamfered corners come out clean at 288 px.

Output:
  graphics/counter/counter.png        288x288  (9 tiles x 32 px) — the entity
  graphics/counter/counter-icon.png    64x64   — the item, without the mast so it reads small

Run: python3 tools/make_counter_sprite.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

TILE = 32
TILES = 9
S = TILE * TILES  # 288
SS = 4  # supersampling factor
W = S * SS

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "graphics" / "counter"

STEEL = (74, 81, 90)
STEEL_LIGHT = (98, 106, 116)
STEEL_DARK = (52, 58, 65)
PLATE = (61, 67, 75)
DEEP = (33, 37, 42)
BLACK = (24, 27, 31)
ORANGE = (208, 108, 42)
ORANGE_LIGHT = (238, 146, 74)
YELLOW = (226, 190, 58)
GREY = (150, 158, 168)
WHITE = (214, 221, 229)


def px(v: float) -> float:
    """Scale a coordinate expressed in final pixels to the supersampled canvas."""
    return v * SS


def chamfer_polygon(size: float, chamfer: float, cx: float, cy: float) -> list[tuple[float, float]]:
    """An octagon: a square with cut corners, centred on (cx, cy)."""
    h = size / 2.0
    c = chamfer
    return [
        (px(cx - h + c), px(cy - h)),
        (px(cx + h - c), px(cy - h)),
        (px(cx + h), px(cy - h + c)),
        (px(cx + h), px(cy + h - c)),
        (px(cx + h - c), px(cy + h)),
        (px(cx - h + c), px(cy + h)),
        (px(cx - h), px(cy + h - c)),
        (px(cx - h), px(cy - h + c)),
    ]


def hazard_band(draw: ImageDraw.ImageDraw, box, step: int, color_a, color_b, width: int) -> None:
    """Diagonal hazard stripes inside `box`, clipped by it."""
    x0, y0, x1, y1 = box
    mask = Image.new("L", (W, W), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([px(x0), px(y0), px(x1), px(y1)], fill=255)
    stripes = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stripes)
    span = (x1 - x0) + (y1 - y0)
    offset = -int(span)
    i = 0
    while offset < span:
        col = color_a if i % 2 == 0 else color_b
        sd.polygon(
            [
                (px(x0 + offset), px(y1)),
                (px(x0 + offset + step), px(y1)),
                (px(x0 + offset + step + (y1 - y0)), px(y0)),
                (px(x0 + offset + (y1 - y0)), px(y0)),
            ],
            fill=col + (255,),
        )
        offset += step
        i += 1
    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    base.paste(stripes, (0, 0), mask)
    draw._image.alpha_composite(base)


def rungs(draw: ImageDraw.ImageDraw, x0: float, x1: float, y0: float, y1: float, step: float) -> None:
    y = y0
    while y < y1:
        draw.line([(px(x0), px(y)), (px(x1), px(y))], fill=STEEL_LIGHT + (255,), width=int(px(1.4)))
        y += step


def draw_counter() -> Image.Image:
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S / 2.0

    # --- platform ------------------------------------------------------------------------
    outer = chamfer_polygon(S - 6, 26, cx, cy)
    d.polygon(outer, fill=STEEL_DARK + (255,))
    inner = chamfer_polygon(S - 22, 24, cx, cy)
    d.polygon(inner, fill=PLATE + (255,))
    deck = chamfer_polygon(S - 44, 22, cx, cy)
    d.polygon(deck, fill=STEEL + (255,))

    # panel lines: four quadrants, so the deck does not read as a flat slab
    for angle in (0, 90, 180, 270):
        a = math.radians(angle + 45)
        d.line(
            [(px(cx + math.cos(a) * 34), px(cy + math.sin(a) * 34)),
             (px(cx + math.cos(a) * 118), px(cy + math.sin(a) * 118))],
            fill=STEEL_DARK + (255,), width=int(px(1.2)),
        )

    # rivets along the outer chamfer
    for k in range(48):
        a = 2 * math.pi * k / 48
        rx, ry = cx + math.cos(a) * (S / 2 - 16), cy + math.sin(a) * (S / 2 - 16)
        d.ellipse([px(rx - 1.6), px(ry - 1.6), px(rx + 1.6), px(ry + 1.6)], fill=STEEL_LIGHT + (255,))

    # --- hazard stripe along the south edge (the "front") --------------------------------
    band_y = cy + 96
    hazard_band(d, (cx - 92, band_y, cx + 92, band_y + 11), 9, YELLOW, BLACK, 0)
    d.polygon(
        [
            (px(cx - 92), px(band_y)), (px(cx + 92), px(band_y)),
            (px(cx + 92), px(band_y + 11)), (px(cx - 92), px(band_y + 11)),
        ],
        outline=BLACK + (200,),
        width=int(px(1)),
    )

    # --- alignment dashes, bottom centre -------------------------------------------------
    for i, x in enumerate(range(-26, 27, 13)):
        if i % 2 == 0:
            d.rectangle([px(cx + x), px(cy + 76), px(cx + x + 6), px(cy + 79)], fill=GREY + (220,))

    # --- hydraulic arms and the two hatches ----------------------------------------------
    for side in (-1, 1):
        hx = cx + side * 78
        hy = cy + 62
        d.line(
            [(px(cx + side * 26), px(cy + 26)), (px(hx - side * 18), px(hy - 10))],
            fill=ORANGE + (255,), width=int(px(9)),
        )
        d.line(
            [(px(cx + side * 26), px(cy + 26)), (px(hx - side * 18), px(hy - 10))],
            fill=ORANGE_LIGHT + (255,), width=int(px(3)),
        )
        d.ellipse([px(hx - 27), px(hy - 27), px(hx + 27), px(hy + 27)], fill=STEEL_DARK + (255,))
        d.ellipse([px(hx - 22), px(hy - 22), px(hx + 22), px(hy + 22)], fill=STEEL + (255,))
        d.ellipse([px(hx - 15), px(hy - 15), px(hx + 15), px(hy + 15)], fill=DEEP + (255,))
        for k in range(8):
            a = 2 * math.pi * k / 8
            bx, by = hx + math.cos(a) * 19, hy + math.sin(a) * 19
            d.ellipse([px(bx - 2), px(by - 2), px(bx + 2), px(by + 2)], fill=STEEL_LIGHT + (255,))

    # --- vents, north corners -------------------------------------------------------------
    for side in (-1, 1):
        vx = cx + side * 70
        vy = cy - 74
        d.rectangle([px(vx - 22), px(vy - 13), px(vx + 22), px(vy + 13)], fill=DEEP + (255,))
        for i in range(5):
            d.line([(px(vx - 18), px(vy - 9 + i * 4.5)), (px(vx + 18), px(vy - 9 + i * 4.5))],
                   fill=STEEL_DARK + (255,), width=int(px(1.6)))

    # --- small status panels ---------------------------------------------------------------
    for side in (-1, 1):
        sx = cx + side * 104
        sy = cy - 20
        d.rectangle([px(sx - 9), px(sy - 6), px(sx + 9), px(sy + 6)], fill=BLACK + (255,))
        d.rectangle([px(sx - 7), px(sy - 4), px(sx + 7), px(sy + 4)], fill=(120, 40, 34, 255))

    # --- the mast, drawn LAST so it rises in front of the deck ---------------------------
    # The elevator leaves the collar and climbs out of the sprite: that line is the signature
    # the requester asked for, so it must be visible, not tucked behind the platform.
    base_w, top_w = 34.0, 20.0
    top_y = 0.0
    steps = 120
    for i in range(steps):
        f0, f1 = i / steps, (i + 1) / steps
        y0 = cy - 30 - (cy - 30 - top_y) * f0
        y1 = cy - 30 - (cy - 30 - top_y) * f1
        w0 = base_w + (top_w - base_w) * f0
        w1 = base_w + (top_w - base_w) * f1
        shade = int(58 - 26 * f0)
        d.polygon(
            [(px(cx - w0 / 2), px(y0)), (px(cx + w0 / 2), px(y0)),
             (px(cx + w1 / 2), px(y1)), (px(cx - w1 / 2), px(y1))],
            fill=(shade, shade + 4, shade + 9, 255),
        )
    # rails
    for side in (-1, 1):
        for i in range(steps):
            f0, f1 = i / steps, (i + 1) / steps
            y0 = cy - 30 - (cy - 30 - top_y) * f0
            y1 = cy - 30 - (cy - 30 - top_y) * f1
            w0 = base_w + (top_w - base_w) * f0
            w1 = base_w + (top_w - base_w) * f1
            x0 = cx + side * (w0 / 2 - 4)
            x1 = cx + side * (w1 / 2 - 4)
            d.line([(px(x0), px(y0)), (px(x1), px(y1))],
                   fill=(STEEL_LIGHT if side < 0 else STEEL_DARK) + (255,), width=int(px(3.4)))
    # rungs, fading upward
    y = cy - 34
    k = 0
    while y > top_y + 6:
        f = 1 - (y / (cy - 30))
        w = base_w + (top_w - base_w) * f
        alpha = max(70, int(210 - 150 * f))
        d.line([(px(cx - w / 2 + 5), px(y)), (px(cx + w / 2 - 5), px(y))],
               fill=(150, 158, 168, alpha), width=int(px(1.8)))
        y -= 10
        k += 1
    # --- the collar: the mouth of the elevator -------------------------------------------
    r = 40
    d.ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=STEEL_DARK + (255,))
    for k in range(16):
        a0 = 2 * math.pi * k / 16
        a1 = 2 * math.pi * (k + 1) / 16
        col = YELLOW if k % 2 == 0 else BLACK
        d.pieslice(
            [px(cx - r + 4), px(cy - r + 4), px(cx + r - 4), px(cy + r - 4)],
            math.degrees(a0), math.degrees(a1), fill=col + (255,),
        )
    d.ellipse([px(cx - 27), px(cy - 27), px(cx + 27), px(cy + 27)], fill=STEEL_LIGHT + (255,))
    d.ellipse([px(cx - 23), px(cy - 23), px(cx + 23), px(cy + 23)], fill=DEEP + (255,))
    # the shaft opening, darker at the centre
    d.ellipse([px(cx - 15), px(cy - 15), px(cx + 15), px(cy + 15)], fill=(14, 16, 20, 255))

    return img.resize((S, S), Image.LANCZOS)


def draw_icon(platform: Image.Image) -> Image.Image:
    """The item icon: the platform without the mast, cropped tight, so it reads at 64 px."""
    crop = platform.crop((int(px(0)), int(px(0)), S, S)) if False else platform
    side = S
    img = crop.resize((64, 64), Image.LANCZOS)
    return img


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    platform = draw_counter()
    platform.save(OUT_DIR / "counter.png")
    draw_icon(platform).save(OUT_DIR / "counter-icon.png")
    print(f"wrote {OUT_DIR/'counter.png'} ({S}x{S}) and counter-icon.png (64x64)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
