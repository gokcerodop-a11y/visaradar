#!/usr/bin/env python3
"""VisaRadar Travel app icon — v2, distinctive passport-stamp mark.

Replaces the generic teal-blue "radar rings + location pin" cliché (shared by
dozens of Schengen/travel-tracker apps and flagged by Apple as template-like,
Guideline 4.3(a), 2026-08-28) with an original passport-stamp + compass-needle
emblem on a deep indigo/amber palette. Rendered at 4x then downscaled to 1024.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

SS = 4
SIZE = 1024
S = SIZE * SS
CX = CY = S / 2

# Distinctive brand palette — deep indigo → violet, warm amber accent.
INDIGO_DARK = (16, 20, 58)     # near-black indigo (top-left)
INDIGO = (46, 41, 122)         # deep violet-indigo (bottom-right)
AMBER = (245, 166, 35)         # warm amber accent (compass needle / stamp ring)
WHITE = (255, 255, 255)

img = Image.new("RGB", (S, S), INDIGO)
px = img.load()


def gradient():
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)
            r = int(INDIGO_DARK[0] + (INDIGO[0] - INDIGO_DARK[0]) * t)
            g = int(INDIGO_DARK[1] + (INDIGO[1] - INDIGO_DARK[1]) * t)
            b = int(INDIGO_DARK[2] + (INDIGO[2] - INDIGO_DARK[2]) * t)
            px[x, y] = (r, g, b)


gradient()
draw = ImageDraw.Draw(img, "RGBA")


def vignette():
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    max_r = S * 0.74
    for i in range(int(max_r), int(S * 0.42), -3):
        t = (i - S * 0.42) / (max_r - S * 0.42)
        a = int(90 * t)
        ld.ellipse([CX - i, CY - i, CX + i, CY + i], outline=(4, 4, 20, a), width=SS * 2)
    img.paste(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"), (0, 0))


def stamp_ring():
    """Perforated passport-stamp ring (double circle, dashed outer edge)."""
    r_outer = S * 0.40
    r_inner = S * 0.345
    draw.ellipse([CX - r_outer, CY - r_outer, CX + r_outer, CY + r_outer],
                 outline=(*WHITE, 235), width=int(S * 0.014))
    draw.ellipse([CX - r_inner, CY - r_inner, CX + r_inner, CY + r_inner],
                 outline=(*WHITE, 150), width=int(S * 0.006))
    # dashed perforation just outside the ring, like an ink stamp
    n = 40
    r_dash = S * 0.435
    dash_len = 0.028
    for i in range(n):
        a0 = (360 / n) * i
        a1 = a0 + dash_len * 180
        draw.arc([CX - r_dash, CY - r_dash, CX + r_dash, CY + r_dash],
                  a0, a1, fill=(*WHITE, 130), width=int(S * 0.010))


def compass_needle():
    """Bold two-tone compass needle — amber north, white south — centred."""
    r = S * 0.30
    pts_n = [(CX, CY - r), (CX - S * 0.045, CY), (CX + S * 0.045, CY)]
    pts_s = [(CX, CY + r), (CX - S * 0.045, CY), (CX + S * 0.045, CY)]
    # shadow
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    off = S * 0.012
    sd.polygon([(x, y + off) for x, y in pts_n], fill=(2, 2, 20, 110))
    sd.polygon([(x, y + off) for x, y in pts_s], fill=(2, 2, 20, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(S * 0.010))
    img.paste(Image.alpha_composite(img.convert("RGBA"), sh).convert("RGB"), (0, 0))

    draw.polygon(pts_n, fill=AMBER)
    draw.polygon(pts_s, fill=WHITE)
    hub_r = S * 0.05
    draw.ellipse([CX - hub_r, CY - hub_r, CX + hub_r, CY + hub_r], fill=WHITE)
    hub_r2 = S * 0.022
    draw.ellipse([CX - hub_r2, CY - hub_r2, CX + hub_r2, CY + hub_r2], fill=INDIGO_DARK)


def ai_spark():
    """Small four-point spark (AI accent) top-right of the ring, like a stamp corner mark."""
    scx = CX + S * 0.285
    scy = CY - S * 0.285
    r_long = S * 0.055
    r_short = S * 0.018
    pts = []
    for i in range(8):
        ang = math.radians(i * 45)
        r = r_long if i % 2 == 0 else r_short
        pts.append((scx + r * math.cos(ang), scy + r * math.sin(ang)))
    draw.polygon(pts, fill=(*AMBER, 235))


vignette()
stamp_ring()
compass_needle()
ai_spark()

import os
out = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
dest = os.path.abspath(os.path.dirname(__file__) + "/../assets/icons/app_icon.png")
os.makedirs(os.path.dirname(dest), exist_ok=True)
out.save(dest, "PNG")
print("wrote", dest)
