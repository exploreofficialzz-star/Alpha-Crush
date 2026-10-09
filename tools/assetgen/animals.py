"""Animals: SDF-meshed quadrupeds (cow, goat, deer) and a chicken. Rigid parts: Body > Head, Leg_FL/FR/BL/BR, Tail."""
import numpy as np
from meshkit import *
from sdf import *
from gltf import Node
from kit import beam

def sst(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

SPECS = {
    'cow':  dict(L=1.9, W=0.36, Hh=0.42, hb=1.0, leg=0.82, lr=(0.1, 0.058), neck=0.42, head=(0.15, 0.19, 0.28), muz=(0.12, 0.1, 0.12), vox=0.07, ear=0.12, horn='short', tail=0.9, udder=True),
    'goat': dict(L=1.05, W=0.2, Hh=0.24, hb=0.62, leg=0.5, lr=(0.05, 0.03), neck=0.3, head=(0.09, 0.115, 0.17), muz=(0.07, 0.06, 0.08), vox=0.042, ear=0.1, horn='curved', tail=0.2, udder=False, beard=True),
    'deer': dict(L=1.35, W=0.2, Hh=0.26, hb=0.98, leg=0.84, lr=(0.056, 0.032), neck=0.55, head=(0.085, 0.105, 0.2), muz=(0.06, 0.055, 0.1), vox=0.045, ear=0.13, horn='antler', tail=0.18, udder=False),
}

def coat(species, seed):
    def f(p, part='Body'):
        n = fbm3(p * (2.0 if species == 'cow' else 5.0) + seed, 3, seed)
        if species == 'cow':
            patch = sst(-0.02, 0.06, n); base = np.array((0.93, 0.91, 0.86)) * (1 - patch[:, None]) + np.array((0.07, 0.065, 0.06)) * patch[:, None]
        elif species == 'goat':
            belly = sst(0.0, 0.5, (0.6 - p[:, 1]) / 0.3)[:, None]; base = np.array((0.80, 0.72, 0.60)) * (1 - belly) + np.array((0.93, 0.89, 0.8)) * belly
            base = base * (0.9 + 0.25 * n[:, None]); dark = sst(0.2, 0.6, (0.4 - p[:, 1]) / 0.2)[:, None]; base = base * (1 - dark * 0.5)
        else:
            belly = sst(0.0, 1.0, (0.92 - p[:, 1]) / 0.2)[:, None]; base = np.array((0.52, 0.34, 0.2)) * (1 - belly) + np.array((0.84, 0.74, 0.6)) * belly
            spots = (fbm3(p * 22 + seed, 2, seed + 3) > 0.34) * (p[:, 1] > 0.85) * 1.0; base = base * (1 - spots[:, None] * 0.85) + np.array((0.9, 0.86, 0.78)) * spots[:, None] * 0.85
            base = base * (0.88 + 0.25 * n[:, None])
        return np.concatenate([base, np.ones((len(p), 1))], 1)
    return f

def build_quad(species, seed=1, lod=1.0):
    S = SPECS[species]; L, W, Hh, hb, ll = S['L'], S['W'], S['Hh'], S['hb'], S['leg']
    colf = coat(species, seed); v = S['vox'] * lod
    J = {'Body': np.array((0, hb, 0.0)), 'Head': np.array((0, hb + Hh * 0.55 + S['neck'] * 0.55, -L * 0.40 - S['neck'] * 0.5)),
         'Leg_FL': np.array((-W * 0.8, hb - Hh * 0.35, -L * 0.30)), 'Leg_FR': np.array((W * 0.8, hb - Hh * 0.35, -L * 0.30)),
         'Leg_BL': np.array((-W * 0.8, hb - Hh * 0.25, L * 0.30)), 'Leg_BR': np.array((W * 0.8, hb - Hh * 0.25, L * 0.30)), 'Tail': np.array((0, hb + Hh * 0.3, L * 0.5))}
    hd = np.array(S['head'])
    def d_body(p):
        c = np.array((0, hb, 0)); ds = [ell(p, c, (W, Hh, L * 0.5)), ell(p, c + (0, Hh * 0.08, -L * 0.22), (W * 1.04, Hh * 1.03, L * 0.3)), ell(p, c + (0, 0, L * 0.26), (W * 0.98, Hh * 0.98, L * 0.27))]
        base = np.array((0, hb + Hh * 0.5, -L * 0.42)); top = J['Head'] + (0, -hd[1] * 0.2, hd[2] * 0.6)
        ds.append(cap(p, base, top + (0, 0, hd[2] * 0.1), W * 0.62, W * 0.4))
        if S.get('udder'): ds.append(ell(p, c + (0, -Hh * 0.95, L * 0.28), (0.13, 0.11, 0.14)))
        return union(ds, 0.1 * W + 0.04)
    def d_head(p):
        h = J['Head']; ds = [ell(p, h, hd), ell(p, h + (0, -hd[1] * 0.35, -hd[2] * 0.85), S['muz']), cap(p, h + (0, hd[1] * 0.2, 0), h + (0, -hd[1] * 0.1, -hd[2] * 0.9), hd[0] * 0.8, S['muz'][0] * 0.9)]
        for sx in (-1, 1):
            e = h + (sx * hd[0] * 0.95, hd[1] * 0.45, hd[2] * 0.15); ds.append(ell(p, e + (sx * S['ear'] * 0.5, S['ear'] * 0.2, 0), (S['ear'] * 0.6, S['ear'] * 0.2, S['ear'] * 0.35)))
            if S['horn'] == 'short': ds.append(cap(p, h + (sx * hd[0] * 0.6, hd[1] * 0.8, hd[2] * 0.1), h + (sx * hd[0] * 1.35, hd[1] * 1.25, hd[2] * 0.0), 0.028, 0.012))
        if S.get('beard'): ds.append(cap(p, h + (0, -hd[1] * 0.8, -hd[2] * 0.7), h + (0, -hd[1] * 1.9, -hd[2] * 0.6), 0.022, 0.008))
        d = union(ds, 0.02)
        for sx in (-1, 1): d = smax(d, -sph(p, h + (sx * hd[0] * 0.78, hd[1] * 0.25, -hd[2] * 0.42), 0.012 + 0.004 * (hd[0] > 0.12)), 0.006)
        return d
    def d_leg(p, name):
        j = J[name]; front = 'F' in name; sx = -1 if name.endswith('L') else 1
        knee = j + (0, -ll * 0.5, 0.05 * (1 if front else -1) * 0.0 + (0.04 if not front else 0.0)); foot = np.array((j[0], 0.06, j[2] + (0.07 if not front else 0.0)))
        ds = [sph(p, j, S['lr'][0] * 1.25), cap(p, j, knee, S['lr'][0], S['lr'][1] * 1.1), cap(p, knee, foot + (0, 0.05, 0), S['lr'][1] * 1.1, S['lr'][1]), ell(p, foot + (0, 0.02, -0.01), (S['lr'][1] * 1.3, 0.06, S['lr'][1] * 1.5))]
        return smax(union(ds, 0.03), -p[..., 1], 0.003)
    def d_tail(p):
        t = J['Tail']; return union([cap(p, t, t + (0, -S['tail'] * 0.8, S['tail'] * 0.18), 0.03, 0.02), ell(p, t + (0, -S['tail'] * 0.9, S['tail'] * 0.2), (0.04, S['tail'] * 0.12, 0.04))], 0.02) if S['tail'] > 0.5 else cap(p, t, t + (0, S['tail'] * 0.7, S['tail'] * 0.4), 0.035, 0.012)
    def paint(fn, part):
        def m(p):
            c = fn(p, part)
            if part == 'Head':
                h = J['Head']; muzzle = sst(0.7, 1.0, (-(p[:, 2] - h[2]) / hd[2]))[:, None] * (p[:, 1:2] < h[1] + hd[1] * 0.1)
                nose = np.array((0.85, 0.62, 0.6)) if species == 'cow' else np.array((0.2, 0.15, 0.13))
                c[:, :3] = c[:, :3] * (1 - muzzle) + nose * muzzle
                for sx in (-1, 1):
                    d = np.linalg.norm(p - (h + (sx * hd[0] * 0.78, hd[1] * 0.25, -hd[2] * 0.42)), axis=1); e = sst(0.026, 0.014, d)[:, None]; c[:, :3] = c[:, :3] * (1 - e) + 0.03 * e
                if species != 'cow':
                    horn = (p[:, 1] > h[1] + hd[1] * 0.85)[:, None]; hc = np.array((0.78, 0.7, 0.55)) if species == 'goat' else np.array((0.55, 0.45, 0.33)); c[:, :3] = c[:, :3] * (1 - horn) + hc * horn
                else:
                    horn = (p[:, 1] > h[1] + hd[1] * 0.85)[:, None]; c[:, :3] = c[:, :3] * (1 - horn) + np.array((0.85, 0.82, 0.72)) * horn
            if part.startswith('Leg'):
                hoof = sst(0.14, 0.06, p[:, 1])[:, None]; c[:, :3] = c[:, :3] * (1 - hoof) + 0.07 * hoof
            return c
        return m
    out = {}; boxes = {'Body': ((-W * 1.3, hb - Hh * 1.6, -L * 0.6), (W * 1.3, hb + Hh * 1.3, L * 0.6)),
                       'Head': (J['Head'] - (0.5, 0.5, 0.55), J['Head'] + (0.5, 0.6, 0.45)), 'Tail': (J['Tail'] - (0.2, 1.1, 0.2), J['Tail'] + (0.2, 0.4, 0.6))}
    for nm in ('Leg_FL', 'Leg_FR', 'Leg_BL', 'Leg_BR'): boxes[nm] = (J[nm] - (0.2, ll + 0.15, 0.25), J[nm] + (0.2, 0.2, 0.25))
    fns = {'Body': d_body, 'Head': d_head, 'Tail': d_tail}
    for nm in ('Leg_FL', 'Leg_FR', 'Leg_BL', 'Leg_BR'): fns[nm] = (lambda p, nm=nm: d_leg(p, nm))
    for nm, (lo, hi) in boxes.items():
        vv = v * (0.65 if nm == 'Head' else 1.0)
        g = mesh_sdf(fns[nm], np.array(lo) - 0.05, np.array(hi) + 0.05, vv, 'animal_hide', mask_fn=paint(colf, nm))
        out[nm] = g
    horn_geos = []
    hh = np.array((0, 0, 0.0))
    for sx in (-1, 1):
        if S['horn'] == 'curved':
            base = np.array((sx * 0.04, hd[1] * 0.8, hd[2] * 0.0)); pts = [base, base + (sx * 0.03, hd[1] * 1.0, hd[2] * 0.15), base + (sx * 0.06, hd[1] * 1.45, hd[2] * 0.75), base + (sx * 0.07, hd[1] * 1.05, hd[2] * 1.35)]
            from scipy.interpolate import CubicSpline
            t = np.linspace(0, 1, 4); cs = CubicSpline(t, np.array(pts)); tt = np.linspace(0, 1, 10); path = cs(tt)
            g = tube(path, np.linspace(0.026, 0.006, 10), 'animal_hide', seg=7); g.C[:] = (0.78, 0.7, 0.55, 1.0); horn_geos.append(g)
        if S['horn'] == 'antler':
            m = np.array((sx * 0.035, hd[1] * 0.85, hd[2] * 0.2)); t1 = m + (sx * 0.09, 0.30, 0.12); t2 = t1 + (sx * 0.05, 0.22, -0.06); b1 = m + (sx * 0.05, 0.12, -0.02); b2 = b1 + (sx * 0.12, 0.14, -0.12)
            c3 = t1 + (0, -0.03, 0); c4 = c3 + (sx * 0.12, 0.13, 0.1)
            for pts, r0, r1 in (([m, m + (sx * 0.04, 0.15, 0.06), t1, t2], 0.02, 0.008), ([b1, b2], 0.014, 0.006), ([c3, c4], 0.012, 0.005)):
                path = np.array([np.array(pts[0]) + (np.array(pts[-1]) - np.array(pts[0])) * k for k in np.linspace(0, 1, 6)]) if len(pts) == 2 else np.array([np.interp(k, np.linspace(0, 1, len(pts)), [q[i] for q in pts]) for i in range(3) for k in [0]]) 
                if len(pts) > 2:
                    from scipy.interpolate import CubicSpline
                    cs = CubicSpline(np.linspace(0, 1, len(pts)), np.array(pts)); path = cs(np.linspace(0, 1, 8))
                g = tube(path, np.linspace(r0, r1, len(path)), 'animal_hide', seg=6); g.C[:] = (0.55, 0.45, 0.33, 1.0); horn_geos.append(g)
    nodes = {}
    for nm in ('Body',):
        nodes[nm] = Node(nm, [out[nm].xf(Tm(*(-J[nm])))], t=tuple(J[nm]))
    for nm in ('Head', 'Leg_FL', 'Leg_FR', 'Leg_BL', 'Leg_BR', 'Tail'):
        extra = [h.xf(Tm(*(J['Head'] * 0 + (0, 0, 0))) @ Tm(*(-(J[nm]) + J['Head'] * 0))) for h in horn_geos] if nm == 'Head' else []
        nodes[nm] = Node(nm, [out[nm].xf(Tm(*(-J[nm])))] + [h.xf(Tm(*(J['Head'] - J['Head']))) for h in extra] if False else [out[nm].xf(Tm(*(-J[nm])))], t=tuple(J[nm] - J['Body']))
        if nm == 'Head': nodes[nm].geos += [h.xf(Tm(*(-hh))) for h in horn_geos]
        nodes['Body'].add(nodes[nm])
    return Node(species.capitalize(), [], children=[nodes['Body'], Node(f'COL_BOX_{round(W*200)}_{round((hb+Hh)*100)}_{round(L*100)}', t=(0, (hb + Hh) / 2, 0))])

def build_chicken(seed=1, lod=1.0):
    v = 0.019 * lod; hc = np.array((0, 0.25, 0)); hp = np.array((0, 0.41, -0.145))
    def d_body(p):
        ds = [ell(p, hc + (0, 0, 0.02), (0.1, 0.115, 0.165)), ell(p, hc + (0, 0.04, -0.07), (0.092, 0.115, 0.1)), ell(p, hc + (0, 0.05, 0.19), (0.05, 0.07, 0.07)), cap(p, hc + (0, 0.07, -0.07), hp + (0, -0.03, 0), 0.055, 0.036)]
        for sx in (-1, 1): ds.append(ell(p, hc + (sx * 0.095, 0.015, 0.02), (0.02, 0.07, 0.11)))
        for a in (-0.6, -0.3, 0.0, 0.3, 0.6): ds.append(cap(p, hc + (a * 0.03, 0.06, 0.17), hc + (a * 0.12, 0.2 - abs(a) * 0.05, 0.3), 0.02, 0.007))
        return union(ds, 0.03)
    def d_head(p):
        ds = [sph(p, hp, 0.042), cap(p, hp + (0, -0.005, -0.03), hp + (0, -0.02, -0.075), 0.017, 0.004), ell(p, hp + (0, 0.05, -0.01), (0.008, 0.03, 0.03)), ell(p, hp + (0, -0.05, -0.05), (0.01, 0.025, 0.012))]
        return union(ds, 0.008)
    def d_leg(p, sx):
        j = np.array((sx * 0.05, 0.17, 0.0)); k = np.array((sx * 0.05, 0.09, 0.01)); f = np.array((sx * 0.05, 0.012, -0.03))
        ds = [cap(p, j, k, 0.014, 0.011), cap(p, k, f + (0, 0.01, 0.03), 0.011, 0.009)]
        for a in (-0.5, 0.0, 0.5): ds.append(cap(p, f + (0, 0, 0.03), f + (np.sin(a) * 0.03, 0, -0.045), 0.0075, 0.005))
        return smax(union(ds, 0.01), -p[..., 1], 0.001)
    def paint(part):
        def m(p):
            n = fbm3(p * 25, 2, seed)[:, None]; c = np.tile(np.array((0.93, 0.9, 0.82)), (len(p), 1)) * (0.93 + 0.12 * n)
            if part == 'Body':
                tail = sst(0.0, 0.06, p[:, 2] - 0.17)[:, None]; c = c * (1 - tail) + np.array((0.35, 0.22, 0.12)) * tail * (0.8 + 0.4 * n)
                wing = (np.abs(p[:, 0]) > 0.075)[:, None]; c = c * (1 - 0.5 * wing) + np.array((0.62, 0.42, 0.22)) * 0.5 * wing
            if part == 'Head':
                comb = (p[:, 1] > hp[1] + 0.035)[:, None] | (p[:, 1] < hp[1] - 0.034)[:, None]; c = c * (1 - comb) + np.array((0.8, 0.1, 0.08)) * comb
                beak = (p[:, 2] < hp[2] - 0.035)[:, None]; c = c * (1 - beak) + np.array((0.95, 0.65, 0.15)) * beak
                for sx in (-1, 1):
                    d = np.linalg.norm(p - (hp + (sx * 0.034, 0.012, -0.022)), axis=1); e = sst(0.009, 0.005, d)[:, None]; c = c * (1 - e) + 0.02 * e
            if part.startswith('Leg'): c = np.tile(np.array((0.9, 0.62, 0.18)), (len(p), 1))
            return np.concatenate([c, np.ones((len(p), 1))], 1)
        return m
    parts = {'Body': (d_body, (-0.2, 0.1, -0.1), (0.2, 0.62, 0.38)), 'Head': (d_head, (-0.08, 0.38, -0.27), (0.08, 0.56, -0.02))}
    parts['Leg_L'] = (lambda p: d_leg(p, -1), (-0.1, -0.01, -0.12), (0.0, 0.22, 0.08)); parts['Leg_R'] = (lambda p: d_leg(p, 1), (0.0, -0.01, -0.12), (0.1, 0.22, 0.08))
    pivots = {'Body': hc, 'Head': hp, 'Leg_L': np.array((-0.05, 0.17, 0)), 'Leg_R': np.array((0.05, 0.17, 0))}
    geos = {nm: mesh_sdf(fn, np.array(lo) - 0.03, np.array(hi) + 0.03, v if nm != 'Head' else v * 0.7, 'animal_hide', mask_fn=paint(nm)) for nm, (fn, lo, hi) in parts.items()}
    body = Node('Body', [geos['Body'].xf(Tm(*(-pivots['Body'])))], t=tuple(pivots['Body']))
    for nm in ('Head', 'Leg_L', 'Leg_R'): body.add(Node(nm, [geos[nm].xf(Tm(*(-pivots[nm])))], t=tuple(pivots[nm] - pivots['Body'])))
    return Node('Chicken', [], children=[body, Node('COL_BOX_30_60_50', t=(0, 0.3, 0))])
