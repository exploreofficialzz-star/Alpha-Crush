"""Construction kit: beams, roofs, windows, doors, fences ... all return lists of Geo (Y up, faces -Z)."""
import numpy as np
from meshkit import *
from gltf import Node
from matdefs import U

def swap_uv(g):
    g = g.copy(); g.UV = np.stack([-g.UV[:, 1], g.UV[:, 0]], 1); return g

def B(size, mat, center=(0, 0, 0), r=0.0, k=2):
    # rounding only pays off on chunky pieces; thin beams stay plain boxes (keeps triangle counts mobile-friendly)
    if r >= 0.025 and min(size) >= 0.2: return rbox(size, r, mat, uvs=U(mat), center=center, k=k)
    return box(size, mat, uvs=U(mat), center=center)

def beam(a, b, w, h, mat, up=(0, 1, 0), r=0.0):
    a = np.array(a, float); b = np.array(b, float); x = b - a; L = np.linalg.norm(x); x = x / L
    upv = np.array(up, float)
    if abs(x @ upv) > 0.95: upv = np.array((1.0, 0, 0))
    z = norm(np.cross(x, upv)); y = np.cross(z, x)
    M = np.eye(4); M[:3, 0] = x; M[:3, 1] = y; M[:3, 2] = z; M[:3, 3] = (a + b) / 2
    return B((L, w, h), mat, r=r).xf(M)

def slab(P, t, mat_top, mat_edge, top_uv):
    """thick plate from 4 top corners P[0..3] (ccw seen from above), thickness t downward along the plate normal"""
    P = np.array(P, float); n = norm(np.cross(P[1] - P[0], P[3] - P[0]))
    if n[1] < 0: n = -n; P = P[::-1]
    Q = P - n * t; geos = []
    UV = np.array([top_uv(p) for p in P])
    geos.append(Geo(P, [n] * 4, UV, None, [(0, 1, 2), (0, 2, 3)], mat_top).fix_winding())
    geos.append(Geo(Q, [-n] * 4, UV, None, [(0, 1, 2), (0, 2, 3)], mat_edge).fix_winding())
    for i in range(4):
        a, b = P[i], P[(i + 1) % 4]; qa, qb = Q[i], Q[(i + 1) % 4]
        e = norm(b - a); sn = norm(np.cross(e, n))
        uvv = [(0, 0), (np.linalg.norm(b - a) * U(mat_edge), 0), (np.linalg.norm(b - a) * U(mat_edge), t * U(mat_edge)), (0, t * U(mat_edge))]
        geos.append(Geo([a, b, qb, qa], [sn] * 4, uvv, None, [(0, 1, 2), (0, 2, 3)], mat_edge).fix_winding())
    return geos

def gable_roof(L, W, rise, over_x, over_z, t, mat='roof_tiles', edge='wood_planks', y0=0.0):
    """ridge along X. Eaves at y0 on z=+-W/2 (+overhang). Returns geos + the gable-end triangle height info."""
    geos = []; hx = L / 2 + over_x; hz = W / 2 + over_z; slope = rise / (W / 2); drop = slope * hz
    for sgn in (1, -1):   # sgn=-1 -> slope facing -Z (front)
        ridge_y = y0 + rise
        A = np.array((-hx, ridge_y, 0.0)); Bp = np.array((hx, ridge_y, 0.0))
        C = np.array((hx, ridge_y - drop, sgn * hz)); D = np.array((-hx, ridge_y - drop, sgn * hz))
        su = U(mat)
        slope_len = np.linalg.norm(C - Bp)
        def uvf(p, A=A, Bp=Bp, C=C, su=su):
            return ((p[0] + hx) * su, np.linalg.norm(p - np.array((p[0], A[1], 0.0))) * su)
        P = [A, Bp, C, D] if sgn == -1 else [D, C, Bp, A]
        geos += slab(P, t, mat, edge, uvf)
    # ridge cap
    geos.append(beam((-hx - 0.02, y0 + rise + 0.03, 0), (hx + 0.02, y0 + rise + 0.03, 0), 0.16, 0.12, mat, r=0.03))
    return geos

def gable_end(W, rise, mat, x, thick=0.1, y0=0.0):
    """plaster triangle closing a gable at x (extruded in X by thick)"""
    hz = W / 2
    P = np.array([(x, y0, -hz), (x, y0, hz), (x, y0 + rise, 0)])
    out = []
    for sgn in (1, -1):
        n = np.array((sgn, 0, 0)); Q = P + n * thick * 0.5 * 0
        uv = [(p[2] * U(mat), -p[1] * U(mat)) for p in P]
        out.append(Geo(P + n * thick / 2, [n] * 3, uv, None, [(0, 1, 2)] if sgn == 1 else [(0, 2, 1)], mat).fix_winding())
    return out

def window(w, h, center, facing=-1, depth=0.1, frame='wood_planks', shutters=True, axis='z'):
    """window in a wall whose normal is facing * axis.  Returns geos (frame, glass, mullion, shutters)."""
    g = []; fw = 0.07
    cx, cy, cz = center
    def at(x, y, z): return (cx + x, cy + y, cz + z)
    def mk(size, mat, off):
        s = size if axis == 'z' else (size[2], size[1], size[0])
        o = (off[0], off[1], off[2] * facing) if axis == 'z' else (off[2] * facing, off[1], off[0])
        return B(s, mat, center=at(*o))
    g.append(mk((w + 2 * fw, fw, depth), frame, (0, h / 2, 0))); g.append(mk((w + 2 * fw, fw, depth), frame, (0, -h / 2, 0)))
    g.append(mk((fw, h, depth), frame, (-w / 2, 0, 0))); g.append(mk((fw, h, depth), frame, (w / 2, 0, 0)))
    g.append(mk((w, h, 0.03), 'glass_window', (0, 0, -0.02)))
    g.append(mk((0.035, h, depth * 0.7), frame, (0, 0, 0))); g.append(mk((w, 0.035, depth * 0.7), frame, (0, 0, 0)))
    g.append(mk((w + 0.2, 0.06, depth + 0.1), frame, (0, -h / 2 - 0.05, 0.03)))
    if shutters:
        for sx in (-1, 1): g.append(mk((w * 0.5, h, 0.04), 'wood_planks', (sx * (w / 2 + w * 0.27), 0, 0.03)))
    return g

def door(w, h, center, facing=-1, axis='z', mat='wood_planks'):
    g = []; cx, cy, cz = center
    def mk(size, m, off):
        s = size if axis == 'z' else (size[2], size[1], size[0])
        o = (off[0], off[1], off[2] * facing) if axis == 'z' else (off[2] * facing, off[1], off[0])
        return B(s, m, center=(cx + o[0], cy + o[1], cz + o[2]))
    g.append(mk((w + 0.2, 0.1, 0.16), mat, (0, h / 2 + 0.05, 0)))
    g.append(mk((0.1, h + 0.1, 0.16), mat, (-w / 2 - 0.05, 0, 0))); g.append(mk((0.1, h + 0.1, 0.16), mat, (w / 2 + 0.05, 0, 0)))
    g.append(swap_uv(mk((w, h, 0.07), mat, (0, 0, 0.0))) if False else mk((w, h, 0.07), mat, (0, 0, 0.0)))
    for yy in (-h * 0.3, h * 0.3): g.append(mk((w, 0.1, 0.04), 'iron', (0, yy, 0.04)))
    g.append(mk((0.05, 0.05, 0.05), 'iron', (w * 0.35, 0, 0.07)))
    return g

def fence_run(a, b, mat='wood_planks', h=1.0, post_every=2.0, rails=2):
    a = np.array(a, float); b = np.array(b, float); L = np.linalg.norm(b - a); n = max(1, int(round(L / post_every)))
    g = []; d = norm(b - a)
    for i in range(n + 1):
        p = a + d * (L * i / n); g.append(beam(p, p + (0, h + 0.05, 0), 0.11, 0.11, mat, r=0.015))
    for k in range(rails):
        y = h * (0.45 + 0.4 * k) if rails > 1 else h * 0.7
        g.append(beam(a + (0, y, 0.0), b + (0, y, 0.0), 0.07, 0.1, mat))
    return g

def barrel(r=0.34, h=0.85, center=(0, 0, 0)):
    prof = [(r * 0.88, 0), (r * 0.96, h * 0.1), (r, h * 0.35), (r * 1.06, h * 0.5), (r, h * 0.65), (r * 0.96, h * 0.9), (r * 0.88, h)]
    g = [lathe(prof, 'wood_planks', seg=18, uvs=1.0, closed_bottom=True).xf(Tm(*center))]
    top = cylinder(r * 0.88, r * 0.88, 0.03, 'wood_planks', seg=18, y0=h - 0.015, caps=(True, True)).xf(Tm(*center)); g.append(top)
    for yy in (0.16, 0.5, 0.84):
        rr = np.interp(yy, [p[1] / h for p in prof], [p[0] for p in prof]) if False else r * 1.0
        g.append(cylinder(rr * 1.05, rr * 1.05, 0.045, 'iron', seg=18, y0=yy * h - 0.02, caps=(False, False)).xf(Tm(*center)))
    return g

def crate(s=0.7, center=(0, 0, 0), rot=0.0):
    g = []; hs = s / 2
    g.append(B((s, s, s), 'wood_planks', center=(0, hs, 0), r=0.02))
    for sx in (-1, 1):
        for sz in (-1, 1): g.append(beam((sx * hs, 0.0, sz * hs), (sx * hs, s, sz * hs), 0.07, 0.07, 'wood_planks'))
    for yy in (0.04, s - 0.04):
        g.append(B((s + 0.04, 0.07, s + 0.04), 'wood_planks', center=(0, yy, 0)))
    return [x.xf(Tm(*center) @ Ry(rot)) for x in g]

def sack(r=0.28, center=(0, 0, 0)):
    prof = [(0.0, 0.0), (r * 0.9, 0.02), (r, r * 0.5), (r * 0.88, r * 1.1), (r * 0.5, r * 1.5), (r * 0.18, r * 1.62), (r * 0.3, r * 1.8), (r * 0.1, r * 1.95)]
    return [lathe(prof, 'canvas', seg=14, uvs=1.0, creases=()).xf(Tm(*center))]

def basket(r=0.3, h=0.28, center=(0, 0, 0)):
    prof = [(r * 0.7, 0), (r * 0.9, h * 0.4), (r, h), (r * 0.94, h)]
    g = [lathe(prof, 'straw', seg=18, closed_bottom=True).xf(Tm(*center))]
    g.append(tube(np.array([(-r, h, 0), (-r * 0.7, h + r * 0.8, 0), (0, h + r * 1.05, 0), (r * 0.7, h + r * 0.8, 0), (r, h, 0)]) + center, [0.012] * 5, 'straw', seg=6))
    return g

def lantern(center=(0, 0, 0), s=1.0):
    g = [cylinder(0.06 * s, 0.06 * s, 0.02 * s, 'iron', seg=8, y0=0).xf(Tm(*center)), cylinder(0.075 * s, 0.075 * s, 0.17 * s, 'lantern_glow', seg=8, y0=0.02 * s, caps=(False, False)).xf(Tm(*center)),
         cylinder(0.01, 0.09 * s, 0.05 * s, 'iron', seg=8, y0=0.19 * s).xf(Tm(*center))]
    return g


def extrude_poly(poly, thick, mat, uvs=1.0):
    """extrude a 2D polygon (x,y; convex or simple CCW) along Z by thick, centred on z=0"""
    poly = np.array(poly, float); n = len(poly); h = thick / 2; g = []
    tris = [(0, i, i + 1) for i in range(1, n - 1)]
    for z, nz in ((h, 1.0), (-h, -1.0)):
        P = np.array([(x, y, z) for x, y in poly]); g.append(Geo(P, [(0, 0, nz)] * n, np.stack([poly[:, 0] * uvs, -poly[:, 1] * uvs], 1), None, tris, mat).fix_winding())
    for i in range(n):
        a = poly[i]; b = poly[(i + 1) % n]; e = b - a; nn = norm((e[1], -e[0], 0))
        P = [(a[0], a[1], -h), (b[0], b[1], -h), (b[0], b[1], h), (a[0], a[1], h)]
        g.append(Geo(P, [nn] * 4, [(0, 0), (np.linalg.norm(e) * uvs, 0), (np.linalg.norm(e) * uvs, thick * uvs), (0, thick * uvs)], None, [(0, 1, 2), (0, 2, 3)], mat).fix_winding())
    return g
