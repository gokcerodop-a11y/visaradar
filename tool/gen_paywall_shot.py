#!/usr/bin/env python3
"""Generate a paywall review screenshot for App Store IAP review.
Mirrors the in-app paywall: dark theme, 3 plans, prices, Most Popular badge."""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1242, 2208
NAVY = (11, 17, 32)
CARD = (28, 42, 63)
TEAL = (0, 212, 170)
INFO = (59, 130, 246)
WHITE = (237, 242, 255)
GREY = (143, 163, 191)

img = Image.new("RGB", (W, H), NAVY)
d = ImageDraw.Draw(img)


def font(sz, bold=True):
    paths = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def center(txt, y, f, fill):
    w = d.textlength(txt, font=f)
    d.text(((W - w) / 2, y), txt, font=f, fill=fill)


# Header — real app icon
icon_path = os.path.abspath(os.path.dirname(__file__) + "/../assets/icons/app_icon.png")
if os.path.exists(icon_path):
    ic = Image.open(icon_path).convert("RGB").resize((150, 150), Image.LANCZOS)
    mask = Image.new("L", (150, 150), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 150, 150], 34, fill=255)
    img.paste(ic, (int(W/2-75), 150), mask)
center("VisaRadar Premium", 330, font(70), WHITE)
center("Unlock the AI assistant, scanner & border mode", 430, font(34, False), GREY)

# Benefits
benefits = [
    "Unlimited AI travel assistant",
    "Passport & visa document scanner",
    "Automatic border mode",
    "Smart tips for your travel style",
]
y = 540
for b in benefits:
    d.ellipse([110, y+4, 152, y+46], fill=TEAL)
    # checkmark drawn with two line segments
    d.line([(122, y+26), (130, y+35), (143, y+15)], fill=NAVY, width=5, joint="curve")
    d.text((180, y), b, font=font(38, False), fill=WHITE)
    y += 90

# Plan cards
plans = [
    ("Monthly", "Renews monthly", "$4.99", False),
    ("Annual", "3-day free trial · best value", "$34.99", True),
    ("Lifetime", "One-time payment", "$59.99", False),
]
y = 980
for title, sub, price, popular in plans:
    border = TEAL if popular else (36, 48, 71)
    d.rounded_rectangle([90, y, W-90, y+170], 24, fill=CARD,
                        outline=border, width=4 if popular else 2)
    d.text((140, y+45), title, font=font(46), fill=WHITE)
    d.text((140, y+105), sub, font=font(30, False), fill=GREY)
    pw = d.textlength(price, font=font(48))
    d.text((W-140-pw, y+58), price, font=font(48), fill=WHITE)
    if popular:
        bf = font(24)
        label = "MOST POPULAR"
        bw = d.textlength(label, font=bf)
        d.rounded_rectangle([330, y+42, 330 + bw + 44, y+90], 12, fill=TEAL)
        d.text((352, y+52), label, font=bf, fill=NAVY)
    y += 200

# CTA
d.rounded_rectangle([90, y+30, W-90, y+150], 28, fill=TEAL)
center("Continue", y+62, font(46), NAVY)
center("Auto-renews · cancel anytime in the App Store",
       y+185, font(26, False), GREY)

dest = os.path.abspath(os.path.dirname(__file__) + "/../docs/iap_review_shot.png")
os.makedirs(os.path.dirname(dest), exist_ok=True)
img.save(dest, "PNG")
print("wrote", dest, img.size)
