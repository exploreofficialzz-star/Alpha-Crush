#!/usr/bin/env python3
"""Draws the picture-first UI icon set used by the kid-friendly HUD (assets/ui/icons/*.png).

The previous SVG "icons" were text labels (<text> is not rendered by Godot's SVG importer), so every
icon here is drawn as real shapes. Two styles:
  * glyph  - white silhouette (button colour comes from the game), soft drop shadow
  * sticker - full colour illustration with a white sticker outline (word goals, coins, gems, faces)
Run:  python3 tools/assetgen/ui_icons.py   (needs Pillow; writes 192x192 RGBA PNGs)
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

S = 4
N = 192
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'assets', 'ui', 'icons'))
FONT = '/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'


class Mask:
    """White-glyph canvas: fill=255 adds, fill=0 erases."""
    def __init__(self):
        self.im = Image.new('L', (N * S, N * S), 0)
        self.d = ImageDraw.Draw(self.im)

    def P(self, pts):
        return [(x * S, y * S) for x, y in pts]

    def rr(self, b, r, fill=255):
        self.d.rounded_rectangle([b[0] * S, b[1] * S, b[2] * S, b[3] * S], radius=r * S, fill=fill)

    def circ(self, cx, cy, r, fill=255):
        self.d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=fill)

    def ell(self, cx, cy, rx, ry, fill=255):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill)

    def poly(self, pts, fill=255):
        self.d.polygon(self.P(pts), fill=fill)

    def line(self, pts, w, fill=255):
        for a, b in zip(pts, pts[1:]):
            self.d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=fill, width=int(w * S))
        for p in pts:
            self.circ(p[0], p[1], w / 2, fill)

    def arc(self, cx, cy, r, a0, a1, w, fill=255):
        self.d.arc([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=fill, width=int(w * S))

    def text(self, xy, s, size, fill=255):
        f = ImageFont.truetype(FONT, int(size * S))
        self.d.text((xy[0] * S, xy[1] * S), s, font=f, fill=fill, anchor='mm')

    def render(self):
        m = self.im.resize((N, N), Image.LANCZOS)
        sh = self.im.filter(ImageFilter.GaussianBlur(2.2 * S)).resize((N, N), Image.LANCZOS)
        sh = shift(sh, 0, 3).point(lambda v: int(v * 0.42))
        out = Image.new('RGBA', (N, N), (0, 0, 0, 0))
        shadow = Image.new('RGBA', (N, N), (10, 20, 50, 0)); shadow.putalpha(sh)
        out.alpha_composite(shadow)
        white = Image.new('RGBA', (N, N), (255, 255, 255, 0)); white.putalpha(m)
        out.alpha_composite(white)
        return out


class Color:
    """Colour sticker canvas with an erase mask."""
    def __init__(self):
        self.im = Image.new('RGBA', (N * S, N * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.er = Image.new('L', (N * S, N * S), 0)
        self.ed = ImageDraw.Draw(self.er)

    def P(self, pts):
        return [(x * S, y * S) for x, y in pts]

    def rr(self, b, r, c, o=None, ow=0):
        self.d.rounded_rectangle([b[0] * S, b[1] * S, b[2] * S, b[3] * S], radius=r * S, fill=c,
                                 outline=o, width=int(ow * S))

    def circ(self, cx, cy, r, c, o=None, ow=0):
        self.d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=c, outline=o, width=int(ow * S))

    def ell(self, cx, cy, rx, ry, c):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=c)

    def poly(self, pts, c, o=None):
        self.d.polygon(self.P(pts), fill=c, outline=o)

    def line(self, pts, w, c):
        for a, b in zip(pts, pts[1:]):
            self.d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=c, width=int(w * S))
        for p in pts:
            self.circ(p[0], p[1], w / 2, c)

    def arc(self, cx, cy, r, a0, a1, w, c):
        self.d.arc([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], a0, a1, fill=c, width=int(w * S))

    def erase_circ(self, cx, cy, r):
        self.ed.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)

    def erase_rr(self, b, r):
        self.ed.rounded_rectangle([b[0] * S, b[1] * S, b[2] * S, b[3] * S], radius=r * S, fill=255)

    def text(self, xy, s, size, c):
        f = ImageFont.truetype(FONT, int(size * S))
        self.d.text((xy[0] * S, xy[1] * S), s, font=f, fill=c, anchor='mm')

    def render(self, sticker=True):
        a = ImageChops.subtract(self.im.split()[3], self.er)
        art = self.im.copy(); art.putalpha(a)
        out = Image.new('RGBA', art.size, (0, 0, 0, 0))
        if sticker:
            halo = a.filter(ImageFilter.GaussianBlur(3.2 * S)).point(lambda v: 255 if v > 24 else 0)
            halo = halo.filter(ImageFilter.GaussianBlur(0.8 * S))
            sh = halo.filter(ImageFilter.GaussianBlur(3 * S)).point(lambda v: int(v * 0.4))
            shadow = Image.new('RGBA', art.size, (10, 20, 50, 0)); shadow.putalpha(shift(sh, 0, 4 * S))
            out.alpha_composite(shadow)
            white = Image.new('RGBA', art.size, (255, 255, 255, 0)); white.putalpha(halo)
            out.alpha_composite(white)
        out.alpha_composite(art)
        return out.resize((N, N), Image.LANCZOS)


def rot(pts, cx, cy, deg):
    a = math.radians(deg); ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in pts]


def rect_poly(cx, cy, w, h, deg):
    pts = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]
    return rot(pts, cx, cy, deg)


def star_pts(cx, cy, ro, ri, n=5, start=-90):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(start + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def shift(img, dx, dy):
    """Translate an image without wrap-around (ImageChops.offset wraps and smears shadows onto the opposite edge)."""
    out = Image.new(img.mode, img.size, 0)
    out.paste(img, (dx, dy))
    return out


ICONS = {}
def icon(fn):
    ICONS[fn.__name__] = fn
    return fn

# ---------------------------------------------------------------- white glyphs
@icon
def hand():
    m = Mask()
    for x, top in ((62, 56), (83, 42), (104, 38), (125, 50)):
        m.rr((x - 8, top, x + 8, 112), 8)
    m.rr((52, 88, 138, 156), 26)
    m.line([(60, 130), (34, 100)], 20)
    return m.render()

@icon
def jump():
    m = Mask()
    m.line([(50, 108), (96, 62), (142, 108)], 24)
    m.line([(50, 150), (96, 104), (142, 150)], 24)
    return m.render()

@icon
def bag():
    m = Mask()
    m.rr((80, 28, 112, 66), 15); m.rr((89, 38, 103, 70), 7, 0)
    m.rr((48, 54, 144, 160), 32)
    m.line([(48, 98), (144, 98)], 6, 0)
    m.rr((66, 112, 126, 148), 14, 0); m.rr((73, 119, 119, 141), 9)
    return m.render()

@icon
def map():
    m = Mask()
    m.poly([(26, 62), (64, 48), (64, 148), (26, 162)])
    m.poly([(71, 48), (121, 64), (121, 164), (71, 148)])
    m.poly([(128, 64), (166, 50), (166, 150), (128, 164)])
    m.circ(96, 82, 36, 0)
    m.poly([(68, 94), (124, 94), (96, 140)], 0)
    m.circ(96, 82, 29); m.poly([(72, 94), (120, 94), (96, 134)]); m.circ(96, 82, 11, 0)
    return m.render()

@icon
def bulb():
    m = Mask()
    m.circ(96, 78, 40)
    m.poly([(70, 106), (122, 106), (114, 130), (78, 130)])
    m.rr((76, 132, 116, 146), 7)
    m.rr((84, 148, 108, 160), 6)
    m.line([(82, 70), (89, 86), (96, 70), (103, 86), (110, 70)], 5, 0)
    for a in (-90, -50, -130, -10, -170):
        r0, r1 = 52, 68
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        m.line([(96 + r0 * ca, 78 + r0 * sa), (96 + r1 * ca, 78 + r1 * sa)], 8)
    return m.render()

@icon
def gear():
    m = Mask()
    m.circ(96, 96, 46)
    for i in range(8):
        a = i * 45
        m.poly(rect_poly(96 + 56 * math.cos(math.radians(a)), 96 + 56 * math.sin(math.radians(a)), 26, 28, a))
    m.circ(96, 96, 19, 0)
    return m.render()

@icon
def star():
    m = Mask()
    m.poly(star_pts(96, 100, 66, 29))
    m.line(star_pts(96, 100, 56, 24) + [star_pts(96, 100, 56, 24)[0]], 12)
    return m.render()

@icon
def hammer():
    m = Mask()
    m.line([(54, 150), (112, 80)], 20)
    m.poly(rect_poly(122, 66, 70, 34, 38))
    m.poly(rot([(80, 54), (96, 40), (110, 56), (96, 70)], 122, 66, 38))
    return m.render()

@icon
def close():
    m = Mask()
    m.line([(54, 54), (138, 138)], 24)
    m.line([(138, 54), (54, 138)], 24)
    return m.render()

@icon
def check():
    m = Mask()
    m.line([(46, 100), (82, 136), (146, 62)], 28)
    return m.render()

@icon
def lock():
    m = Mask()
    m.rr((64, 28, 128, 112), 30); m.rr((80, 44, 112, 112), 14, 0)
    m.rr((48, 84, 144, 160), 20)
    m.circ(96, 116, 10, 0); m.rr((91, 118, 101, 140), 4, 0)
    return m.render()

@icon
def play():
    m = Mask()
    pts = [(64, 42), (64, 150), (152, 96)]
    m.poly(pts); m.line(pts + [pts[0]], 18)
    return m.render()

@icon
def home():
    m = Mask()
    m.poly([(24, 100), (96, 36), (168, 100)]); m.line([(24, 100), (96, 36), (168, 100)], 14)
    m.rr((46, 92, 146, 158), 8); m.rr((80, 110, 112, 158), 10, 0)
    return m.render()

@icon
def back():
    m = Mask()
    m.line([(122, 40), (66, 96), (122, 152)], 26)
    return m.render()

@icon
def music():
    m = Mask()
    m.ell(66, 142, 24, 18); m.ell(130, 126, 24, 18)
    m.rr((80, 48, 94, 142), 6); m.rr((144, 32, 158, 126), 6)
    m.poly([(80, 46), (158, 28), (158, 56), (80, 74)])
    return m.render()

def _speaker(m, waves=True):
    m.poly([(34, 74), (66, 74), (108, 40), (108, 152), (66, 118), (34, 118)])
    m.line([(34, 74), (66, 74), (34, 118)], 6)
    if waves:
        m.arc(108, 96, 34, -48, 48, 13); m.arc(108, 96, 58, -45, 45, 13)

@icon
def sound():
    m = Mask(); _speaker(m); return m.render()

@icon
def vibrate():
    m = Mask()
    m.rr((68, 30, 124, 162), 14); m.rr((78, 46, 114, 134), 6, 0); m.circ(96, 148, 5, 0)
    m.arc(96, 96, 50, 150, 210, 11); m.arc(96, 96, 70, 155, 205, 11)
    m.arc(96, 96, 50, -30, 30, 11); m.arc(96, 96, 70, -25, 25, 11)
    return m.render()

@icon
def contrast():
    m = Mask()
    m.circ(96, 96, 62); m.circ(96, 96, 48, 0)
    m.d.pieslice([(96 - 48) * S, (96 - 48) * S, (96 + 48) * S, (96 + 48) * S], -90, 90, fill=255)
    return m.render()

@icon
def text_size():
    m = Mask()
    m.text((64, 100), 'A', 104); m.text((134, 126), 'a', 70)
    return m.render()

def _bars(n):
    m = Mask()
    for i, (x, h) in enumerate(((40, 44), (82, 78), (124, 112))):
        box = (x, 156 - h, x + 30, 156)
        m.rr(box, 8)
        if i >= n:
            m.rr((box[0] + 8, box[1] + 8, box[2] - 8, box[3] - 8), 3, 0)
    return m.render()

@icon
def bars1(): return _bars(1)
@icon
def bars2(): return _bars(2)
@icon
def bars3(): return _bars(3)

@icon
def drop():
    m = Mask()
    m.line([(96, 28), (96, 104)], 26)
    m.line([(54, 74), (96, 116), (138, 74)], 26)
    m.rr((40, 142, 152, 158), 8)
    return m.render()

@icon
def sparkle():
    m = Mask()
    m.poly([(96, 22), (112, 80), (170, 96), (112, 112), (96, 170), (80, 112), (22, 96), (80, 80)])
    m.circ(150, 44, 12); m.circ(44, 146, 9)
    return m.render()

@icon
def people():
    m = Mask()
    for cx, cy, s in ((60, 108, 0.86), (132, 108, 0.86), (96, 96, 1.0)):
        m.circ(cx, cy - 30 * s, 20 * s)
        m.rr((cx - 28 * s, cy - 6 * s, cx + 28 * s, cy + 50 * s), 22 * s)
    return m.render()

@icon
def pointer():
    """Tutorial pointing hand (cursor style, tilted) with a dark outline so it reads on any background."""
    m = Mask()
    m.rr((60, 14, 86, 116), 13)                       # index finger (left of centre, not the tallest-centre finger)
    m.rr((50, 92, 152, 168), 28)                      # palm
    m.circ(100, 100, 13); m.circ(118, 104, 13); m.circ(134, 112, 12)   # curled fingers
    m.line([(62, 142), (36, 116)], 19)                # thumb
    base = m.im.rotate(14, resample=Image.BICUBIC, center=(96 * S, 120 * S))
    dil = base.filter(ImageFilter.GaussianBlur(3.4 * S)).point(lambda v: 255 if v > 30 else 0).filter(ImageFilter.GaussianBlur(0.8 * S))
    out = Image.new('RGBA', base.size, (0, 0, 0, 0))
    dark = Image.new('RGBA', base.size, (22, 36, 78, 0)); dark.putalpha(dil)
    out.alpha_composite(dark)
    white = Image.new('RGBA', base.size, (255, 255, 255, 0)); white.putalpha(base)
    out.alpha_composite(white)
    crease = Image.new('RGBA', base.size, (0, 0, 0, 0)); cd = ImageDraw.Draw(crease)
    for (x0, y0, x1, y1) in ((109, 104, 109, 126), (126, 108, 126, 128), (86, 112, 86, 132)):
        cd.line([(x0 * S, y0 * S), (x1 * S, y1 * S)], fill=(176, 194, 232, 255), width=3 * S)
    crease = crease.rotate(14, resample=Image.BICUBIC, center=(96 * S, 120 * S))
    out.alpha_composite(crease)
    return out.resize((N, N), Image.LANCZOS)

# ---------------------------------------------------------------- colour stickers
GOLD = (255, 200, 61, 255); GOLD_D = (214, 140, 20, 255); GOLD_L = (255, 226, 130, 255)
GREEN = (84, 190, 84, 255); GREEN_D = (46, 140, 62, 255)
BROWN = (176, 112, 54, 255); BROWN_D = (120, 72, 30, 255); BROWN_L = (212, 150, 84, 255)
RED = (232, 70, 64, 255); BLUE = (62, 140, 240, 255); BLUE_D = (36, 92, 190, 255)
GRAY = (170, 182, 198, 255); GRAY_D = (110, 124, 144, 255); CREAM = (255, 244, 220, 255)
ORANGE = (255, 150, 28, 255); PURPLE = (150, 90, 230, 255); PINK = (255, 120, 170, 255)


@icon
def coin():
    c = Color()
    c.circ(96, 98, 62, GOLD_D); c.circ(96, 94, 58, GOLD); c.circ(96, 94, 42, GOLD_L)
    c.poly(star_pts(96, 96, 28, 12), GOLD_D)
    c.arc(96, 94, 50, 200, 260, 6, (255, 255, 255, 200))
    return c.render()

@icon
def gem():
    c = Color()
    c.poly([(40, 76), (68, 36), (124, 36), (152, 76)], (170, 120, 255, 255))
    c.poly([(40, 76), (152, 76), (96, 158)], PURPLE)
    c.poly([(68, 36), (96, 76), (40, 76)], (196, 160, 255, 255))
    c.poly([(124, 36), (152, 76), (96, 76)], (120, 70, 210, 255))
    c.poly([(96, 76), (152, 76), (96, 158)], (110, 60, 196, 255))
    c.line([(60, 56), (76, 48)], 6, (255, 255, 255, 230))
    return c.render()

@icon
def star_gold():
    c = Color()
    c.poly(star_pts(96, 100, 70, 31), GOLD_D)
    c.poly(star_pts(96, 98, 62, 27), GOLD)
    c.poly(star_pts(96, 98, 34, 15), GOLD_L)
    return c.render()

@icon
def orange():
    c = Color()
    c.circ(96, 108, 56, (236, 118, 10, 255)); c.circ(96, 104, 52, ORANGE)
    c.arc(96, 104, 40, 195, 255, 8, (255, 214, 140, 230))
    c.rr((92, 36, 100, 56), 4, BROWN_D)
    c.poly([(98, 48), (136, 30), (128, 62)], GREEN); c.poly([(98, 48), (128, 62), (104, 66)], GREEN_D)
    return c.render()

@icon
def basket():
    c = Color()
    c.arc(96, 78, 52, 180, 360, 12, BROWN_D)
    c.circ(74, 74, 22, ORANGE); c.circ(112, 68, 22, (240, 90, 60, 255)); c.circ(94, 86, 22, (255, 190, 40, 255))
    c.poly([(36, 84), (156, 84), (140, 158), (52, 158)], BROWN)
    c.rr((30, 76, 162, 98), 10, BROWN_L)
    for x in (66, 96, 126):
        c.line([(x - 6, 100), (x - 10 + (x - 96) * 0.15, 154)], 5, BROWN_D)
    c.line([(46, 124), (146, 124)], 5, BROWN_D)
    return c.render()

@icon
def wheat():
    c = Color()
    for dx, tilt in ((-34, -14), (0, 0), (34, 14)):
        pts = rot([(96 + dx * 0.2, 166), (96 + dx * 0.2, 56)], 96, 166, tilt)
        c.line(pts, 6, (120, 150, 60, 255))
        tx, ty = pts[1]
        for k in range(4):
            y = ty + 8 + k * 14
            px, py = rot([(96 + dx * 0.2, y)], 96, 166, tilt)[0]
            c.line([(px - 2, py), (px - 12, py - 13)], 11, GOLD)
            c.line([(px + 2, py), (px + 12, py - 13)], 11, GOLD)
        c.line([(tx, ty - 6), (tx, ty - 22)], 11, GOLD)
    c.rr((54, 140, 138, 156), 7, RED)
    return c.render()

@icon
def seeds():
    c = Color()
    c.ell(96, 150, 62, 22, BROWN_D); c.ell(96, 144, 58, 18, BROWN)
    c.line([(96, 144), (96, 86)], 9, GREEN_D)
    c.poly([(96, 96), (44, 70), (50, 104)], GREEN); c.poly([(96, 90), (150, 52), (146, 92)], (120, 214, 90, 255))
    c.ell(70, 138, 7, 5, CREAM)
    return c.render()

@icon
def ladder():
    c = Color()
    for x in (60, 116):
        c.poly([(x - 8, 24), (x + 10, 24), (x + 14, 170), (x - 4, 170)], BROWN_D)
        c.poly([(x - 4, 24), (x + 6, 24), (x + 8, 170), (x - 2, 170)], BROWN_L)
    for y in (46, 80, 114, 148):
        c.rr((52, y - 7, 140, y + 7), 6, BROWN, BROWN_D, 2)
    return c.render()

@icon
def market():
    c = Color()
    for i in range(6):
        x0 = 26 + i * 23
        c.poly([(x0, 40), (x0 + 23, 40), (x0 + 28, 84), (x0 - 5, 84)], RED if i % 2 == 0 else CREAM)
        c.circ(x0 + 11.5, 84, 12, RED if i % 2 == 0 else CREAM)
    c.rr((36, 96, 156, 158), 8, BROWN, BROWN_D, 3)
    c.rr((28, 92, 164, 108), 6, BROWN_L)
    c.circ(66, 84 + 40, 14, ORANGE); c.circ(96, 128, 14, (240, 90, 60, 255)); c.circ(126, 124, 14, (255, 190, 40, 255))
    return c.render()

@icon
def bridge():
    c = Color()
    c.rr((20, 92, 172, 152), 10, GRAY, GRAY_D, 3)
    c.d.pieslice([(96 - 36) * S, (152 - 44) * S, (96 + 36) * S, (152 + 44) * S], 180, 360, fill=BLUE_D)
    c.ell(96, 154, 76, 12, BLUE)
    c.rr((12, 74, 180, 98), 7, BROWN, BROWN_D, 3)
    for x in (30, 66, 102, 138, 162):
        c.rr((x - 5, 48, x + 5, 76), 4, BROWN_D)
    c.rr((20, 46, 172, 57), 5, BROWN_L)
    return c.render()

@icon
def wrench():
    c = Color()
    c.line([(60, 150), (118, 78)], 24, GRAY_D)
    c.line([(60, 150), (118, 78)], 14, GRAY)
    c.circ(128, 66, 36, GRAY_D); c.circ(128, 66, 30, GRAY)
    c.erase_rr((114, 20, 142, 62), 8)
    c.line([(60, 150), (118, 78)], 14, GRAY)
    return c.render()

@icon
def tools():
    c = Color()
    c.line([(52, 150), (120, 70)], 16, BROWN)
    c.poly(rect_poly(128, 62, 64, 30, 40), GRAY_D); c.poly(rect_poly(128, 62, 56, 22, 40), GRAY)
    c.line([(140, 150), (72, 70)], 14, GRAY_D); c.line([(140, 150), (72, 70)], 8, GRAY)
    c.circ(66, 62, 24, GRAY_D); c.circ(66, 62, 18, GRAY); c.erase_rr((58, 34, 74, 56), 5)
    return c.render()

@icon
def lantern():
    c = Color()
    c.arc(96, 40, 20, 180, 360, 7, GRAY_D)
    c.rr((68, 44, 124, 62), 8, GRAY_D)
    c.rr((60, 60, 132, 146), 22, (255, 214, 90, 255), GRAY_D, 5)
    c.circ(96, 104, 24, (255, 244, 190, 255))
    c.line([(96, 62), (96, 146)], 5, GRAY_D)
    c.rr((64, 142, 128, 160), 8, GRAY_D)
    return c.render()

@icon
def boat():
    c = Color()
    c.ell(96, 150, 80, 14, BLUE)
    c.rr((92, 24, 100, 120), 4, BROWN_D)
    c.poly([(100, 28), (100, 108), (152, 108)], CREAM, GRAY_D); c.poly([(90, 40), (90, 108), (50, 108)], (255, 226, 190, 255))
    c.poly([(26, 116), (166, 116), (142, 152), (50, 152)], RED)
    c.rr((26, 112, 166, 124), 5, BROWN_L)
    return c.render()

@icon
def gate():
    c = Color()
    for x in (28, 150):
        c.rr((x, 40, x + 16, 160), 5, BROWN_D)
    for y in (62, 100, 138):
        c.rr((36, y - 9, 156, y + 9), 5, BROWN, BROWN_D, 2)
    c.line([(44, 136), (148, 64)], 9, BROWN_L)
    return c.render()

@icon
def sun():
    c = Color()
    for i in range(12):
        a = i * 30
        c.poly(rot([(96, 14), (106, 40), (86, 40)], 96, 96, a), GOLD)
    c.circ(96, 96, 44, GOLD_D); c.circ(96, 96, 40, (255, 222, 90, 255)); c.circ(86, 86, 14, (255, 246, 190, 255))
    return c.render()

@icon
def unlock():
    c = Color()
    c.arc(116, 70, 34, 180, 360, 18, GRAY_D); c.line([(150, 70), (150, 92)], 18, GRAY_D)
    c.arc(116, 70, 34, 180, 360, 10, GRAY)
    c.rr((44, 82, 148, 164), 22, GREEN, GREEN_D, 4)
    c.circ(96, 118, 12, GREEN_D); c.rr((90, 120, 102, 144), 5, GREEN_D)
    return c.render()

@icon
def upgrade():
    c = Color()
    c.poly([(96, 24), (152, 90), (118, 90), (118, 160), (74, 160), (74, 90), (40, 90)], GREEN, GREEN_D)
    c.poly([(96, 40), (132, 84), (112, 84), (112, 150), (80, 150), (80, 84), (60, 84)], (126, 224, 110, 255))
    c.poly([(150, 40), (156, 58), (174, 64), (156, 70), (150, 88), (144, 70), (126, 64), (144, 58)], GOLD)
    return c.render()

@icon
def key():
    c = Color()
    c.circ(66, 70, 40, GOLD_D); c.circ(66, 70, 34, GOLD); c.circ(66, 70, 14, (0, 0, 0, 0)); c.erase_circ(66, 70, 14)
    c.line([(92, 96), (148, 152)], 20, GOLD_D); c.line([(92, 96), (148, 152)], 12, GOLD)
    c.rr((126, 142, 156, 154), 4, GOLD_D); c.rr((140, 128, 152, 156), 4, GOLD_D)
    return c.render()

@icon
def engine():
    c = Color()
    c.circ(96, 98, 56, GRAY_D)
    for i in range(8):
        a = i * 45
        c.poly(rect_poly(96 + 58 * math.cos(math.radians(a)), 98 + 58 * math.sin(math.radians(a)), 26, 24, a), GRAY_D)
    c.circ(96, 98, 46, GRAY); c.circ(96, 98, 18, GRAY_D)
    c.poly([(104, 52), (70, 106), (94, 106), (84, 148), (126, 90), (100, 90)], GOLD, GOLD_D)
    return c.render()

@icon
def together():
    c = Color()
    cols = (BLUE, PINK, GREEN)
    for (cx, cy, s), col in zip(((54, 112, 0.9), (138, 112, 0.9), (96, 100, 1.05)), cols):
        c.circ(cx, cy - 34 * s, 21 * s, (246, 204, 168, 255))
        c.rr((cx - 30 * s, cy - 8 * s, cx + 30 * s, cy + 54 * s), 24 * s, col)
    c.poly([(96, 30), (112, 14), (128, 28), (96, 58), (64, 28), (80, 14)], RED)
    return c.render()

@icon
def forest():
    c = Color()
    c.rr((88, 126, 104, 164), 3, BROWN_D)
    for (cx, base, w) in ((96, 134, 62), (96, 104, 52), (96, 76, 40)):
        c.poly([(cx, base - 46), (cx + w, base), (cx - w, base)], GREEN_D)
        c.poly([(cx, base - 40), (cx + w - 10, base - 4), (cx - w + 10, base - 4)], GREEN)
    return c.render()

@icon
def water():
    c = Color()
    c.poly([(96, 22), (146, 104), (96, 104), (46, 104)], BLUE_D)
    c.circ(96, 112, 52, BLUE_D); c.circ(96, 108, 46, BLUE)
    c.poly([(96, 30), (138, 100), (54, 100)], BLUE)
    c.arc(96, 112, 34, 100, 170, 8, (255, 255, 255, 220))
    return c.render()

@icon
def build():
    c = Color()
    for row, y in enumerate((52, 90, 128)):
        off = 0 if row % 2 == 0 else 24
        for k in range(-1, 4):
            x = 20 + k * 48 + off
            x0, x1 = max(x, 14), min(x + 44, 178)
            if x1 - x0 < 12:
                continue
            c.rr((x0, y, x1, y + 32), 5, (214, 96, 60, 255), (150, 56, 36, 255), 2)
    c.line([(150, 28), (112, 66)], 12, BROWN); c.poly(rect_poly(156, 24, 40, 20, 40), GRAY_D)
    return c.render()

@icon
def friend():
    c = Color()
    for (cx, col) in ((60, BLUE), (132, PINK)):
        c.circ(cx, 90, 24, (246, 204, 168, 255))
        c.rr((cx - 32, 118, cx + 32, 176), 26, col)
    c.poly([(96, 42), (116, 22), (136, 40), (96, 78), (56, 40), (76, 22)], RED)
    return c.render()

@icon
def explore():
    c = Color()
    c.circ(96, 98, 66, GOLD_D); c.circ(96, 98, 58, CREAM); c.circ(96, 98, 50, (214, 236, 255, 255))
    c.poly([(96, 40), (112, 98), (80, 98)], RED); c.poly([(96, 156), (112, 98), (80, 98)], BLUE_D)
    c.circ(96, 98, 8, GOLD_D)
    return c.render()

@icon
def festival():
    c = Color()
    for (cx, cy, col) in ((60, 66, RED), (100, 50, BLUE), (140, 70, GOLD)):
        c.line([(cx, cy + 40), (96, 168)], 3, GRAY_D)
        c.ell(cx, cy, 28, 36, col); c.poly([(cx - 7, cy + 36), (cx + 7, cy + 36), (cx, cy + 46)], col)
        c.ell(cx - 9, cy - 12, 6, 10, (255, 255, 255, 190))
    return c.render()

@icon
def future():
    c = Color()
    c.poly([(96, 20), (130, 70), (130, 126), (62, 126), (62, 70)], CREAM, GRAY_D)
    c.poly([(96, 20), (122, 58), (70, 58)], RED)
    c.circ(96, 88, 17, BLUE); c.circ(96, 88, 11, (180, 226, 255, 255))
    c.poly([(62, 100), (36, 140), (62, 128)], RED); c.poly([(130, 100), (156, 140), (130, 128)], RED)
    c.poly([(76, 128), (116, 128), (96, 170)], ORANGE); c.poly([(84, 128), (108, 128), (96, 154)], GOLD)
    return c.render()

@icon
def apple():
    c = Color()
    c.circ(70, 108, 44, (200, 40, 44, 255)); c.circ(122, 108, 44, (200, 40, 44, 255)); c.circ(96, 118, 46, (200, 40, 44, 255))
    c.circ(70, 104, 40, RED); c.circ(122, 104, 40, RED); c.circ(96, 112, 42, RED)
    c.arc(64, 98, 26, 200, 260, 7, (255, 255, 255, 190))
    c.line([(96, 66), (100, 42)], 8, BROWN_D)
    c.poly([(102, 52), (140, 36), (134, 68)], GREEN); c.poly([(102, 52), (134, 68), (110, 70)], GREEN_D)
    return c.render()

@icon
def mango():
    c = Color()
    c.ell(96, 106, 46, 62, (236, 150, 30, 255))
    c.ell(96, 102, 42, 58, GOLD)
    c.ell(112, 120, 26, 40, (240, 110, 50, 150))
    c.arc(80, 90, 26, 190, 250, 7, (255, 255, 255, 180))
    c.line([(96, 44), (98, 30)], 7, BROWN_D)
    c.poly([(100, 40), (150, 28), (132, 62)], GREEN); c.poly([(100, 40), (132, 62), (108, 58)], GREEN_D)
    return c.render()

@icon
def berry():
    c = Color()
    for (x, y) in ((70, 110), (122, 110), (96, 78), (96, 134)):
        c.circ(x, y, 30, (86, 54, 170, 255)); c.circ(x, y - 2, 26, PURPLE); c.circ(x - 8, y - 10, 7, (255, 255, 255, 190))
    c.line([(96, 56), (96, 36)], 7, GREEN_D)
    c.poly([(98, 46), (136, 32), (128, 60)], GREEN)
    return c.render()

@icon
def wood():
    c = Color()
    c.rr((44, 62, 156, 140), 18, BROWN, BROWN_D, 3)
    for y in (82, 102, 122):
        c.line([(70, y), (146, y)], 4, BROWN_D)
    c.ell(50, 101, 26, 40, BROWN_L)
    c.ell(50, 101, 26, 40, BROWN_L); c.ell(50, 101, 20, 32, (222, 170, 108, 255)); c.ell(50, 101, 12, 20, BROWN_L); c.ell(50, 101, 5, 9, BROWN)
    return c.render()

@icon
def stone():
    c = Color()
    c.poly([(36, 128), (52, 74), (96, 50), (146, 70), (162, 124), (130, 150), (66, 150)], GRAY_D)
    c.poly([(44, 124), (58, 78), (96, 58), (140, 74), (152, 120), (126, 142), (68, 142)], GRAY)
    c.poly([(58, 78), (96, 58), (104, 90), (70, 98)], (210, 220, 232, 255))
    c.poly([(104, 90), (140, 74), (152, 120), (118, 114)], (140, 154, 174, 255))
    return c.render()

@icon
def ore():
    c = Color()
    c.poly([(34, 130), (50, 76), (94, 54), (148, 72), (164, 126), (130, 152), (64, 152)], (70, 80, 100, 255))
    c.poly([(44, 126), (58, 80), (94, 62), (140, 76), (154, 122), (126, 144), (68, 144)], (104, 116, 138, 255))
    for (x, y, r, col) in ((78, 98, 14, GOLD), (118, 92, 11, (120, 220, 255, 255)), (110, 124, 13, GOLD), (70, 128, 9, (120, 220, 255, 255))):
        c.poly(star_pts(x, y, r + 6, r * 0.45, 4, -90), col)
    return c.render()

@icon
def flower():
    c = Color()
    c.line([(96, 100), (96, 168)], 9, GREEN_D)
    c.poly([(98, 148), (146, 124), (136, 160)], GREEN)
    for i in range(5):
        a = math.radians(-90 + i * 72)
        c.circ(96 + 34 * math.cos(a), 78 + 34 * math.sin(a), 24, PINK)
    c.circ(96, 78, 20, GOLD); c.circ(90, 72, 6, GOLD_L)
    return c.render()

@icon
def crate():
    c = Color()
    c.rr((34, 48, 158, 160), 10, BROWN, BROWN_D, 4)
    for y in (78, 108, 138):
        c.line([(40, y), (152, y)], 4, BROWN_D)
    c.line([(44, 56), (148, 152)], 9, BROWN_L); c.line([(148, 56), (44, 152)], 9, BROWN_L)
    return c.render()


def _face(hair, shirt, girl):
    c = Color()
    c.rr((34, 138, 158, 184), 30, shirt)
    if girl:
        c.ell(96, 94, 68, 72, hair)
    c.circ(96, 88, 50, (244, 200, 164, 255))
    c.circ(46, 92, 11, (244, 200, 164, 255)); c.circ(146, 92, 11, (244, 200, 164, 255))
    if girl:
        c.poly([(46, 86), (60, 34), (96, 24), (132, 34), (146, 86), (130, 62), (96, 52), (62, 62)], hair)
        c.circ(148, 40, 15, PINK); c.circ(134, 32, 12, PINK); c.circ(148, 40, 6, (255, 200, 220, 255))
    else:
        c.poly([(44, 86), (48, 50), (96, 26), (144, 50), (148, 86), (130, 58), (96, 48), (62, 58)], hair)
    for x in (74, 118):
        c.circ(x, 90, 8, (40, 36, 56, 255)); c.circ(x + 3, 87, 3, (255, 255, 255, 255))
    c.circ(66, 110, 8, (255, 160, 150, 150)); c.circ(126, 110, 8, (255, 160, 150, 150))
    c.arc(96, 102, 22, 25, 155, 5, (170, 70, 70, 255))
    return c.render()

@icon
def boy():
    return _face((74, 48, 28, 255), (62, 140, 240, 255), False)

@icon
def girl():
    return _face((96, 54, 30, 255), (255, 120, 170, 255), True)


def main():
    os.makedirs(OUT, exist_ok=True)
    count = 0
    for name, fn in ICONS.items():
        fn().save(os.path.join(OUT, name + '.png'), optimize=True); count += 1
    # slash variants: redraw base glyph mask then strike through
    for base, off in (('music', 'music_off'), ('sound', 'sound_off'), ('vibrate', 'vibrate_off')):
        m = Mask()
        if base == 'music':
            m.ell(66, 142, 24, 18); m.ell(130, 126, 24, 18); m.rr((80, 48, 94, 142), 6); m.rr((144, 32, 158, 126), 6)
            m.poly([(80, 46), (158, 28), (158, 56), (80, 74)])
        elif base == 'sound':
            _speaker(m, waves=False)
        else:
            m.rr((68, 30, 124, 162), 14); m.rr((78, 46, 114, 134), 6, 0); m.circ(96, 148, 5, 0)
        m.line([(30, 30), (162, 162)], 34, 0)
        m.line([(30, 30), (162, 162)], 15, 255)
        m.render().save(os.path.join(OUT, off + '.png'), optimize=True); count += 1
    print('wrote', count, 'icons to', OUT)

if __name__ == '__main__':
    main()
