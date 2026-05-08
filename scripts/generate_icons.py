#!/usr/bin/env python3
"""Generate the 18 placeholder PNG icons used by the Roblox HUD.

Each icon is rendered as a 256x256 white shape on a transparent background.
The HUD applies its own tint via ImageColor3 so colour does not need to be
encoded in the PNG itself.

Run from the repo root: ``python3 scripts/generate_icons.py``.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "icons"
SIZE = 256
WHITE = (255, 255, 255, 255)


def new_canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(img: Image.Image, name: str) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"{name}.png"
    img.save(out, "PNG")


def stroke_polygon(draw: ImageDraw.ImageDraw, pts, width: int = 14) -> None:
    pts = list(pts)
    pts.append(pts[0])
    draw.line(pts, fill=WHITE, width=width, joint="curve")


def heart() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    points = []
    for t in [i / 200 for i in range(201)]:
        angle = 2 * math.pi * t
        x = 16 * math.sin(angle) ** 3
        y = -(13 * math.cos(angle) - 5 * math.cos(2 * angle) - 2 * math.cos(3 * angle) - math.cos(4 * angle))
        sx = 128 + x * 7
        sy = 128 + y * 7
        points.append((sx, sy))
    draw.polygon(points, fill=WHITE)
    return img


def zap() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    pts = [
        (148, 24),
        (60, 138),
        (118, 138),
        (88, 232),
        (200, 110),
        (140, 110),
        (170, 24),
    ]
    draw.polygon(pts, fill=WHITE)
    return img


def award() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # 5-pointed star
    pts = []
    cx, cy = 128, 110
    outer, inner = 90, 40
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=WHITE)
    # ribbon
    draw.polygon([(96, 196), (160, 196), (160, 248), (128, 224), (96, 248)], fill=WHITE)
    return img


def coins() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    draw.ellipse([(40, 40), (216, 216)], fill=WHITE)
    draw.ellipse([(72, 72), (184, 184)], outline=(0, 0, 0, 0), fill=(0, 0, 0, 0))
    # Hollow center via mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([(72, 72), (184, 184)], fill=255)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(transparent, (0, 0), mask)
    # Dollar sign
    d2 = ImageDraw.Draw(img)
    d2.text((116, 100), "$", fill=WHITE)
    # Stroke for $
    d2.line([(128, 86), (128, 170)], fill=WHITE, width=12)
    d2.arc([(96, 96), (160, 138)], 30, 330, fill=WHITE, width=12)
    d2.arc([(96, 118), (160, 160)], 210, 510, fill=WHITE, width=12)
    return img


def star() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    pts = []
    cx, cy = 128, 128
    outer, inner = 110, 50
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=WHITE)
    return img


def swords() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Two crossed swords drawn as rotated rectangles + triangular tips.
    def sword(angle_deg: float) -> Image.Image:
        plate = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(plate)
        d.polygon([(118, 32), (138, 32), (138, 200), (118, 200)], fill=WHITE)  # blade
        d.polygon([(102, 200), (154, 200), (138, 220), (118, 220)], fill=WHITE)  # guard
        d.polygon([(120, 220), (136, 220), (136, 244), (120, 244)], fill=WHITE)  # hilt
        return plate.rotate(angle_deg, resample=Image.BICUBIC, center=(128, 128))

    img.alpha_composite(sword(45))
    img.alpha_composite(sword(-45))
    return img


def shield() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Heater shield outline
    pts = [
        (60, 40),
        (196, 40),
        (196, 130),
        (128, 224),
        (60, 130),
    ]
    draw.polygon(pts, fill=WHITE)
    # Inner cross
    d2 = ImageDraw.Draw(img)
    d2.rectangle([(120, 70), (136, 200)], fill=(0, 0, 0, 0))
    d2.rectangle([(80, 130), (176, 146)], fill=(0, 0, 0, 0))
    return img


def backpack() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Body
    draw.rounded_rectangle([(56, 80), (200, 232)], radius=20, fill=WHITE)
    # Top handle
    draw.rounded_rectangle([(96, 36), (160, 76)], radius=14, outline=WHITE, width=12)
    # Front pocket cutout
    pocket = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(pocket)
    md.rounded_rectangle([(82, 142), (174, 212)], radius=12, fill=255)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(transparent, (0, 0), pocket)
    return img


def map_icon() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Folded paper (3 vertical panels)
    draw.polygon([(40, 76), (102, 56), (102, 220), (40, 240)], fill=WHITE)
    draw.polygon([(102, 56), (158, 76), (158, 240), (102, 220)], fill=WHITE)
    draw.polygon([(158, 76), (220, 56), (220, 220), (158, 240)], fill=WHITE)
    # Holes between panels
    panel_mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(panel_mask)
    md.line([(102, 56), (102, 220)], fill=255, width=4)
    md.line([(158, 76), (158, 240)], fill=255, width=4)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(transparent, (0, 0), panel_mask)
    return img


def users() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Two head circles + bodies
    draw.ellipse([(48, 50), (120, 122)], fill=WHITE)
    draw.ellipse([(140, 50), (212, 122)], fill=WHITE)
    draw.rounded_rectangle([(28, 140), (132, 230)], radius=24, fill=WHITE)
    draw.rounded_rectangle([(124, 140), (228, 230)], radius=24, fill=WHITE)
    return img


def settings() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    cx, cy = 128, 128
    teeth = 8
    outer, inner = 116, 92
    pts = []
    for i in range(teeth * 2):
        r = outer if i % 2 == 0 else inner
        angle = i * math.pi / teeth
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=WHITE)
    # Center hole
    hole = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(hole)
    md.ellipse([(cx - 32, cy - 32), (cx + 32, cy + 32)], fill=255)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(transparent, (0, 0), hole)
    return img


def x_mark() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    draw.line([(64, 64), (192, 192)], fill=WHITE, width=28)
    draw.line([(192, 64), (64, 192)], fill=WHITE, width=28)
    return img


def health_potion() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Bottle body
    draw.rounded_rectangle([(76, 100), (180, 232)], radius=24, fill=WHITE)
    # Neck
    draw.rectangle([(108, 60), (148, 100)], fill=WHITE)
    # Cap
    draw.rounded_rectangle([(96, 32), (160, 70)], radius=8, fill=WHITE)
    # Cross cutout
    cut = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(cut)
    md.rectangle([(120, 138), (136, 210)], fill=255)
    md.rectangle([(96, 162), (160, 178)], fill=255)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(transparent, (0, 0), cut)
    return img


def diamond_sword() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Vertical sword
    draw.polygon([(122, 16), (134, 16), (134, 196), (122, 196)], fill=WHITE)
    draw.polygon([(96, 196), (160, 196), (148, 220), (108, 220)], fill=WHITE)
    draw.polygon([(120, 220), (136, 220), (136, 244), (120, 244)], fill=WHITE)
    # Diamond accent
    draw.polygon([(128, 56), (148, 86), (128, 116), (108, 86)], fill=(0, 0, 0, 0))
    return img


def shield_item() -> Image.Image:
    return shield()


def speed_boost() -> Image.Image:
    return zap()


def armor() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Chestplate
    draw.polygon(
        [(72, 60), (184, 60), (200, 100), (180, 220), (76, 220), (56, 100)],
        fill=WHITE,
    )
    # Neck cutout
    cut = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(cut)
    md.polygon([(108, 60), (148, 60), (140, 96), (116, 96)], fill=255)
    transparent = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    img.paste(transparent, (0, 0), cut)
    return img


def magic_staff() -> Image.Image:
    img = new_canvas()
    draw = ImageDraw.Draw(img)
    # Staff
    draw.polygon([(110, 230), (140, 60), (158, 60), (128, 230)], fill=WHITE)
    # Crystal
    draw.polygon([(128, 16), (170, 60), (128, 96), (86, 60)], fill=WHITE)
    return img


ICONS = {
    "Heart": heart,
    "Zap": zap,
    "Award": award,
    "Coins": coins,
    "Star": star,
    "Swords": swords,
    "Shield": shield,
    "Backpack": backpack,
    "Map": map_icon,
    "Users": users,
    "Settings": settings,
    "X": x_mark,
    "HealthPotion": health_potion,
    "DiamondSword": diamond_sword,
    "ShieldItem": shield_item,
    "SpeedBoost": speed_boost,
    "Armor": armor,
    "MagicStaff": magic_staff,
}


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, fn in ICONS.items():
        img = fn()
        save(img, name)
        print(f"wrote {OUT_DIR / (name + '.png')}")


if __name__ == "__main__":
    main()
