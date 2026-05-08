"""Generate placeholder white-on-transparent PNG icons for the HUD.

Each icon is a 256x256 transparent PNG with a white shape. The HUD applies its
own ImageColor3 tint so the silhouette picks up the panel colour at runtime.

Run from the repo root:
    python3 scripts/generate_icons.py
"""

import math
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.stderr.write("PIL/Pillow is required. Install with: pip install Pillow\n")
    sys.exit(1)

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "icons"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SIZE = 256
WHITE = (255, 255, 255, 255)


def new_image() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def save(img: Image.Image, name: str) -> None:
    out = OUT_DIR / f"{name}.png"
    img.save(out)
    print(f"  wrote {out.relative_to(OUT_DIR.parent.parent)}")


def coins() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    d.ellipse((40, 40, 216, 216), outline=WHITE, width=14)
    d.text((110, 92), "$", fill=WHITE)
    # Big dollar sign rendered as path
    d.line((128, 80, 128, 176), fill=WHITE, width=14)
    d.arc((84, 80, 172, 132), 180, 360, fill=WHITE, width=14)
    d.arc((84, 124, 172, 176), 0, 180, fill=WHITE, width=14)
    return img


def star() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    cx, cy, outer, inner = 128, 128, 100, 44
    points = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        r = outer if i % 2 == 0 else inner
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    d.polygon(points, fill=WHITE)
    return img


def award() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    cx, cy = 128, 110
    d.ellipse((cx - 56, cy - 56, cx + 56, cy + 56), outline=WHITE, width=12)
    # Inner star
    pts = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        r = 30 if i % 2 == 0 else 14
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    d.polygon(pts, fill=WHITE)
    # Ribbons
    d.polygon([(cx - 36, cy + 50), (cx - 24, cy + 50), (cx - 18, cy + 110), (cx - 50, cy + 100)], fill=WHITE)
    d.polygon([(cx + 36, cy + 50), (cx + 24, cy + 50), (cx + 18, cy + 110), (cx + 50, cy + 100)], fill=WHITE)
    return img


def swords() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    # Two crossed katanas
    d.polygon([(40, 60), (50, 50), (210, 200), (200, 210)], fill=WHITE)
    d.polygon([(46, 200), (216, 56), (206, 46), (36, 190)], fill=WHITE)
    # Hilts
    d.rectangle((44, 196, 76, 220), fill=WHITE)
    d.rectangle((180, 196, 212, 220), fill=WHITE)
    return img


def backpack() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((58, 68, 198, 220), radius=24, outline=WHITE, width=12)
    d.rounded_rectangle((100, 38, 156, 80), radius=14, outline=WHITE, width=12)
    d.line((60, 130, 196, 130), fill=WHITE, width=10)
    return img


def settings() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    cx, cy, R, r = 128, 128, 90, 38
    teeth = 8
    pts = []
    for i in range(teeth * 2):
        angle = i * math.pi / teeth
        radius = R if i % 2 == 0 else R - 22
        pts.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    d.polygon(pts, fill=WHITE)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(0, 0, 0, 0))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=WHITE, width=10)
    return img


def x_icon() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    d.line((60, 60, 196, 196), fill=WHITE, width=22)
    d.line((196, 60, 60, 196), fill=WHITE, width=22)
    return img


def zap() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    d.polygon([(132, 24), (60, 144), (118, 144), (96, 232), (200, 100), (138, 100)], fill=WHITE)
    return img


def users() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    # Two heads
    d.ellipse((58, 56, 130, 128), fill=WHITE)
    d.ellipse((124, 64, 196, 136), fill=WHITE)
    # Two bodies
    d.rounded_rectangle((40, 138, 148, 226), radius=30, fill=WHITE)
    d.rounded_rectangle((120, 146, 220, 226), radius=30, fill=WHITE)
    return img


def dice() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((48, 48, 208, 208), radius=24, outline=WHITE, width=14)
    pip = 16
    for cx, cy in ((90, 90), (166, 90), (90, 166), (166, 166), (128, 128)):
        d.ellipse((cx - pip, cy - pip, cx + pip, cy + pip), fill=WHITE)
    return img


def lock() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((54, 116, 202, 224), radius=18, outline=WHITE, width=12)
    d.arc((76, 36, 180, 156), start=180, end=360, fill=WHITE, width=14)
    d.ellipse((118, 156, 138, 176), fill=WHITE)
    d.line((128, 170, 128, 200), fill=WHITE, width=10)
    return img


def sparkles() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)

    def burst(cx: int, cy: int, span: int) -> None:
        d.polygon([(cx, cy - span), (cx + span // 3, cy), (cx, cy + span), (cx - span // 3, cy)], fill=WHITE)
        d.polygon([(cx - span, cy), (cx, cy + span // 3), (cx + span, cy), (cx, cy - span // 3)], fill=WHITE)

    burst(128, 128, 80)
    burst(72, 60, 28)
    burst(196, 188, 36)
    return img


def diamond_sword() -> Image.Image:
    img = new_image()
    d = ImageDraw.Draw(img)
    # Blade as elongated diamond
    d.polygon([(128, 16), (170, 144), (128, 168), (86, 144)], fill=WHITE)
    # Crossguard
    d.rectangle((68, 168, 188, 184), fill=WHITE)
    # Hilt
    d.rectangle((118, 184, 138, 230), fill=WHITE)
    # Pommel
    d.ellipse((110, 222, 146, 250), fill=WHITE)
    return img


ICONS = {
    "Coins": coins,
    "Star": star,
    "Award": award,
    "Swords": swords,
    "Backpack": backpack,
    "Settings": settings,
    "X": x_icon,
    "Zap": zap,
    "Users": users,
    "Dice": dice,
    "Lock": lock,
    "Sparkles": sparkles,
    "DiamondSword": diamond_sword,
}


def main() -> int:
    print(f"Generating {len(ICONS)} icons -> {OUT_DIR}")
    for name, fn in ICONS.items():
        save(fn(), name)
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
