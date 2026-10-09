"""Alpha-cutout sprite atlases drawn with PIL (leaves, grass tufts, flowers)."""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

def _rot(pts, ang, ox, oy):
    c, s = np.cos(ang), np.sin(ang)
    return [(ox + x * c - y * s, oy + x * s + y * c) for x, y in pts]

def leaf_pts(length, width, shape='ovate', n=12):
    out = []
    for i in range(n + 1):
        t = i / n
        if shape == 'ovate': w = width * np.sin(np.pi * t ** 0.8) ** 0.85 * (1 - 0.2 * t)
        elif shape == 'lance': w = width * np.sin(np.pi * t ** 0.9) ** 1.1 * (1 - 0.35 * t)
        else: w = width * np.sin(np.pi * t) ** 0.7
        out.append((w, -t * length))
    return out + [(-x, y) for x, y in reversed(out)]

def draw_leaf(d, x, y, ang, length, width, col, shape='ovate', vein=True):
    """ang: 0 = pointing up"""
    base = tuple(int(255 * c) for c in col)
    dark = tuple(int(v * 0.72) for v in base); light = tuple(min(255, int(v * 1.22)) for v in base)
    p = leaf_pts(length, width, shape)
    d.polygon(_rot(p, ang, x, y), fill=dark + (255,))
    inner = [(px * 0.78, py * 0.95 - length * 0.02) for px, py in p]
    d.polygon(_rot(inner, ang, x, y), fill=base + (255,))
    inner2 = [(px * 0.35 + width * 0.12, py * 0.8 - length * 0.1) for px, py in p]
    d.polygon(_rot(inner2, ang, x, y), fill=light + (255,))
    if vein:
        a = _rot([(0, 0), (0, -length * 0.92)], ang, x, y)
        d.line(a, fill=light + (255,), width=max(1, int(width * 0.07)))

def bleed(rgba):
    """spread opaque colours into transparent pixels (no dark fringes after mip-mapping / filtering)"""
    a = rgba[..., 3] > 0.45
    idx = ndi.distance_transform_edt(~a, return_distances=False, return_indices=True)
    out = rgba.copy(); out[..., :3] = rgba[idx[0], idx[1], :3]; return out

def _twig(d, r, x, y, ang, length, depth, kind, S):
    cols = {'broad': [(0.18, 0.40, 0.09), (0.25, 0.48, 0.12), (0.14, 0.34, 0.08), (0.30, 0.50, 0.14)],
            'fruit': [(0.14, 0.38, 0.11), (0.20, 0.46, 0.14), (0.11, 0.32, 0.09)],
            'bush': [(0.22, 0.42, 0.13), (0.30, 0.50, 0.16), (0.17, 0.36, 0.11), (0.32, 0.50, 0.15)],
            'pine': [(0.06, 0.22, 0.13), (0.09, 0.29, 0.16), (0.05, 0.19, 0.12), (0.12, 0.33, 0.18)]}[kind]
    ex = x + np.sin(ang) * length; ey = y - np.cos(ang) * length
    d.line([(x, y), (ex, ey)], fill=(70, 50, 30, 255), width=max(2, int(S * 0.006 * (depth + 1))))
    n = {'broad': 7, 'fruit': 7, 'bush': 8, 'pine': 30}[kind] if depth < 2 else (4 if kind != 'pine' else 22)
    for i in range(n):
        t = (i + 1) / (n + 1) if depth < 2 else (i + 1) / n
        px = x + (ex - x) * t; py = y + (ey - y) * t
        for side in (-1, 1):
            if kind == 'pine':
                L = S * r.uniform(0.07, 0.115) * (1.0 - 0.45 * t); a2 = ang + side * r.uniform(0.75, 1.15)
                c = tuple(int(255 * v) for v in cols[r.integers(len(cols))])
                q = (px + np.sin(a2) * L, py - np.cos(a2) * L)
                d.line([(px, py), q], fill=c + (255,), width=max(3, int(S * 0.0095)))
                continue
            size = S * {'broad': 0.115, 'fruit': 0.12, 'bush': 0.075}[kind] * r.uniform(0.8, 1.15) * (1.0 - 0.35 * t)
            wid = size * {'broad': 0.52, 'fruit': 0.36, 'bush': 0.62}[kind]
            a2 = ang + side * r.uniform(0.55, 1.1)
            draw_leaf(d, px, py, a2, size, wid, cols[r.integers(len(cols))], 'lance' if kind == 'fruit' else 'ovate')
    # terminal leaf
    if kind != 'pine':
        size = S * 0.10 * r.uniform(0.9, 1.1); draw_leaf(d, ex, ey, ang + r.uniform(-.2, .2), size, size * 0.5, cols[r.integers(len(cols))])
    if depth < 2:
        for t, sgn in ((0.30, -1), (0.42, 1), (0.56, -1), (0.68, 1), (0.82, -1)):
            if r.random() < (0.9 if kind == 'pine' else 0.6):
                _twig(d, r, x + (ex - x) * t, y + (ey - y) * t, ang + sgn * r.uniform(0.5, 0.9), length * r.uniform(0.38, 0.55), depth + 1, kind, S)

def leaf_cell(kind, S=512, seed=0, ss=2):
    r = np.random.default_rng(seed); im = Image.new('RGBA', (S * ss, S * ss), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    _twig(d, r, S * ss * 0.5, S * ss * 0.97, r.uniform(-0.08, 0.08), S * ss * 0.62, 0, kind, S * ss)
    return im.resize((S, S), Image.LANCZOS)

def leaf_atlas(S=512, seed=7):
    cells = [leaf_cell(k, S, seed + i) for i, k in enumerate(('broad', 'fruit', 'pine', 'bush'))]
    A = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))
    for i, c in enumerate(cells): A.paste(c, ((i % 2) * S, (i // 2) * S))
    arr = np.asarray(A, np.float32) / 255.0
    arr[..., 3] = (arr[..., 3] > 0.5) * 1.0 * 0 + arr[..., 3]   # keep AA alpha (scissor in shader)
    return Image.fromarray((bleed(arr) * 255).astype(np.uint8))

def blade(d, x0, y0, x1, y1, bend, w0, cols, steps=10):
    pts = []
    for i in range(steps + 1):
        t = i / steps; px = x0 + (x1 - x0) * t + bend * np.sin(np.pi * t) * (1 if x1 >= x0 else -1) * 0.0 + bend * t * t
        py = y0 + (y1 - y0) * t; pts.append((px, py, w0 * (1 - t) ** 0.9 + 0.5))
    for i in range(steps):
        t = (i + 0.5) / steps
        c = tuple(int(255 * (cols[0][k] * (1 - t) + cols[1][k] * t)) for k in range(3))
        (ax, ay, aw), (bx, by, bw) = pts[i], pts[i + 1]
        d.polygon([(ax - aw, ay), (ax + aw, ay), (bx + bw, by), (bx - bw, by)], fill=c + (255,))

def tuft_cell(S=256, seed=0, dry=0.0, ss=2):
    r = np.random.default_rng(seed); im = Image.new('RGBA', (S * ss, S * ss), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for i in range(22):
        bx = S * ss * (0.5 + r.normal(0, 0.10)); h = S * ss * r.uniform(0.45, 0.97) * (1 - abs(bx / (S * ss) - 0.5) * 0.9)
        tipx = bx + r.normal(0, 0.12) * S * ss; w0 = S * ss * r.uniform(0.012, 0.022)
        g = r.random() < dry
        base = (0.12, 0.26, 0.06) if not g else (0.35, 0.30, 0.10)
        tip = (0.45, 0.62, 0.18) if not g else (0.66, 0.58, 0.26)
        sh = r.uniform(0.85, 1.15)
        blade(d, bx, S * ss - 2, tipx, S * ss - h, r.normal(0, S * ss * 0.05), w0,
              (tuple(min(1, c * sh) for c in base), tuple(min(1, c * sh) for c in tip)))
    return im.resize((S, S), Image.LANCZOS)

def grass_atlas(S=256, seed=3):
    A = Image.new('RGBA', (S * 2, S), (0, 0, 0, 0))
    A.paste(tuft_cell(S, seed, 0.0), (0, 0)); A.paste(tuft_cell(S, seed + 1, 0.35), (S, 0))
    arr = np.asarray(A, np.float32) / 255.0
    return Image.fromarray((bleed(arr) * 255).astype(np.uint8))

def flower_cell(kind, S=256, seed=0, ss=2):
    r = np.random.default_rng(seed); im = Image.new('RGBA', (S * ss, S * ss), (0, 0, 0, 0)); d = ImageDraw.Draw(im); K = S * ss
    for i in range(7):
        bx = K * (0.5 + r.normal(0, 0.16)); top = K * r.uniform(0.18, 0.55)
        d.line([(bx, K - 2), (bx + r.normal(0, K * 0.03), top)], fill=(60, 110, 40, 255), width=max(2, int(K * 0.011)))
        for lf in range(2):
            ly = K - (K - top) * r.uniform(0.15, 0.45); draw_leaf(d, bx, ly, r.choice([-1, 1]) * r.uniform(0.7, 1.2), K * 0.11, K * 0.035, (0.16, 0.38, 0.10), 'lance', False)
        hx, hy = bx, top
        if kind == 'daisy':
            for k in range(11):
                a = k / 11 * 2 * np.pi; pr = K * 0.052
                d.polygon(_rot(leaf_pts(pr, pr * 0.30, 'lance', 8), a, hx, hy), fill=(250, 248, 240, 255))
            d.ellipse([hx - K * 0.02, hy - K * 0.02, hx + K * 0.02, hy + K * 0.02], fill=(240, 190, 30, 255))
        elif kind == 'violet':
            for k in range(5):
                a = k / 5 * 2 * np.pi; pr = K * 0.04
                d.polygon(_rot(leaf_pts(pr, pr * 0.55, 'ovate', 8), a, hx, hy), fill=(130, 90, 200, 255))
            d.ellipse([hx - K * 0.01, hy - K * 0.01, hx + K * 0.01, hy + K * 0.01], fill=(250, 230, 120, 255))
        elif kind == 'buttercup':
            for k in range(5):
                a = k / 5 * 2 * np.pi; pr = K * 0.034
                d.ellipse([hx + np.sin(a) * pr - pr * 0.8, hy - np.cos(a) * pr - pr * 0.8, hx + np.sin(a) * pr + pr * 0.8, hy - np.cos(a) * pr + pr * 0.8], fill=(250, 214, 40, 255))
            d.ellipse([hx - K * 0.012, hy - K * 0.012, hx + K * 0.012, hy + K * 0.012], fill=(200, 140, 20, 255))
        else:  # poppy
            for k in range(4):
                a = k / 4 * 2 * np.pi + 0.4; pr = K * 0.055
                d.ellipse([hx + np.sin(a) * pr * 0.55 - pr * 0.7, hy - np.cos(a) * pr * 0.55 - pr * 0.7, hx + np.sin(a) * pr * 0.55 + pr * 0.7, hy - np.cos(a) * pr * 0.55 + pr * 0.7], fill=(215, 40, 30, 255))
            d.ellipse([hx - K * 0.014, hy - K * 0.014, hx + K * 0.014, hy + K * 0.014], fill=(35, 25, 25, 255))
    return im.resize((S, S), Image.LANCZOS)

def flower_atlas(S=256, seed=5):
    A = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))
    for i, k in enumerate(('daisy', 'violet', 'buttercup', 'poppy')): A.paste(flower_cell(k, S, seed + i), ((i % 2) * S, (i // 2) * S))
    arr = np.asarray(A, np.float32) / 255.0
    return Image.fromarray((bleed(arr) * 255).astype(np.uint8))
