"""Vegetation: trees, bushes, rocks, ridge mountains."""
import numpy as np
from meshkit import *
from gltf import Node
from matdefs import U, cell_rect

def _perp(d, r):
    v = r.normal(size=3); v -= d * (v @ d); return norm(v)

def shell_card(center, outward, size, mat, r, tip=None, ao=0.6, wind=0.5, aspect=1.0):
    """leaf card lying tangent to a clump shell: faces outward, random roll, lit with a crown-spherical normal"""
    n = norm(outward + r.normal(size=3) * 0.18)
    ref = norm(np.array((0, 1.0, 0)) * 0.55 + r.normal(size=3) * 0.9)
    up = ref - n * (ref @ n)
    if np.linalg.norm(up) < 1e-3: up = _perp(n, r)
    up = norm(up); rt = norm(np.cross(up, n))
    ur = list(cell_rect(mat))
    if r.random() < 0.5: ur[0], ur[2] = ur[2], ur[0]
    light_n = norm(0.75 * norm(outward) + 0.25 * np.array((0, 1.0, 0)))
    g = quad(center, rt, up, size * aspect, size, mat, tuple(ur), normal=light_n, double=True)
    tint = ao * (0.84 + 0.3 * r.random())
    g.C[:] = (tint, tint * (0.95 + 0.1 * r.random()), tint * 0.94, np.clip(wind, 0, 1))
    return g

def clump(center, radius, count, mat, r, size=(1.2, 1.7), squash=0.8, inner=0.45, wind=0.6, ao_lo=0.62):
    out = []
    for _ in range(count):
        u = norm(r.normal(size=3)); rr = radius * (inner + (1 - inner) * r.random() ** 0.6)
        p = center + u * rr * np.array((1.0, squash, 1.0)); depth = rr / radius
        out.append(shell_card(p, u, r.uniform(*size), mat, r, ao=ao_lo + (1 - ao_lo) * depth ** 1.2 + 0.05 * u[1], wind=wind))
    return out

def _branch(start, direction, length, r0, r1, bark, r, curl=0.35, n=6, seg=7):
    d = norm(direction); pts = []
    for k in range(n):
        t = k / (n - 1); p = start + d * length * t + np.array((0, 1, 0)) * (curl * length * t * t) + r.normal(size=3) * 0.03 * t
        pts.append(p)
    return tube(np.array(pts), np.linspace(r0, r1, n), bark, seg=seg, uvs=U(bark)), np.array(pts)

def tree_broad(seed=1, H=6.8, crown=3.0, leaf='foliage_broad', trunk_frac=0.55, bark='bark', clumps=5, density=1.0):
    r = np.random.default_rng(seed); geos = []; n = 16; t = np.linspace(0, 1, n); ang = r.uniform(0, 6.28)
    path = np.stack([0.30 * np.sin(t * 2.4 + ang) * t, H * trunk_frac * t, 0.24 * np.cos(t * 2.0 + ang) * t], 1)
    rad = 0.10 + 0.27 * (1 - t) ** 1.5 + 0.20 * np.exp(-t * 16)
    geos.append(tube(path, rad, bark, seg=12, uvs=U(bark)))
    cc = np.array((path[-1][0], H * 0.80, path[-1][2])); tips = [cc + np.array((0, crown * 0.15, 0))]
    for i in range(clumps):
        ts = 0.5 + 0.45 * (i / clumps); k = int(ts * (n - 1)); start = path[k]
        az = i / clumps * 6.28 + r.uniform(-0.35, 0.35); el = r.uniform(0.3, 0.75)
        dirv = np.array((np.cos(az) * np.cos(el), np.sin(el), np.sin(az) * np.cos(el)))
        bg, bp = _branch(start, dirv, crown * r.uniform(0.65, 0.95), rad[k] * 0.55, 0.04, bark, r)
        geos.append(bg); tips.append(bp[-1])
    for i, c in enumerate(tips):
        rr = crown * (0.62 if i else 0.78)
        geos += clump(c + np.array((0, rr * 0.1, 0)), rr, int((34 if i else 46) * density), leaf, r, size=(crown * 0.42, crown * 0.62), wind=np.clip(0.35 + 0.15 * i, 0, 1))
    geos.append(ellipsoid((crown * 0.42, crown * 0.34, crown * 0.42), 'foliage_core', seg=10, rings=6, center=tuple(cc)))
    return Node('Tree', geos, children=[Node('COL_CYL_32_400_0', t=(0, 0, 0))])

def tree_pine(seed=3, H=9.5):
    r = np.random.default_rng(seed); geos = []
    n = 12; t = np.linspace(0, 1, n); path = np.stack([0.05 * np.sin(t * 3), H * t, 0.05 * np.cos(t * 2.5)], 1)
    geos.append(tube(path, 0.30 * (1 - t) ** 0.9 + 0.025, 'bark', seg=10, uvs=U('bark')))
    nt = 12
    for i in range(nt):
        f = i / (nt - 1); y = 1.6 + (H - 2.2) * f; R = 2.5 * (1 - f) ** 0.85 + 0.3; m = max(5, int(11 * (1 - f)) + 5)
        for k in range(m):
            az = (k / m + (i % 2) * 0.5 / m) * 6.28 + r.uniform(-0.15, 0.15); dd = np.array((np.cos(az), -0.22 + 0.2 * f, np.sin(az)))
            base = np.array((0, y, 0)) + dd * R * 0.45; sz = R * r.uniform(0.95, 1.25) * 1.1
            n_out = norm(np.array((dd[0], 0.45, dd[2])))
            geos.append(shell_card(base, n_out, sz, 'foliage_pine', r, ao=0.62 + 0.3 * f, wind=np.clip(0.2 + f * 0.6, 0, 1)))
    geos.append(shell_card(np.array((0, H - 0.8, 0)), np.array((0.3, 0.2, 0.0)), 1.7, 'foliage_pine', r, ao=1.0, wind=1.0))
    geos.append(cylinder(0.9, 0.05, H - 1.4, 'foliage_core', seg=10, y0=1.6))
    return Node('Pine', geos, children=[Node('COL_CYL_30_500_0')])

def tree_fruit(seed=5):
    return tree_broad(seed, H=3.9, crown=1.9, leaf='foliage_fruit', trunk_frac=0.52, clumps=4, density=1.25)

def bush(seed=9, size=1.0, leaf='foliage_bush'):
    r = np.random.default_rng(seed); cc = np.array((0, 0.40 * size, 0)); geos = []
    geos += clump(cc, 0.62 * size, 46, leaf, r, size=(0.45 * size, 0.7 * size), squash=0.62, inner=0.5, wind=0.5, ao_lo=0.55)
    geos.append(ellipsoid((0.32 * size, 0.22 * size, 0.32 * size), 'foliage_core', seg=8, rings=5, center=tuple(cc)))
    return Node('Bush', geos)

def rock_prop(seed, radius, squash, rough=0.28):
    g = rock(radius, 'rock', seed=seed, squash=squash, rough=rough, facets=6, sub=3)
    # box-project UVs (dominant axis) so the preview and non-triplanar use are fine
    a = np.abs(g.N); ax = a.argmax(1)
    uv = np.where((ax == 1)[:, None], g.P[:, [0, 2]], np.where((ax == 0)[:, None], g.P[:, [2, 1]], g.P[:, [0, 1]])) * U('rock')
    g.UV = uv
    g.C[:, :3] = (0.82 + 0.25 * (g.P[:, 1:2] / radius + 0.4)).clip(0.7, 1.15)
    return Node('Rock', [g], children=[Node(f'COL_SPH_{round(radius*85)}_{round(squash*100)}_0')])

def mountains(seed=4, r0=620.0, r1=1250.0, nth=360, nr=22, hmax=520.0):
    rr = np.random.default_rng(seed)
    th = np.linspace(0, 2 * np.pi, nth, endpoint=False); rad = np.linspace(r0, r1, nr)
    TH, RA = np.meshgrid(th, rad)
    # periodic ridged noise on the unrolled ring
    def ridge(a, b, s):
        x = np.stack([np.cos(a) * 2.2 + b * 0.0, np.sin(a) * 2.2, b * 0.9], -1)
        v = 0
        amp = 1; f = 1
        for o in range(5):
            v = v + amp * (1 - np.abs(vnoise(x * f * 1.6, s + o))); amp *= 0.5; f *= 2.0
        return v / 1.94
    bump = ridge(TH, RA / 420.0, seed)
    face = np.clip((RA - r0) / (r1 - r0), 0, 1)
    fall = np.sin(np.pi * np.clip(face * 1.25, 0, 1)) ** 0.8
    H = (hmax * (bump ** 2.4) * (0.35 + 0.65 * fall) + 60 * bump) * np.clip((RA - r0) / 80.0, 0, 1) - 8
    P = np.stack([np.cos(TH) * RA, H, np.sin(TH) * RA], -1).reshape(-1, 3)
    T = []
    for j in range(nr - 1):
        for i in range(nth):
            a = j * nth + i; b = j * nth + (i + 1) % nth; c = (j + 1) * nth + (i + 1) % nth; d = (j + 1) * nth + i
            T += [(a, b, c), (a, c, d)]
    T = np.array(T); N = smooth_normals(P, T)
    # bake colour: rock / snow / forest foot, lambert, aerial perspective
    y = P[:, 1]; slope = 1 - np.clip(N[:, 1], 0, 1)
    snow = np.clip((y - 0.42 * hmax) / (0.18 * hmax) + 0.6 * (0.45 - slope), 0, 1)
    rock_c = np.array((0.42, 0.40, 0.40)) * (0.85 + 0.3 * fbm3(P * 0.01, 3, seed)[:, None]); forest = np.array((0.16, 0.27, 0.15))
    low = np.clip(1 - y / (0.22 * hmax), 0, 1)[:, None] * np.clip(1 - slope * 2.2, 0, 1)[:, None]
    col = rock_c * (1 - low) + forest * low; col = col * (1 - snow[:, None]) + np.array((0.96, 0.97, 1.0)) * snow[:, None]
    L = norm(np.array((0.5, 0.65, -0.35))); lam = np.clip(N @ L, 0, 1)[:, None] * 0.75 + 0.35
    col = col * lam
    haze = np.clip((np.hypot(P[:, 0], P[:, 2]) - r0) / (r1 - r0), 0, 1)[:, None] ** 0.7 * 0.55 + np.clip(1 - y / 200.0, 0, 1)[:, None] * 0.25
    col = col * (1 - haze) + np.array((0.62, 0.74, 0.90)) * haze
    C = np.concatenate([col, np.ones((len(col), 1))], 1)
    g = Geo(P, N, None, C, T, 'mountain')
    return Node('Mountains', [g.fix_winding()])
