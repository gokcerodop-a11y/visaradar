#!/usr/bin/env python3
"""Google Play feature graphic (1024x500) — indigo/amber gradient + app icon.
Mirrors the passport-stamp icon palette (tool/gen_icon.py) so Play and App Store
listings look like the same product."""
from PIL import Image, ImageDraw, ImageFont
import os

INDIGO_DARK = (16, 20, 58)
INDIGO = (46, 41, 122)
AMBER = (245, 166, 35)
WHITE = (237, 242, 255)
W, H = 1024, 500

img = Image.new("RGB", (W, H), INDIGO)
px = img.load()
for y in range(H):
    for x in range(W):
        t = (x + y) / (W + H)
        r = int(INDIGO_DARK[0] + (INDIGO[0] - INDIGO_DARK[0]) * t)
        g = int(INDIGO_DARK[1] + (INDIGO[1] - INDIGO_DARK[1]) * t)
        b = int(INDIGO_DARK[2] + (INDIGO[2] - INDIGO_DARK[2]) * t)
        px[x, y] = (r, g, b)

d = ImageDraw.Draw(img)


def font(sz):
    for p in ["/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, sz)
            except Exception:
                pass
    return ImageFont.load_default()


icon = Image.open(
    os.path.dirname(__file__) + "/../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
).convert("RGBA")
icon_size = 380
icon = icon.resize((icon_size, icon_size), Image.LANCZOS)
img.paste(icon, (60, (H - icon_size) // 2), icon)

title_f = font(56)
sub_f = font(28)
tx = 60 + icon_size + 50
d.text((tx, 175), "VisaRadar", font=title_f, fill=WHITE)
d.text((tx, 245), "Yapay Zekâ Seyahat Asistanı", font=sub_f, fill=AMBER)

img.save(os.path.dirname(__file__) + "/play/assets/feature-graphic-1024x500.png")
print("saved")
