"""Small props, harvestable resources and the letter gem."""
import numpy as np
from meshkit import *
from gltf import Node
from kit import *
from matdefs import U

def lamp_post():
    g = [cylinder(0.2, 0.14, 0.25, 'iron', seg=12), cylinder(0.075, 0.05, 2.9, 'iron', seg=12, y0=0.25), cylinder(0.12, 0.12, 0.06, 'iron', seg=12, y0=0.9)]
    g.append(tube(np.array([(0, 2.9, 0), (0.05, 3.2, 0), (0.35, 3.35, 0), (0.6, 3.25, 0)]), [0.04, 0.035, 0.03, 0.03], 'iron', seg=8, cap_end=False))
    c = (0.6, 3.05, 0)
    g.append(cylinder(0.11, 0.11, 0.03, 'iron', seg=8, y0=c[1] - 0.2).xf(Tm(c[0], 0, 0)))
    g.append(cylinder(0.1, 0.1, 0.24, 'lantern_glow', seg=8, y0=c[1] - 0.17, caps=(False, False)).xf(Tm(c[0], 0, 0)))
    g.append(cylinder(0.02, 0.13, 0.1, 'iron', seg=8, y0=c[1] + 0.07).xf(Tm(c[0], 0, 0)))
    return Node('LampPost', g, children=[Node('COL_CYL_22_340_0')])

def signpost():
    g = [beam((0, 0, 0), (0, 3.0, 0), 0.14, 0.14, 'wood_planks', r=0.02)]
    for i, (y, ang, ln) in enumerate(((2.65, 12, 1.5), (2.2, -8, 1.45), (1.75, 6, 1.5))):
        poly = [(0, -0.17), (ln - 0.28, -0.17), (ln, 0.0), (ln - 0.28, 0.17), (0, 0.17)]
        for gg in extrude_poly(poly, 0.05, 'wood_planks', uvs=U('wood_planks')): g.append(gg.xf(Tm(0.04, y, -0.09) @ Ry(ang + (0 if i % 2 == 0 else 180)) @ Tm(0.0, 0, 0)) if False else gg.xf(Ry(ang if i % 2 == 0 else 180 - ang) @ Tm(0.07, y, 0.0) if False else Tm(0, y, 0) @ Ry(ang if i % 2 == 0 else 180 - ang) @ Tm(0.07, 0, 0.09)))
    return Node('Signpost', g, children=[Node('COL_CYL_18_300_0')])

def fence_segment(L=2.0):
    g = fence_run((0, 0, 0), (L, 0, 0), h=1.0, post_every=L, rails=2)
    for i in range(1, 8): g.append(beam((i * L / 8, 0.05, 0.0), (i * L / 8, 0.88 + 0.03 * (i % 2), 0.0), 0.075, 0.03, 'wood_planks')) if False else None
    return Node('Fence', g)

def bench():
    g = [B((1.7, 0.07, 0.42), 'wood_planks', center=(0, 0.48, 0), r=0.01), B((1.7, 0.4, 0.06), 'wood_planks', center=(0, 0.78, 0.22), r=0.01)]
    for sx in (-1, 1): g += [beam((sx * 0.75, 0, -0.16), (sx * 0.75, 0.46, -0.16), 0.06, 0.05, 'iron'), beam((sx * 0.75, 0, 0.16), (sx * 0.75, 0.46, 0.16), 0.06, 0.05, 'iron'), beam((sx * 0.75, 0.46, 0.2), (sx * 0.75, 0.95, 0.22), 0.05, 0.05, 'iron')]
    return Node('Bench', g, children=[Node('COL_BOX_180_90_50', t=(0, 0.45, 0))])

def well():
    g = [lathe([(1.0, 0), (1.0, 0.85), (0.78, 0.85), (0.78, 0.0)], 'rock', seg=20, creases=(1, 2), uvs=U('rock')), cylinder(0.78, 0.78, 0.02, 'water_dark', seg=18, y0=0.45, caps=(True, False))]
    for sx in (-1, 1): g.append(beam((sx * 0.95, 0.8, 0), (sx * 0.95, 2.4, 0), 0.14, 0.14, 'wood_planks', r=0.02))
    g.append(beam((-0.95, 2.1, 0), (0.95, 2.1, 0), 0.12, 0.12, 'wood_planks')); g.append(cylinder(0.08, 0.08, 1.9, 'wood_planks', seg=10, y0=-0.95).xf(Tm(0, 1.6, 0) @ Rz(90)))
    g += gable_roof(2.4, 1.6, 0.8, 0.25, 0.3, 0.07, y0=2.4)
    g += [x.xf(Tm(0, 0, 0)) for x in [B((0.3, 0.22, 0.3), 'wood_planks', center=(0.0, 1.3, 0.0), r=0.03)]]
    return Node('Well', g, children=[Node('COL_CYL_105_100_0')])

def haystack(seed=1):
    r = np.random.default_rng(seed)
    prof = [(1.0, 0), (1.1, 0.3), (0.95, 0.8), (0.65, 1.3), (0.3, 1.65), (0.0, 1.8)]
    g = lathe(prof, 'hay', seg=22, uvs=1.0, closed_bottom=True)
    n = fbm3(g.P * 3.0, 3, seed)
    g.P = g.P + g.N * n[:, None] * 0.06; g.C[:, :3] = (0.78 + 0.35 * n[:, None]).clip(0.6, 1.1)
    return Node('Haystack', [g], children=[Node('COL_CYL_100_150_0')])

def crop_wheat(seed=2, n=26):
    r = np.random.default_rng(seed); g = []
    for i in range(n):
        a = r.uniform(0, 6.28); rad = 0.22 * np.sqrt(r.random()); x, z = np.cos(a) * rad, np.sin(a) * rad; h = r.uniform(0.75, 1.0); lean = r.normal(0, 0.1, 2)
        pts = np.array([(x, 0, z), (x + lean[0] * 0.5, h * 0.5, z + lean[1] * 0.5), (x + lean[0], h, z + lean[1])])
        gg = tube(pts, [0.008, 0.006, 0.005], 'wheat', seg=4, cap_end=False); gg.C[:, :3] = (0.65 + 0.2 * r.random()); g.append(gg)
        head = ellipsoid((0.022, 0.085, 0.022), 'wheat', seg=6, rings=4, center=(pts[2][0], pts[2][1] + 0.07, pts[2][2])); head.C[:, :3] = 0.85 + 0.2 * r.random(); g.append(head)
    return Node('Wheat', g)

def _fruit(r, col, ytop=0.0, elong=1.0, seed=0, leaf=True):
    g = ellipsoid((r, r * elong, r), col, seg=14, rings=10, center=(0, r * elong, 0))
    n = fbm3(g.P * 14, 2, seed); g.P = g.P + g.N * n[:, None] * r * 0.035
    g.C[:, :3] = (0.9 + 0.2 * n[:, None]).clip(0.7, 1.1)
    out = [g, cylinder(0.012, 0.01, r * 0.5, 'bark', seg=5, y0=r * elong * 2 - r * 0.2)]
    if leaf:
        lf = quad((0.06, r * elong * 2 + 0.01, 0), (1, 0, 0), (0.6, 0, 0.6), 0.1, 0.06, 'foliage_fruit', cell_rect_default(), double=True); out.append(lf)
    return out

def cell_rect_default():
    from matdefs import cell_rect; return cell_rect('foliage_fruit')

def res_apple(): return Node('Apple', _fruit(0.11, 'fruit_red', seed=1))
def res_orange(): return Node('Orange', _fruit(0.12, 'fruit_orange', seed=2))
def res_mango(): return Node('Mango', _fruit(0.1, 'fruit_mango', elong=1.35, seed=3))

def res_wood():
    g = []
    for i, (x, z, ang, rad) in enumerate(((0.0, 0.0, 8, 0.13), (0.0, 0.26, -6, 0.12), (0.12, 0.13, 3, 0.115))):
        y = rad if i < 2 else rad + 0.18
        c = cylinder(rad, rad, 0.8, 'bark', seg=12, y0=-0.4, caps=(False, False), uvs=U('bark')).xf(Tm(x, y, z) @ Ry(ang) @ Rz(90))
        g.append(c)
        for s in (-1, 1):
            e = cylinder(rad * 0.97, rad * 0.97, 0.01, 'wood_planks', seg=12, y0=s * 0.4 - 0.005, caps=(True, True), uvs=U('wood_planks')).xf(Tm(x, y, z) @ Ry(ang) @ Rz(90)); g.append(e)
    return Node('Log', g)

def res_stone():
    return Node('Stone', [rock(0.24, 'rock', seed=5, squash=0.7, rough=0.3, facets=5, sub=2, center=(0, 0.14, 0)), rock(0.15, 'rock', seed=6, squash=0.7, rough=0.3, facets=4, sub=2, center=(0.28, 0.09, 0.1))])

def res_ore():
    g = [rock(0.3, 'rock', seed=8, squash=0.75, rough=0.3, facets=5, sub=2, center=(0, 0.16, 0))]
    r = np.random.default_rng(4)
    for i in range(5):
        a = r.uniform(0, 6.28); d = r.uniform(0.05, 0.2); tilt = r.uniform(5, 30); h = r.uniform(0.18, 0.34); rad = r.uniform(0.04, 0.065)
        c = Node('c', [cylinder(rad, rad, h * 0.7, 'ore_crystal', seg=6, y0=0), cylinder(rad, 0.005, h * 0.3, 'ore_crystal', seg=6, y0=h * 0.7)])
        M = Tm(np.cos(a) * d, 0.18, np.sin(a) * d) @ Ry(r.uniform(0, 360)) @ Rz(tilt * (1 if r.random() < 0.5 else -1)) @ Rx(tilt * r.uniform(-1, 1))
        g += [x.xf(M) for x in c.geos]
    return Node('Ore', g)

def letter_gem(s=0.56):
    g = rbox((s, s, s), 0.09, 'gem', uvs=1.0 / s, center=(0, s / 2, 0), k=2)
    g.UV = g.UV + 0.5
    return Node('LetterGem', [g])

def stall_small():
    g = [B((2.2, 0.8, 0.9), 'wood_planks', center=(0, 0.4, 0), r=0.03), B((2.35, 0.07, 1.05), 'wood_planks', center=(0, 0.83, 0), r=0.02)]
    for sx in (-1, 1): g.append(beam((sx * 1.05, 0, 0.4), (sx * 1.05, 2.3, 0.4), 0.09, 0.09, 'wood_planks', r=0.015)); g.append(beam((sx * 1.05, 0.8, -0.4), (sx * 1.05, 2.1, -0.4), 0.09, 0.09, 'wood_planks', r=0.015))
    P = [(-1.25, 2.3, 0.45), (1.25, 2.3, 0.45), (1.25, 2.0, -0.7), (-1.25, 2.0, -0.7)]
    g += slab([P[3], P[2], P[1], P[0]], 0.03, 'awning', 'awning', lambda p: ((p[0] + 1.25) * U('awning'), (p[2] - 0.45) * U('awning')))
    g += basket(0.26, 0.22, (-0.6, 0.87, 0)) + basket(0.24, 0.2, (0.2, 0.87, 0.05)) + sack(0.22, (0.8, 0.87, 0))
    return Node('Stall', g, children=[Node('COL_BOX_240_230_120', t=(0, 1.15, 0))])
