"""Human avatar generator: smooth SDF body parts meshed with marching cubes, exported as a rigid
joint hierarchy (ball-jointed so rotations leave no cracks).  Faces -Z, Y up, metres.

Vertex colour channels (consumed by the avatar shader):  R = top/shirt  G = trousers  B = leather (boots, gloves, belt)  A = eyebrows."""
import numpy as np
from meshkit import Geo, merge, norm, fbm3
from sdf import *
from gltf import Node

def sst(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

# joint origins in template (male, world) space ------------------------------------------------
def joints():
    J = {'Hips': (0, 0.95, 0), 'Spine': (0, 1.00, 0), 'Neck': (0, 1.50, 0), 'Head': (0, 1.60, 0.005)}
    for s, n in ((1, 'R'), (-1, 'L')):
        J[f'UpperArm_{n}'] = (s * 0.19, 1.43, 0); J[f'Forearm_{n}'] = (s * 0.213, 1.15, 0); J[f'Hand_{n}'] = (s * 0.228, 0.885, -0.012)
        J[f'Thigh_{n}'] = (s * 0.088, 0.93, 0); J[f'Shin_{n}'] = (s * 0.092, 0.505, -0.005); J[f'Foot_{n}'] = (s * 0.09, 0.088, 0.0)
    return J
PARENT = {'Spine': 'Hips', 'Neck': 'Spine', 'Head': 'Neck', 'Thigh_R': 'Hips', 'Thigh_L': 'Hips', 'Shin_R': 'Thigh_R', 'Shin_L': 'Thigh_L',
          'Foot_R': 'Shin_R', 'Foot_L': 'Shin_L', 'UpperArm_R': 'Spine', 'UpperArm_L': 'Spine', 'Forearm_R': 'UpperArm_R', 'Forearm_L': 'UpperArm_L',
          'Hand_R': 'Forearm_R', 'Hand_L': 'Forearm_L'}
ORDER = ['Hips', 'Spine', 'Neck', 'Head', 'UpperArm_R', 'Forearm_R', 'Hand_R', 'UpperArm_L', 'Forearm_L', 'Hand_L',
         'Thigh_R', 'Shin_R', 'Foot_R', 'Thigh_L', 'Shin_L', 'Foot_L']

WAIST = lambda p: ell(p, (0, 1.0, 0), (0.138, 0.075, 0.098))

# body part SDFs (template space) -----------------------------------------------------------------
def d_pelvis(p, fem=False):
    ds = [ell(p, (0, 0.945, 0), (0.150, 0.100, 0.098)), ell(p, (0.072, 0.905, 0.034), (0.074, 0.072, 0.07)), ell(p, (-0.072, 0.905, 0.034), (0.074, 0.072, 0.07)),
          WAIST(p), sph(p, (0.088, 0.93, 0), 0.084), sph(p, (-0.088, 0.93, 0), 0.084)]
    if fem: ds += [ell(p, (0.094, 0.91, 0.0), (0.08, 0.1, 0.092)), ell(p, (-0.094, 0.91, 0.0), (0.08, 0.1, 0.092))]
    return union(ds, 0.05)

def d_torso(p, fem=False):
    ds = [WAIST(p), ell(p, (0, 1.10, 0), (0.128, 0.13, 0.092)), ell(p, (0, 1.31, 0.008), (0.154, 0.165, 0.102)), ell(p, (0, 1.428, 0.016), (0.150, 0.066, 0.082))]
    for s in (-1, 1):
        ds += [ell(p, (s * 0.07, 1.345, -0.062), (0.066, 0.046, 0.034)), sph(p, (s * 0.185, 1.435, 0.0), 0.06)]
        if fem: ds += [ell(p, (s * 0.078, 1.318, -0.07), (0.066, 0.064, 0.056))]
    ds += [cap(p, (0, 1.45, 0.0), (0, 1.52, 0.0), 0.066, 0.058)]
    for s in (-1, 1): ds += [cap(p, (s * 0.04, 1.505, 0.005), (s * 0.15, 1.455, 0.0), 0.042, 0.05)]
    return union(ds, 0.05)

def d_neck(p):
    return union([cap(p, (0, 1.49, 0.0), (0, 1.62, 0.012), 0.060, 0.052), sph(p, (0, 1.50, 0), 0.062), sph(p, (0, 1.605, 0.008), 0.054)], 0.02)

def d_head(p, fem=False):
    ds = [ell(p, (0, 1.70, 0.008), (0.088, 0.108, 0.10)), ell(p, (0, 1.655, -0.018), (0.078 - (0.004 if fem else 0), 0.088, 0.088)), sph(p, (0, 1.608, -0.05), 0.034 if fem else 0.037),
          ell(p, (0, 1.628, -0.045), (0.064 - (0.006 if fem else 0), 0.05, 0.06)), ell(p, (0, 1.677, -0.098), (0.0125, 0.026, 0.02)), sph(p, (0, 1.655, -0.106), 0.0125),
          ell(p, (0, 1.715, -0.085), (0.07, 0.013 if fem else 0.016, 0.02)), sph(p, (0.05, 1.66, -0.07), 0.026), sph(p, (-0.05, 1.66, -0.07), 0.026), sph(p, (0.043, 1.688, -0.082), 0.02), sph(p, (-0.043, 1.688, -0.082), 0.02),
          ell(p, (0.092, 1.69, 0.005), (0.012, 0.03, 0.018)), ell(p, (-0.092, 1.69, 0.005), (0.012, 0.03, 0.018)),
          ell(p, (0, 1.631, -0.092), (0.025, 0.0105 if fem else 0.009, 0.012)), sph(p, (0, 1.606, 0.008), 0.05)]
    d = union(ds, 0.025)
    for s in (-1, 1): d = smax(d, -sph(p, (s * 0.034, 1.6965, -0.091), 0.0188), 0.006)
    return d

def d_uarm(p, s):
    sh = (s * 0.19, 1.43, 0); el = (s * 0.213, 1.15, 0)
    return union([sph(p, sh, 0.056), cap(p, sh, el, 0.052, 0.043), ell(p, (s * 0.2, 1.34, -0.006), (0.05, 0.075, 0.05)), sph(p, el, 0.044)], 0.04)

def d_farm(p, s):
    el = (s * 0.213, 1.15, 0); wr = (s * 0.228, 0.885, -0.012)
    return union([sph(p, el, 0.043), cap(p, el, wr, 0.042, 0.031), ell(p, (s * 0.217, 1.07, -0.004), (0.044, 0.085, 0.046)), sph(p, wr, 0.032)], 0.04)

def d_hand(p, s):
    W = np.array((s * 0.228, 0.885, -0.012)); ds = [sph(p, W, 0.032), ell(p, W + (0, -0.06, -0.004), (0.038, 0.057, 0.0175))]
    ds += [cap(p, W + (-s * 0.028, -0.04, -0.006), W + (-s * 0.042, -0.088, -0.034), 0.0105, 0.0085), cap(p, W + (-s * 0.042, -0.088, -0.034), W + (-s * 0.040, -0.115, -0.05), 0.0085, 0.0075)]
    for i, L in enumerate((0.078, 0.088, 0.082, 0.066)):
        x = W[0] + s * (-0.025 + 0.0165 * i); a = np.array((x, W[1] - 0.108, W[2] - 0.004)); b = a + (0, -0.55 * L, -0.06 * L); c = b + (0, -0.42 * L, -0.30 * L)
        ds += [cap(p, a, b, 0.0092, 0.0085), cap(p, b, c, 0.0085, 0.0072)]
    return union(ds, 0.006)

def d_thigh(p, s, pockets=True):
    hp = (s * 0.088, 0.93, 0); kn = (s * 0.092, 0.505, -0.005)
    d = union([sph(p, hp, 0.088), cap(p, hp, kn, 0.082, 0.058), ell(p, (s * 0.096, 0.76, -0.022), (0.074, 0.17, 0.074)), ell(p, (s * 0.09, 0.72, 0.03), (0.066, 0.16, 0.062)), sph(p, kn, 0.058)], 0.05)
    if pockets: d = smin(d, rbx(p, (s * 0.158, 0.70, -0.012), (0.024, 0.08, 0.052), 0.014), 0.012)
    return d

def d_shin(p, s):
    kn = (s * 0.092, 0.505, -0.005); an = (s * 0.09, 0.088, 0.0)
    return union([sph(p, kn, 0.058), cap(p, kn, an, 0.056, 0.042), ell(p, (s * 0.09, 0.37, 0.026), (0.05, 0.105, 0.056)), sph(p, an, 0.046)], 0.04)

def d_foot(p, s):
    x = s * 0.09
    d = union([sph(p, (x, 0.088, 0), 0.04), ell(p, (x, 0.05, -0.05), (0.046, 0.042, 0.118)), sph(p, (x, 0.055, 0.038), 0.042), ell(p, (x, 0.034, -0.135), (0.041, 0.032, 0.062))], 0.03)
    return smax(d, -p[..., 1], 0.004)

# masks (R shirt, G trousers, B leather, A brows) ------------------------------------------------------
def _m(R, G, B, A=None):
    A = np.zeros_like(R) if A is None else A
    return np.stack([R, G, B, A], -1)

def m_pelvis(p):
    y = p[:, 1]; shirt = sst(0.955, 1.045, y); return _m(shirt, 1 - shirt, np.zeros(len(p)))
def m_torso(p):
    y = p[:, 1]; hem = sst(0.955, 1.045, y); neck = 1 - sst(1.495, 1.575, y); sh = hem * neck
    return _m(sh, 1 - hem, np.zeros(len(p)))
def m_neck(p): return _m(1 - sst(1.50, 1.58, p[:, 1]), np.zeros(len(p)), np.zeros(len(p)))
def m_head(p):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    brow = np.exp(-((y - (1.7195 + 0.0045 * np.clip((np.abs(x) - 0.012) / 0.04, 0, 1))) / 0.0062) ** 2) * sst(0.010, 0.022, np.abs(x)) * (1 - sst(0.06, 0.074, np.abs(x))) * sst(-0.055, -0.075, z)
    z0 = np.zeros(len(p)); return _m(z0, z0, z0, brow)
def m_uarm(p): o = np.zeros(len(p)); return _m(o + 1, o, o)
def m_farm(p): y = p[:, 1]; o = np.zeros(len(p)); return _m(sst(1.00, 1.08, y), o, o)
def m_hand(p, s):
    y = p[:, 1]; o = np.zeros(len(p)); return _m(o, o, sst(0.74, 0.80, y))
def m_thigh(p): o = np.zeros(len(p)); return _m(o, o + 1, o)
def m_shin(p): y = p[:, 1]; b = 1 - sst(0.17, 0.25, y); return _m(np.zeros(len(p)), 1 - b, b)
def m_foot(p): o = np.zeros(len(p)); return _m(o, o, o + 1)

def uv_zero(v): return np.zeros((len(v), 2))
def uv_sole(v): y = v[:, 1]; return np.stack([1 - sst(0.020, 0.032, y), np.zeros(len(v))], -1)
def uv_lips(v):
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    m = np.exp(-((x / 0.026) ** 2 + ((y - 1.6195) / 0.0078) ** 2)) * sst(-0.080, -0.090, z)
    return np.stack([np.zeros(len(v)), m], -1)

THICK = np.array([0.005, 0.005, 0.003, 0.0])   # cloth thickness per channel

def clothed(dfn, mfn):
    def f(p):
        d = dfn(p); m = mfn(p); return d - m[:, :3] @ THICK[:3]
    return f

# hair -------------------------------------------------------------------------------------------------
def d_hair(p, style):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    outer = union([ell(p, (0, 1.706, 0.012), (0.099, 0.119, 0.109)), ell(p, (0, 1.748, -0.035), (0.082, 0.058, 0.092)), ell(p, (0.0, 1.76, 0.0), (0.07, 0.04, 0.075))], 0.03)
    if style == 'long':
        outer = union([outer, ell(p, (0, 1.69, 0.045), (0.098, 0.12, 0.07))], 0.03)
    inner = ell(p, (0, 1.695, 0.008), (0.076, 0.097, 0.089))
    d = np.maximum(outer, -inner)
    front = 1.742 + 0.012 * np.sin(x * 55)
    yh = front - (front - (1.62 if style == 'long' else 1.655)) * sst(-0.02, 0.085, z)
    yh = np.minimum(yh, np.where(np.abs(x) > 0.078, 1.69 - 0.02 * (style == 'long'), 9.0))
    d = np.maximum(d, yh - y)
    d = d + 0.006 * fbm3(p * 55.0, 3, 5) + 0.003 * np.sin((x + z) * 90)
    if style == 'long':   # ponytail
        tail = union([cap(p, (0, 1.735, 0.085), (0, 1.66, 0.165), 0.034, 0.03), cap(p, (0, 1.66, 0.165), (0, 1.50, 0.15), 0.03, 0.022), cap(p, (0, 1.50, 0.15), (0, 1.40, 0.14), 0.022, 0.006)], 0.03)
        d = smin(d, tail + 0.004 * np.sin(y * 120), 0.02)
    return d

def d_eye(p, c): return sph(p, c, 0.0112)

def eye_geo(cx, cy, cz):
    from sdf import mesh_sdf
    g = mesh_sdf(lambda p: sph(p, (cx, cy, cz), 0.0112), (cx - 0.02, cy - 0.02, cz - 0.02), (cx + 0.02, cy + 0.02, cz + 0.02), 0.003, 'avatar_eye')
    d = g.P - (cx, cy, cz); ang = np.arccos(np.clip(-d[:, 2] / np.linalg.norm(d, axis=1), -1, 1))
    iris = sst(0.60, 0.52, ang); pupil = sst(0.30, 0.24, ang)
    col = np.array((0.96, 0.95, 0.92)) * (1 - iris[:, None]) + np.array((0.27, 0.17, 0.09)) * iris[:, None]
    col = col * (1 - pupil[:, None]) + np.array((0.02, 0.02, 0.02)) * pupil[:, None]
    g.C = np.concatenate([col, np.ones((len(col), 1))], 1); return g

# assembly --------------------------------------------------------------------------------------------
PARTS = {  # name -> (sdf, mask, bbox lo, bbox hi, voxel)
}

def build(gender='male', lod=1.0, hair_style=None):
    fem = gender == 'female'
    sc = np.array((0.93, 0.935, 0.93)) if fem else np.array((1.0, 1.0, 1.0))
    hair_style = hair_style or ('long' if fem else 'short')
    J = {k: np.array(v) * sc for k, v in joints().items()}

    def wrap(fn):    # evaluate template SDF at p / scale
        if not fem: return fn
        return lambda p: fn(p / sc) * float(sc.min())
    def wmask(fn):
        if not fem: return fn
        return lambda p: fn(p / sc)

    parts = {
        'Hips': (lambda p: d_pelvis(p, fem), m_pelvis, (-0.2, 0.78, -0.16), (0.2, 1.07, 0.18), 0.031),
        'Spine': (lambda p: d_torso(p, fem), m_torso, (-0.25, 0.92, -0.16), (0.25, 1.56, 0.16), 0.031),
        'Neck': (d_neck, m_neck, (-0.07, 1.44, -0.07), (0.07, 1.66, 0.08), 0.017),
        'Head': (lambda p: d_head(p, fem), m_head, (-0.11, 1.55, -0.14), (0.11, 1.82, 0.13), 0.0078),
    }
    for s, n in ((1, 'R'), (-1, 'L')):
        parts[f'UpperArm_{n}'] = (lambda p, s=s: d_uarm(p, s), m_uarm, (s * 0.19 - 0.09, 1.08, -0.09), (s * 0.19 + 0.09, 1.5, 0.09), 0.026)
        parts[f'Forearm_{n}'] = (lambda p, s=s: d_farm(p, s), m_farm, (s * 0.22 - 0.07, 0.84, -0.08), (s * 0.22 + 0.07, 1.2, 0.08), 0.024)
        parts[f'Hand_{n}'] = (lambda p, s=s: d_hand(p, s), (lambda p, s=s: m_hand(p, s)), (s * 0.228 - 0.07, 0.72, -0.09), (s * 0.228 + 0.07, 0.93, 0.05), 0.0105)
        parts[f'Thigh_{n}'] = (lambda p, s=s: d_thigh(p, s), m_thigh, (s * 0.09 - 0.12, 0.44, -0.11), (s * 0.09 + 0.12, 1.0, 0.11), 0.03)
        parts[f'Shin_{n}'] = (lambda p, s=s: d_shin(p, s), m_shin, (s * 0.09 - 0.09, 0.04, -0.09), (s * 0.09 + 0.09, 0.56, 0.1), 0.026)
        parts[f'Foot_{n}'] = (lambda p, s=s: d_foot(p, s), m_foot, (s * 0.09 - 0.07, -0.01, -0.22), (s * 0.09 + 0.07, 0.15, 0.09), 0.0155)

    geos = {}
    for name, (dfn, mfn, lo, hi, vox) in parts.items():
        lo_s = np.array(lo) * sc - 0.035; hi_s = np.array(hi) * sc + 0.035; v = vox * lod
        uvf = uv_sole if name.startswith('Foot') else (uv_lips if name == 'Head' else uv_zero)
        sdf_fn = wrap(dfn) if name == 'Head' else wrap(clothed(dfn, mfn))
        geos[name] = mesh_sdf(sdf_fn, lo_s, hi_s, v, 'avatar_body', mask_fn=wmask(mfn), uv_fn=(lambda vv, uvf=uvf: uvf(vv / sc)))
    # hair & eyes (head-local after translation)
    hair = mesh_sdf(wrap(lambda p: d_hair(p, hair_style)), np.array((-0.125, 1.56, -0.14)) * sc, np.array((0.125, 1.84, 0.26 if hair_style == 'long' else 0.14)) * sc, 0.0125 * lod, 'avatar_hair')
    if hair_style == 'long': hair = mesh_sdf(wrap(lambda p: d_hair(p, hair_style)), np.array((-0.125, 1.38, -0.14)) * sc, np.array((0.125, 1.84, 0.26)) * sc, 0.0125 * lod, 'avatar_hair')
    eyes = [eye_geo(*(np.array((s * 0.034, 1.70, -0.0845)) * sc)) for s in (1, -1)]

    # node hierarchy with local offsets
    nodes = {}
    for name in ORDER:
        o = J[name]; par = PARENT.get(name); po = J[par] if par else np.zeros(3)
        local = o - po
        g = geos[name].xf(__import__('meshkit').Tm(*(-o))) if geos.get(name) is not None else None
        nodes[name] = Node(name, [g] if g is not None else [], t=tuple(local))
        if par: nodes[par].add(nodes[name])
    head_o = J['Head']
    nodes['Head'].add(Node('Hair', [hair.xf(__import__('meshkit').Tm(*(-head_o)))]))
    for s, e in zip((1, -1), eyes):
        nodes['Head'].add(Node('Eye_R' if s == 1 else 'Eye_L', [e.xf(__import__('meshkit').Tm(*(-head_o)))]))
    # attachment points
    nodes['Spine'].add(Node('Attach_Back', t=tuple(np.array((0, 1.30, 0.115)) * sc - J['Spine'])))
    nodes['Head'].add(Node('Attach_Hat', t=tuple(np.array((0, 1.745, 0.0)) * sc - head_o)))
    root = Node('Avatar', [], children=[nodes['Hips']])
    return root, geos, hair, eyes, J

PALETTE = {'skin': (0.78, 0.58, 0.45), 'shirt': (0.27, 0.36, 0.50), 'pants': (0.31, 0.34, 0.22), 'leather': (0.30, 0.19, 0.11), 'hair': (0.13, 0.08, 0.05)}

def bake_preview(g, pal=PALETTE):
    if g.mat != 'avatar_body':
        return g
    ss = lambda x: np.clip((x - 0.35) / 0.30, 0, 1) ** 2 * (3 - 2 * np.clip((x - 0.35) / 0.30, 0, 1))
    c = ss(g.C); sk = np.array(pal['skin'])
    out = np.tile(sk, (len(c), 1)).astype(float)
    for k, name in enumerate(('shirt', 'pants', 'leather', 'hair')):
        out = out * (1 - c[:, k:k + 1]) + np.array(pal[name]) * c[:, k:k + 1]
    sole = ss(g.UV[:, 0:1]); out = out * (1 - sole) + np.array((0.08, 0.07, 0.06)) * sole
    lips = ss(g.UV[:, 1:2]) * 0.8; out = out * (1 - lips) + np.array((0.62, 0.30, 0.28)) * lips
    h = g.copy(); h.C = np.concatenate([out, np.ones((len(out), 1))], 1); h.mat = 'preview'; return h
