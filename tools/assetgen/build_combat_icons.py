#!/usr/bin/env python3
"""Draws the combat HUD / menu icons (192x192 white glyphs with a soft shadow, matching the existing icon set).
Glyphs are drawn at 4x on an alpha mask, then downsampled. Deterministic; run:  python3 tools/assetgen/build_combat_icons.py"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "icons")
S = 768  # supersampled canvas
FINAL = 192


class Canvas:
    def __init__(self):
        self.img = Image.new("L", (S, S), 0)
        self.d = ImageDraw.Draw(self.img)

    def u(self, v):
        return v * S

    def pts(self, points):
        return [(x * S, y * S) for x, y in points]

    def poly(self, points, fill=255):
        self.d.polygon(self.pts(points), fill=fill)

    def rect(self, x0, y0, x1, y1, r=0.0, fill=255):
        if r > 0:
            self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill)
        else:
            self.d.rectangle([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill)

    def ellipse(self, cx, cy, rx, ry=None, fill=255):
        ry = rx if ry is None else ry
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill)

    def line(self, x0, y0, x1, y1, w, fill=255):
        self.d.line([(x0 * S, y0 * S), (x1 * S, y1 * S)], fill=fill, width=int(w * S))
        r = w * S / 2
        for x, y in ((x0, y0), (x1, y1)):
            self.d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=fill)

    def arc(self, cx, cy, r, a0, a1, w, fill=255):
        self.d.arc([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=fill, width=int(w * S))

    def ring(self, cx, cy, r, w, fill=255):
        self.ellipse(cx, cy, r, fill=fill)
        self.ellipse(cx, cy, r - w, fill=0)

    def save(self, name):
        small = self.img.resize((FINAL, FINAL), Image.LANCZOS)
        shadow = small.filter(ImageFilter.GaussianBlur(3.2)).point(lambda v: int(v * 0.42))
        shifted = Image.new("L", (FINAL, FINAL), 0)
        shifted.paste(shadow, (0, 5))
        out = Image.new("RGBA", (FINAL, FINAL), (0, 0, 0, 0))
        out.alpha_composite(Image.merge("RGBA", (Image.new("L", (FINAL, FINAL), 22), Image.new("L", (FINAL, FINAL), 34), Image.new("L", (FINAL, FINAL), 92), shifted)))
        out.alpha_composite(Image.merge("RGBA", (Image.new("L", (FINAL, FINAL), 255), Image.new("L", (FINAL, FINAL), 255), Image.new("L", (FINAL, FINAL), 255), small)))
        out.save(os.path.join(OUT, name + ".png"))


def rot(points, deg, cx=0.5, cy=0.5):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


def arrow_head(cv, x, y, angle_deg, size=0.11):
    a = math.radians(angle_deg)
    tip = (x + math.cos(a) * size, y + math.sin(a) * size)
    left = (x + math.cos(a + 2.3) * size, y + math.sin(a + 2.3) * size)
    right = (x + math.cos(a - 2.3) * size, y + math.sin(a - 2.3) * size)
    cv.poly([tip, left, right])


# ------------------------------------------------------------------------------------------------ action icons
def attack():
    c = Canvas()
    c.rect(0.28, 0.40, 0.72, 0.80, 0.09)
    for x, y in ((0.335, 0.40), (0.445, 0.36), (0.555, 0.36), (0.665, 0.40)):
        c.ellipse(x, y, 0.062)
    c.poly([(0.22, 0.52), (0.30, 0.45), (0.37, 0.62), (0.30, 0.72)])
    c.rect(0.36, 0.78, 0.64, 0.92, 0.04)
    for x in (0.39, 0.5, 0.61):
        c.line(x, 0.40, x, 0.54, 0.014, 0)
    for dx, dy in ((0.0, -0.12), (0.12, -0.08), (-0.12, -0.08)):
        c.line(0.5 + dx * 0.9, 0.2 + dy * 0.2, 0.5 + dx * 1.3, 0.12 + dy * 0.6, 0.03)
    return c


def dodge():
    c = Canvas()
    c.arc(0.5, 0.5, 0.30, 40, 320, 0.10)
    end = math.radians(320)
    arrow_head(c, 0.5 + math.cos(end) * 0.30, 0.5 + math.sin(end) * 0.30, 320 + 90 - 180 + 180, 0.15)
    c.ellipse(0.5, 0.5, 0.07)
    return c


def crush():
    c = Canvas()
    pts = []
    for i in range(24):
        r = 0.44 if i % 2 == 0 else 0.22
        a = math.pi * 2 * i / 24 - math.pi / 2
        pts.append((0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
    c.poly(pts)
    c.ellipse(0.5, 0.5, 0.12, fill=0)
    c.ellipse(0.5, 0.5, 0.06)
    return c


def grenade():
    c = Canvas()
    c.ellipse(0.5, 0.60, 0.25, 0.28)
    c.rect(0.43, 0.20, 0.57, 0.36, 0.03)
    c.poly([(0.55, 0.22), (0.80, 0.30), (0.78, 0.37), (0.55, 0.31)])
    c.ring(0.74, 0.18, 0.09, 0.03)
    for y in (0.5, 0.6, 0.7):
        c.line(0.30, y, 0.70, y, 0.016, 0)
    c.line(0.5, 0.40, 0.5, 0.84, 0.016, 0)
    return c


def reload():
    c = Canvas()
    c.arc(0.5, 0.5, 0.28, 205, 335, 0.09)
    e1 = math.radians(335)
    arrow_head(c, 0.5 + math.cos(e1) * 0.28, 0.5 + math.sin(e1) * 0.28, 335 + 100, 0.13)
    c.arc(0.5, 0.5, 0.28, 25, 155, 0.09)
    e2 = math.radians(155)
    arrow_head(c, 0.5 + math.cos(e2) * 0.28, 0.5 + math.sin(e2) * 0.28, 155 + 100, 0.13)
    return c


def swap():
    c = Canvas()
    c.line(0.18, 0.36, 0.70, 0.36, 0.09)
    c.poly([(0.84, 0.36), (0.64, 0.20), (0.64, 0.52)])
    c.line(0.82, 0.66, 0.30, 0.66, 0.09)
    c.poly([(0.16, 0.66), (0.36, 0.50), (0.36, 0.82)])
    return c


def pause():
    c = Canvas()
    c.rect(0.28, 0.2, 0.43, 0.8, 0.04)
    c.rect(0.57, 0.2, 0.72, 0.8, 0.04)
    return c


def heart():
    c = Canvas()
    c.ellipse(0.35, 0.38, 0.19)
    c.ellipse(0.65, 0.38, 0.19)
    c.poly([(0.17, 0.46), (0.83, 0.46), (0.5, 0.86)])
    c.poly([(0.30, 0.40), (0.70, 0.40), (0.5, 0.60)])
    return c


def shield():
    c = Canvas()
    outer = [(0.2, 0.2), (0.5, 0.1), (0.8, 0.2), (0.8, 0.52), (0.5, 0.9), (0.2, 0.52)]
    c.poly(outer)
    inner = [(0.5 + (x - 0.5) * 0.7, 0.5 + (y - 0.5) * 0.7) for x, y in outer]
    c.poly(inner, 0)
    c.poly([(0.5 + (x - 0.5) * 0.42, 0.5 + (y - 0.5) * 0.42) for x, y in outer])
    return c


def flag():
    c = Canvas()
    c.rect(0.24, 0.10, 0.31, 0.90, 0.02)
    c.poly([(0.31, 0.14), (0.58, 0.20), (0.80, 0.16), (0.74, 0.32), (0.80, 0.48), (0.58, 0.52), (0.31, 0.46)])
    c.ellipse(0.275, 0.9, 0.12, 0.04)
    return c


def crown():
    c = Canvas()
    c.poly([(0.14, 0.72), (0.14, 0.34), (0.33, 0.54), (0.5, 0.24), (0.67, 0.54), (0.86, 0.34), (0.86, 0.72)])
    c.rect(0.14, 0.72, 0.86, 0.84, 0.03)
    for x, y in ((0.14, 0.32), (0.5, 0.20), (0.86, 0.32)):
        c.ellipse(x, y, 0.055)
    return c


def supply():
    c = Canvas()
    c.d.pieslice([0.16 * S, 0.06 * S, 0.84 * S, 0.78 * S], 180, 360, fill=255)
    for x in (0.34, 0.5, 0.66):
        c.line(x, 0.14, x, 0.42, 0.014, 0)
    c.line(0.18, 0.42, 0.42, 0.70, 0.02)
    c.line(0.5, 0.42, 0.5, 0.70, 0.02)
    c.line(0.82, 0.42, 0.58, 0.70, 0.02)
    c.rect(0.36, 0.68, 0.64, 0.90, 0.03)
    c.line(0.36, 0.79, 0.64, 0.79, 0.016, 0)
    return c


def rocket():
    c = Canvas()
    body = [(0.5, 0.06), (0.63, 0.30), (0.63, 0.68), (0.37, 0.68), (0.37, 0.30)]
    c.poly(rot(body, 35))
    c.poly(rot([(0.37, 0.55), (0.2, 0.82), (0.37, 0.76)], 35))
    c.poly(rot([(0.63, 0.55), (0.8, 0.82), (0.63, 0.76)], 35))
    c.poly(rot([(0.44, 0.7), (0.5, 0.95), (0.56, 0.7)], 35))
    wx, wy = rot([(0.5, 0.34)], 35)[0]
    c.ellipse(wx, wy, 0.055, fill=0)
    return c


def drone():
    c = Canvas()
    c.ellipse(0.5, 0.5, 0.14, 0.10)
    for x, y in ((0.2, 0.3), (0.8, 0.3), (0.2, 0.7), (0.8, 0.7)):
        c.line(0.5, 0.5, x, y, 0.04)
        c.ellipse(x, y, 0.13, 0.04)
        c.ellipse(x, y, 0.025, fill=0)
    c.ellipse(0.5, 0.52, 0.045, fill=0)
    return c


def ammo():
    c = Canvas()
    for x in (0.30, 0.50, 0.70):
        c.rect(x - 0.075, 0.40, x + 0.075, 0.82, 0.02)
        c.d.pieslice([(x - 0.075) * S, 0.14 * S, (x + 0.075) * S, 0.66 * S], 180, 360, fill=255)
        c.line(x - 0.075, 0.74, x + 0.075, 0.74, 0.016, 0)
    return c


def trophy():
    c = Canvas()
    c.poly([(0.28, 0.18), (0.72, 0.18), (0.68, 0.46), (0.5, 0.62), (0.32, 0.46)])
    c.arc(0.27, 0.34, 0.12, 90, 270, 0.045)
    c.arc(0.73, 0.34, 0.12, 270, 450, 0.045)
    c.rect(0.46, 0.60, 0.54, 0.76)
    c.rect(0.33, 0.76, 0.67, 0.88, 0.03)
    return c


def bolt():
    c = Canvas()
    c.poly([(0.60, 0.08), (0.28, 0.56), (0.46, 0.56), (0.38, 0.92), (0.74, 0.40), (0.54, 0.40)])
    return c


def target():
    c = Canvas()
    c.ring(0.5, 0.5, 0.34, 0.06)
    c.ellipse(0.5, 0.5, 0.06)
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        c.line(0.5 + dx * 0.20, 0.5 + dy * 0.20, 0.5 + dx * 0.46, 0.5 + dy * 0.46, 0.05)
    return c


# ------------------------------------------------------------------------------------------------ weapons (side view, muzzle to the right)
def wpn_pistol():
    c = Canvas()
    c.rect(0.18, 0.34, 0.84, 0.52, 0.03)
    c.poly([(0.36, 0.52), (0.55, 0.52), (0.48, 0.82), (0.30, 0.82)])
    c.arc(0.58, 0.58, 0.07, 0, 180, 0.03)
    c.rect(0.22, 0.30, 0.30, 0.36)
    return c


def wpn_smg():
    c = Canvas()
    c.rect(0.14, 0.36, 0.80, 0.54, 0.03)
    c.rect(0.80, 0.41, 0.94, 0.48)
    c.rect(0.44, 0.54, 0.54, 0.84, 0.02)
    c.poly([(0.24, 0.54), (0.36, 0.54), (0.32, 0.80), (0.22, 0.80)])
    c.rect(0.02, 0.38, 0.16, 0.50, 0.02)
    return c


def wpn_rifle():
    c = Canvas()
    c.rect(0.14, 0.40, 0.76, 0.54, 0.03)
    c.rect(0.76, 0.44, 0.97, 0.49)
    c.poly([(0.0, 0.38), (0.16, 0.40), (0.16, 0.58), (0.04, 0.62)])
    c.poly([(0.42, 0.54), (0.54, 0.54), (0.52, 0.82), (0.40, 0.82)])
    c.rect(0.34, 0.31, 0.62, 0.40, 0.02)
    c.poly([(0.24, 0.54), (0.34, 0.54), (0.30, 0.74), (0.22, 0.74)])
    return c


def wpn_shotgun():
    c = Canvas()
    c.rect(0.30, 0.40, 0.97, 0.47)
    c.rect(0.52, 0.47, 0.70, 0.56, 0.03)
    c.rect(0.18, 0.38, 0.42, 0.54, 0.03)
    c.poly([(0.0, 0.42), (0.20, 0.40), (0.20, 0.56), (0.02, 0.64)])
    c.poly([(0.30, 0.54), (0.40, 0.54), (0.36, 0.72), (0.28, 0.72)])
    return c


def wpn_sniper():
    c = Canvas()
    c.rect(0.28, 0.45, 0.98, 0.50)
    c.rect(0.30, 0.28, 0.64, 0.40, 0.04)
    c.rect(0.34, 0.40, 0.38, 0.45)
    c.rect(0.56, 0.40, 0.60, 0.45)
    c.rect(0.12, 0.42, 0.42, 0.56, 0.03)
    c.poly([(0.0, 0.40), (0.14, 0.42), (0.14, 0.62), (0.03, 0.66)])
    c.line(0.78, 0.50, 0.70, 0.74, 0.02)
    c.line(0.78, 0.50, 0.88, 0.74, 0.02)
    return c


def wpn_lmg():
    c = Canvas()
    c.rect(0.12, 0.36, 0.70, 0.54, 0.03)
    c.rect(0.70, 0.40, 0.96, 0.47)
    c.rect(0.70, 0.35, 0.88, 0.52, 0.02)
    c.ellipse(0.46, 0.68, 0.14)
    c.ellipse(0.46, 0.68, 0.06, fill=0)
    c.poly([(0.0, 0.38), (0.14, 0.38), (0.14, 0.56), (0.03, 0.60)])
    c.line(0.84, 0.54, 0.80, 0.74, 0.02)
    return c


def wpn_launcher():
    c = Canvas()
    c.rect(0.10, 0.36, 0.84, 0.52, 0.06)
    c.poly([(0.84, 0.34), (0.96, 0.30), (0.96, 0.58), (0.84, 0.54)])
    c.poly([(0.10, 0.34), (0.0, 0.28), (0.0, 0.60), (0.10, 0.54)])
    c.poly([(0.44, 0.52), (0.56, 0.52), (0.54, 0.76), (0.44, 0.76)])
    c.rect(0.30, 0.26, 0.46, 0.36, 0.02)
    return c


# ------------------------------------------------------------------------------------------------ styles and crush moves
def style_tiger():
    c = Canvas()
    c.ellipse(0.5, 0.64, 0.22, 0.18)
    for x, y, a in ((0.24, 0.42, -20), (0.40, 0.28, -8), (0.60, 0.28, 8), (0.76, 0.42, 20)):
        c.poly(rot([(x - 0.09, y), (x, y - 0.12), (x + 0.09, y), (x, y + 0.10)], a, x, y))
    for x in (0.4, 0.5, 0.6):
        c.line(x, 0.58, x, 0.74, 0.014, 0)
    return c


def style_crane():
    c = Canvas()
    c.ellipse(0.46, 0.58, 0.20, 0.13)
    c.poly([(0.58, 0.52), (0.68, 0.50), (0.74, 0.24), (0.66, 0.22)])
    c.ellipse(0.74, 0.22, 0.055)
    c.poly([(0.76, 0.19), (0.94, 0.25), (0.76, 0.29)])
    c.poly([(0.38, 0.52), (0.08, 0.26), (0.22, 0.58), (0.34, 0.62)])
    c.line(0.44, 0.68, 0.42, 0.92, 0.025)
    c.line(0.52, 0.68, 0.55, 0.92, 0.025)
    c.poly([(0.20, 0.62), (0.06, 0.78), (0.28, 0.66)])
    return c


def style_hawk():
    c = Canvas()
    c.ellipse(0.5, 0.50, 0.085, 0.20)
    c.poly([(0.43, 0.40), (0.06, 0.28), (0.11, 0.44), (0.20, 0.48), (0.24, 0.60), (0.43, 0.62)])
    c.poly([(0.57, 0.40), (0.94, 0.28), (0.89, 0.44), (0.80, 0.48), (0.76, 0.60), (0.57, 0.62)])
    c.poly([(0.44, 0.66), (0.56, 0.66), (0.62, 0.90), (0.38, 0.90)])
    c.poly([(0.46, 0.28), (0.5, 0.16), (0.54, 0.28)])
    return c


def style_turtle():
    c = Canvas()
    c.d.pieslice([0.14 * S, 0.30 * S, 0.86 * S, 0.94 * S], 180, 360, fill=255)
    c.rect(0.14, 0.62, 0.86, 0.72, 0.03)
    for a in (-0.18, 0.0, 0.18):
        c.line(0.5 + a, 0.34, 0.5 + a * 1.8, 0.62, 0.014, 0)
    c.line(0.30, 0.46, 0.70, 0.46, 0.014, 0)
    c.ellipse(0.9, 0.56, 0.075)
    c.rect(0.26, 0.72, 0.38, 0.84, 0.03)
    c.rect(0.62, 0.72, 0.74, 0.84, 0.03)
    c.poly([(0.14, 0.64), (0.04, 0.70), (0.14, 0.72)])
    return c


def crush_quake():
    c = Canvas()
    for r in (0.20, 0.34, 0.48):
        c.arc(0.5, 0.74, r, 180, 360, 0.05)
    c.line(0.08, 0.76, 0.92, 0.76, 0.05)
    c.poly([(0.5, 0.58), (0.40, 0.40), (0.46, 0.40), (0.46, 0.14), (0.54, 0.14), (0.54, 0.40), (0.60, 0.40)])
    c.line(0.28, 0.86, 0.36, 0.80, 0.03)
    c.line(0.72, 0.86, 0.64, 0.80, 0.03)
    return c


def crush_dragon():
    c = Canvas()
    c.line(0.18, 0.82, 0.70, 0.30, 0.10)
    c.poly([(0.86, 0.14), (0.52, 0.22), (0.78, 0.48)])
    for off in (-0.10, 0.0, 0.10):
        c.line(0.10 + off, 0.56 - off * 0.2, 0.34 + off, 0.40, 0.03)
    c.line(0.28, 0.92, 0.48, 0.72, 0.03)
    return c


def crush_storm():
    c = Canvas()
    for ang in (-28, 0, 28):
        bullet = [(0.5 - 0.06, 0.40), (0.5 - 0.06, 0.78), (0.5 + 0.06, 0.78), (0.5 + 0.06, 0.40)]
        c.poly(rot(bullet, ang, 0.5, 0.86))
        tip = [(0.5 - 0.06, 0.40), (0.5, 0.22), (0.5 + 0.06, 0.40)]
        c.poly(rot(tip, ang, 0.5, 0.86))
    for x, y in ((0.14, 0.22), (0.86, 0.22), (0.5, 0.08)):
        c.ellipse(x, y, 0.04)
    return c


ICONS = {
    "attack": attack, "dodge": dodge, "crush": crush, "grenade": grenade, "reload": reload, "swap": swap, "pause": pause,
    "heart": heart, "shield": shield, "flag": flag, "crown": crown, "supply": supply, "rocket": rocket, "drone": drone,
    "ammo": ammo, "trophy": trophy, "bolt": bolt, "target": target,
    "wpn_pistol": wpn_pistol, "wpn_smg": wpn_smg, "wpn_rifle": wpn_rifle, "wpn_shotgun": wpn_shotgun, "wpn_sniper": wpn_sniper,
    "wpn_lmg": wpn_lmg, "wpn_launcher": wpn_launcher,
    "style_tiger": style_tiger, "style_crane": style_crane, "style_hawk": style_hawk, "style_turtle": style_turtle,
    "crush_quake": crush_quake, "crush_dragon": crush_dragon, "crush_storm": crush_storm,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        fn().save(name)
    print("wrote %d icons to %s" % (len(ICONS), OUT))
