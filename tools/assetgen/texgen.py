"""PBR texture recipes. Every function returns dict(albedo, height, rough, ao[, metal]) of a *tileable* image."""
import numpy as np
from texlib import *

def ctr(x, k): return np.clip((x - 0.5) * k + 0.5, 0, 1)
def P(x): return np.asarray(x, float)

def grass(n=1024, seed=1):
    macro = ctr(fbm_tile(n, 3.2, seed, 1, 5), 2.2); mid = ctr(fbm_tile(n, 2.4, seed + 1, 3, 40), 2.0)
    s = 0.5 * ctr(fbm_tile(n, 1.1, seed + 2, 30, n / 3, aniso=(68, 3.2)), 2.2) + 0.5 * ctr(fbm_tile(n, 1.1, seed + 3, 30, n / 3, aniso=(112, 3.2)), 2.2)
    fine = ctr(fbm_tile(n, 0.7, seed + 4, 80, n / 2), 2.0)
    t = 0.40 * s + 0.20 * mid + 0.28 * macro + 0.12 * fine
    alb = ramp(t, [(0, (0.06, 0.15, 0.035)), (0.32, (0.13, 0.28, 0.06)), (0.52, (0.22, 0.40, 0.09)), (0.72, (0.36, 0.52, 0.15)), (1, (0.55, 0.62, 0.26))])
    dry = smoothstep(0.60, 0.82, fbm_tile(n, 3.0, seed + 5, 1, 8))[..., None]
    alb = alb * (1 - dry * 0.55) + dry * 0.55 * P((0.50, 0.46, 0.21)) * (0.8 + 0.4 * s[..., None])
    d1, d2, ids, _ = voronoi_tile(n, 56, seed + 6); r = rng(seed + 7).random(ids.max() + 1)[ids]
    dot = smoothstep(3.2, 1.6, d1) * (r > 0.93); col = np.where((r > 0.965)[..., None], P((0.95, 0.93, 0.78)), P((0.93, 0.80, 0.22)))
    alb = alb * (1 - dot[..., None] * 0.9) + col * dot[..., None] * 0.9
    return dict(albedo=alb, height=0.55 * s + 0.3 * mid + 0.15 * fine, rough=0.92 - 0.12 * s, ao=0.55 + 0.45 * smoothstep(0.15, 0.75, s))

def dirt(n=1024, seed=11):
    soil = ctr(fbm_tile(n, 2.6, seed, 2, 60), 2.2); grit = ctr(fbm_tile(n, 1.0, seed + 1, 40), 2.0)
    d1, d2, ids, _ = voronoi_tile(n, 22, seed + 2, 1.0); rr = rng(seed + 3).random(ids.max() + 1)
    radius = (0.35 + 0.45 * rr)[ids] * (n / 22) * 0.5
    stone = smoothstep(radius, radius * 0.7, d1) * (rr[ids] > 0.62)
    sc = ramp(rng(seed + 4).random(ids.max() + 1)[ids], [(0, (0.38, 0.34, 0.29)), (0.5, (0.55, 0.50, 0.43)), (1, (0.68, 0.62, 0.53))]) * (0.85 + 0.3 * grit[..., None])
    soilc = ramp(0.6 * soil + 0.4 * grit, [(0, (0.17, 0.12, 0.08)), (0.5, (0.34, 0.24, 0.15)), (1, (0.52, 0.40, 0.26))])
    alb = soilc * (1 - stone[..., None]) + sc * stone[..., None]
    return dict(albedo=alb, height=0.5 * soil + 0.2 * grit + 0.55 * stone, rough=0.93 - 0.2 * stone, ao=0.65 + 0.35 * (1 - 0.5 * stone) * smoothstep(0, 0.6, soil))

def rock(n=1024, seed=21):
    base = ctr(fbm_tile(n, 2.8, seed, 2, 90), 2.0); w = ctr(fbm_tile(n, 3.0, seed + 1, 1, 6), 1.6)
    yy = np.linspace(0, 1, n, endpoint=False)[:, None]
    strata = 0.5 + 0.5 * np.sin((yy * 9 + (w - 0.5) * 2.4) * 2 * np.pi)
    d1, d2, ids, _ = voronoi_tile(n, 6, seed + 2, 0.95); edge = d2 - d1
    edge = edge + (fbm_tile(n, 1.6, seed + 8, 6, 200) - 0.5) * 22
    crack = 1 - smoothstep(0.0, 7.0, edge); crack *= smoothstep(0.42, 0.62, fbm_tile(n, 3, seed + 3, 1, 8))
    plate = rng(seed + 4).random(ids.max() + 1)[ids]
    t = 0.45 * base + 0.25 * strata + 0.18 * plate + 0.12 * ctr(fbm_tile(n, 1.2, seed + 5, 60), 2)
    alb = ramp(t, [(0, (0.22, 0.21, 0.20)), (0.4, (0.37, 0.35, 0.33)), (0.7, (0.55, 0.52, 0.47)), (1, (0.72, 0.69, 0.63))])
    warm = ctr(fbm_tile(n, 3, seed + 6, 1, 5), 2)[..., None]; alb = alb * (0.9 + 0.2 * warm * P((1.08, 1.0, 0.9)))
    lich = (smoothstep(0.66, 0.80, fbm_tile(n, 2.6, seed + 7, 2, 30)) * (1 - crack))[..., None]
    alb = alb * (1 - lich * 0.55) + lich * 0.55 * P((0.50, 0.56, 0.28)) * (0.8 + 0.4 * base[..., None])
    alb *= (1 - 0.65 * crack[..., None])
    return dict(albedo=alb, height=0.55 * base + 0.2 * strata + 0.1 * plate - 0.5 * crack, rough=0.9 - 0.15 * base, ao=1 - 0.7 * crack)

def sand(n=512, seed=31):
    x = np.arange(n)[None, :]; y = np.arange(n)[:, None]
    w = fbm_tile(n, 3, seed, 1, 6); rip = 0.5 + 0.5 * np.sin(2 * np.pi * (3 * x / n + 5 * y / n) + (w - 0.5) * 9)
    g = ctr(fbm_tile(n, 0.8, seed + 1, 80), 2.2); m = ctr(fbm_tile(n, 2.5, seed + 2, 2, 40), 2)
    alb = ramp(0.45 * m + 0.35 * g + 0.2 * rip, [(0, (0.66, 0.57, 0.40)), (0.5, (0.80, 0.71, 0.52)), (1, (0.90, 0.83, 0.64))])
    return dict(albedo=alb, height=0.5 * rip + 0.3 * m + 0.2 * g, rough=0.95 - 0.1 * g, ao=0.8 + 0.2 * rip)

def cobble(n=512, seed=41):
    d1, d2, ids, _ = voronoi_tile(n, 7, seed, 0.75); edge = d2 - d1
    gap = 1 - smoothstep(2.5, 8.0, edge); r = rng(seed + 1).random(ids.max() + 1)[ids]
    var = ctr(fbm_tile(n, 2.2, seed + 2, 3, 80), 2)
    sc = ramp(r, [(0, (0.44, 0.43, 0.41)), (0.5, (0.60, 0.57, 0.51)), (1, (0.72, 0.65, 0.54))]) * (0.82 + 0.3 * var[..., None])
    moss = (smoothstep(0.45, 0.7, fbm_tile(n, 2.4, seed + 3, 2, 30)) * gap)[..., None]
    mort = ramp(ctr(fbm_tile(n, 1.2, seed + 4, 40), 2), [(0, (0.14, 0.12, 0.10)), (1, (0.30, 0.27, 0.22))]) * (1 - moss) + moss * P((0.20, 0.30, 0.11))
    alb = sc * (1 - gap[..., None]) + mort * gap[..., None]
    h = (1 - gap) * (0.55 + 0.45 * smoothstep(0, 18, edge)) + 0.06 * var
    return dict(albedo=alb, height=h, rough=0.88 - 0.15 * (1 - gap), ao=0.35 + 0.65 * (1 - gap) ** 0.6)

def wood_planks(n=512, seed=51, planks=8):
    ph = n // planks; y = np.arange(n)[:, None]; x = np.arange(n)[None, :]; board = np.minimum(y // ph, planks - 1).astype(int) * np.ones((1, n), int)
    r = rng(seed); rnd = r.random(planks); shift = r.integers(0, n, planks)
    g0 = ctr(fbm_tile(n, 2.0, seed, 3, n / 2, aniso=(0, 14)), 2.4); g1 = ctr(fbm_tile(n, 1.4, seed + 1, 20, n / 2, aniso=(0, 18)), 2.2)
    grain = np.zeros((n, n)); fine = np.zeros((n, n))
    for b in range(planks):
        sl = slice(b * ph, (b + 1) * ph); grain[sl] = np.roll(g0, int(shift[b]), 1)[sl]; fine[sl] = np.roll(g1, int(shift[b] * 3), 1)[sl]
    edge = np.minimum(y % ph, ph - 1 - y % ph).astype(float) * np.ones((1, n)); gap = 1 - smoothstep(1.5, 4.5, edge)
    t = 0.5 * grain + 0.25 * fine + 0.25 * rnd[board]
    alb = ramp(t, [(0, (0.22, 0.15, 0.09)), (0.35, (0.40, 0.28, 0.17)), (0.65, (0.56, 0.42, 0.28)), (1, (0.70, 0.56, 0.40))])
    alb *= (0.9 + 0.2 * rnd[board])[..., None]
    for k in range(3):   # knots
        kx, ky = r.integers(0, n), (r.integers(0, planks) + 0.5) * ph
        dx = np.minimum(abs(x - kx), n - abs(x - kx)); dy = abs(y - ky); rr = np.sqrt((dx / 1.8) ** 2 + dy ** 2) / (ph * 0.11)
        ring = 0.5 + 0.5 * np.sin(rr * 7); m = smoothstep(2.2, 0.4, rr)
        alb = alb * (1 - m[..., None] * 0.55) * (0.9 + 0.1 * ring[..., None]); grain = grain * (1 - m) + ring * m
    alb *= (1 - 0.8 * gap[..., None])
    return dict(albedo=alb, height=0.35 * grain + 0.15 * fine + 0.5 * (1 - gap), rough=0.85 - 0.12 * grain, ao=1 - 0.7 * gap)

def bark(n=512, seed=61):
    a = ctr(fbm_tile(n, 1.9, seed, 3, 60, aniso=(90, 9)), 2.2); b = ctr(fbm_tile(n, 1.4, seed + 1, 8, n / 3, aniso=(90, 6)), 2.0)
    h = 0.62 * a + 0.38 * b; furrow = smoothstep(0.45, 0.30, h)
    alb = ramp(h, [(0, (0.075, 0.05, 0.04)), (0.35, (0.18, 0.12, 0.08)), (0.65, (0.34, 0.25, 0.18)), (1, (0.50, 0.40, 0.30))])
    li = (smoothstep(0.62, 0.78, fbm_tile(n, 2.5, seed + 2, 2, 20)) * (1 - furrow))[..., None]
    alb = alb * (1 - li * 0.5) + li * 0.5 * P((0.55, 0.58, 0.45))
    return dict(albedo=alb, height=h, rough=0.95 - 0.1 * h, ao=1 - 0.75 * furrow)

def plaster(n=512, seed=71, base=(0.88, 0.82, 0.70)):
    var = ctr(fbm_tile(n, 2.8, seed, 2, 30), 1.8); grain = ctr(fbm_tile(n, 0.9, seed + 1, 60), 2.0)
    stain = ctr(fbm_tile(n, 2.6, seed + 2, 2, 25, aniso=(90, 3)), 1.4)
    alb = P(base) * (0.90 + 0.2 * var[..., None]) * (1 - 0.05 * stain[..., None]) * (0.96 + 0.08 * grain[..., None])
    return dict(albedo=alb, height=0.35 * var + 0.65 * grain, rough=0.92 - 0.08 * grain, ao=0.9 + 0.1 * var)

def brick(n=512, seed=81, rows=8, cols=4, palette=None, mortar_px=4, name='brick'):
    palette = palette or [(0.56, 0.22, 0.15), (0.64, 0.30, 0.19), (0.47, 0.19, 0.13), (0.68, 0.38, 0.26), (0.52, 0.27, 0.20)]
    bh = n // rows; bw = n // cols; y = np.arange(n)[:, None]; x = np.arange(n)[None, :]
    row = (y // bh).astype(int) * np.ones((1, n), int); xs = (x + (row % 2) * (bw // 2)) % n; col = (xs // bw).astype(int)
    u = (xs % bw).astype(float); v = (y % bh).astype(float) * np.ones((1, n))
    edge = np.minimum(np.minimum(u, bw - 1 - u), np.minimum(v, bh - 1 - v))
    r = rng(seed); cid = r.random((rows, cols)); jit = r.random((rows, cols))
    pal = np.array(palette); pick = pal[(cid * len(pal)).astype(int).clip(0, len(pal) - 1)]
    bc = pick[row, col] * (0.88 + 0.24 * jit[row, col])[..., None]
    nz = ctr(fbm_tile(n, 1.6, seed, 4, n / 2), 2.0)
    bc = bc * (0.88 + 0.24 * nz[..., None])
    mort = P((0.66, 0.63, 0.57)) * (0.8 + 0.3 * ctr(fbm_tile(n, 1.0, seed + 1, 50), 2)[..., None])
    mmask = 1 - smoothstep(mortar_px - 1, mortar_px + 1, edge)
    alb = bc * (1 - mmask[..., None]) + mort * mmask[..., None]
    h = (1 - mmask) * (0.6 + 0.4 * smoothstep(mortar_px, mortar_px + 6, edge)) + 0.1 * nz
    return dict(albedo=alb, height=h, rough=0.88 - 0.1 * (1 - mmask), ao=0.45 + 0.55 * (1 - mmask) ** 0.5)

def roof_tiles(n=512, seed=91, rows=8, cols=4):
    th = n // rows; tw = n // cols; y = np.arange(n)[:, None]; x = np.arange(n)[None, :]
    row = (y // th).astype(int) * np.ones((1, n), int); xs = (x + (row % 2) * (tw // 2)) % n; col = (xs // tw).astype(int)
    u = (xs % tw) / tw; v = ((y % th) / th) * np.ones((1, n))
    r = rng(seed); cr = r.random((rows, cols)); k = cr[row, col]
    nz = ctr(fbm_tile(n, 2.0, seed, 3, n / 2), 2)
    base = ramp(0.55 * k + 0.45 * nz, [(0, (0.50, 0.19, 0.11)), (0.5, (0.65, 0.28, 0.16)), (1, (0.80, 0.42, 0.25))])
    shadow = smoothstep(0.22, 0.0, v) * 0.65; lipd = smoothstep(0.86, 1.0, v) * 0.25
    side = smoothstep(0.1, 0.0, np.minimum(u, 1 - u)) * 0.45
    moss = (smoothstep(0.62, 0.78, fbm_tile(n, 2.6, seed + 1, 2, 20)))[..., None] * 0.5
    alb = base * (1 - shadow - lipd - side)[..., None]
    alb = alb * (1 - moss) + moss * P((0.28, 0.36, 0.16)) * (0.7 + 0.5 * nz[..., None]) * (1 - shadow)[..., None]
    h = smoothstep(0.0, 0.25, v) * (1 - smoothstep(0.92, 1.0, v)) * 0.8 + 0.2 * np.sin(u * np.pi) + 0.05 * nz
    return dict(albedo=alb, height=h, rough=0.82, ao=1 - 0.8 * shadow)

def fabric_stripes(n=512, seed=101, stripes=8, c1=(0.78, 0.13, 0.11), c2=(0.95, 0.92, 0.84)):
    x = np.arange(n)[None, :] * np.ones((n, 1)); y = np.arange(n)[:, None] * np.ones((1, n))
    st = ((x * stripes // n) % 2).astype(float)
    weave = 0.5 + 0.5 * np.sin(2 * np.pi * 96 * x / n) * np.sin(2 * np.pi * 96 * y / n)
    nz = ctr(fbm_tile(n, 2.4, seed, 2, 60), 1.8)
    alb = (P(c1) * (1 - st[..., None]) + P(c2) * st[..., None]) * (0.92 + 0.1 * weave[..., None]) * (0.92 + 0.14 * nz[..., None])
    return dict(albedo=alb, height=0.7 * weave + 0.3 * nz, rough=0.88, ao=0.9 + 0.1 * weave)

def cloth_plain(n=512, seed=111, base=(0.72, 0.66, 0.52)):
    x = np.arange(n)[None, :] * np.ones((n, 1)); y = np.arange(n)[:, None] * np.ones((1, n))
    weave = 0.5 + 0.5 * np.sin(2 * np.pi * 128 * x / n) * np.sin(2 * np.pi * 128 * y / n)
    nz = ctr(fbm_tile(n, 2.4, seed, 2, 60), 1.8)
    return dict(albedo=P(base) * (0.9 + 0.1 * weave[..., None]) * (0.88 + 0.2 * nz[..., None]), height=0.7 * weave + 0.3 * nz, rough=0.9, ao=0.9 + 0.1 * weave)

def metal_iron(n=256, seed=121):
    s = ctr(fbm_tile(n, 1.2, seed, 20, n / 2, aniso=(15, 8)), 2.2); m = ctr(fbm_tile(n, 2.6, seed + 1, 2, 20), 2)
    alb = ramp(0.6 * m + 0.4 * s, [(0, (0.10, 0.10, 0.11)), (0.6, (0.22, 0.22, 0.24)), (1, (0.38, 0.37, 0.38))])
    rust = smoothstep(0.70, 0.86, fbm_tile(n, 2.8, seed + 2, 2, 20))[..., None]
    alb = alb * (1 - rust * 0.7) + rust * 0.7 * P((0.40, 0.19, 0.08))
    return dict(albedo=alb, height=0.5 * s + 0.5 * m, rough=0.5 + 0.35 * rust[..., 0] + 0.1 * (1 - s), ao=np.ones((n, n)), metal=0.85 * (1 - rust[..., 0]))

def water_normal(n=512, seed=131):
    r = rng(seed); x = np.arange(n)[None, :] / n; y = np.arange(n)[:, None] / n; h = np.zeros((n, n))
    for i in range(18):
        kx, ky = r.integers(-9, 10), r.integers(-9, 10)
        if kx == 0 and ky == 0: continue
        h += np.sin(2 * np.pi * (kx * x + ky * y) + r.random() * 6.28) * (1.0 / (1 + 0.35 * np.hypot(kx, ky)))
    h = norm01(h) * 0.7 + 0.3 * fbm_tile(n, 2.2, seed, 4, n / 4)
    return dict(albedo=np.ones((n, n, 3)) * 0.5, height=h, rough=np.full((n, n), 0.1), ao=np.ones((n, n)))

def detail_fine(n=256, seed=141):
    """fine skin / cloth micro normal used by the avatar shader (triplanar)"""
    x = np.arange(n)[None, :] * np.ones((n, 1)); y = np.arange(n)[:, None] * np.ones((1, n))
    weave = 0.5 + 0.5 * np.sin(2 * np.pi * 48 * x / n) * np.sin(2 * np.pi * 48 * y / n)
    pores = ctr(fbm_tile(n, 0.8, seed, 30, n / 2), 2.2)
    h = 0.45 * pores + 0.35 * weave + 0.2 * ctr(fbm_tile(n, 2.2, seed + 1, 2, 30), 2)
    return dict(albedo=np.ones((n, n, 3)) * 0.5, height=h, rough=np.full((n, n), 0.6), ao=np.ones((n, n)))

RECIPES = {  # name -> (fn, size, normal_strength)
    'grass': (grass, 1024, 1.6), 'dirt': (dirt, 1024, 2.2), 'rock': (rock, 1024, 3.0), 'sand': (sand, 512, 1.2),
    'cobble': (cobble, 512, 3.0), 'wood_planks': (wood_planks, 512, 2.4), 'bark': (bark, 512, 3.2), 'plaster': (plaster, 512, 1.4),
    'brick': (brick, 512, 3.0), 'roof_tiles': (roof_tiles, 512, 3.2), 'awning': (fabric_stripes, 512, 1.6),
    'cloth': (cloth_plain, 512, 1.6), 'iron': (metal_iron, 256, 1.8),
}
