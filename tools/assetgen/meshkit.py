"""Tiny procedural-modelling kit (numpy only). Meshes are triangle soups with per-vertex
position / normal / uv / colour and a *material name* that the game maps to a PBR material.

Conventions (match Godot): +Y up, metres, models face -Z, glTF counter-clockwise front faces
(Godot's importer flips them to its clockwise convention)."""
import numpy as np

# ------------------------------------------------------------------ transforms
def Tm(x=0, y=0, z=0):
    m = np.eye(4); m[:3, 3] = (x, y, z); return m
def Sm(x=1, y=None, z=None):
    y = x if y is None else y; z = x if z is None else z
    return np.diag([x, y, z, 1.0])
def Rx(d):
    c, s = np.cos(np.radians(d)), np.sin(np.radians(d)); m = np.eye(4); m[1, 1] = c; m[1, 2] = -s; m[2, 1] = s; m[2, 2] = c; return m
def Ry(d):
    c, s = np.cos(np.radians(d)), np.sin(np.radians(d)); m = np.eye(4); m[0, 0] = c; m[0, 2] = s; m[2, 0] = -s; m[2, 2] = c; return m
def Rz(d):
    c, s = np.cos(np.radians(d)), np.sin(np.radians(d)); m = np.eye(4); m[0, 0] = c; m[0, 1] = -s; m[1, 0] = s; m[1, 1] = c; return m

def norm(v, eps=1e-9):
    v = np.asarray(v, float); n = np.linalg.norm(v, axis=-1, keepdims=True); return v / np.maximum(n, eps)

# ------------------------------------------------------------------ geometry container
class Geo:
    def __init__(self, P, N, UV, C, T, mat, double=False):
        self.P = np.asarray(P, float).reshape(-1, 3)
        self.N = np.asarray(N, float).reshape(-1, 3)
        n = len(self.P)
        self.UV = np.zeros((n, 2)) if UV is None else np.asarray(UV, float).reshape(-1, 2)
        self.C = np.ones((n, 4)) if C is None else np.asarray(C, float).reshape(-1, 4)
        self.T = np.asarray(T, np.int64).reshape(-1, 3)
        self.mat = mat; self.double = double

    def copy(self):
        return Geo(self.P.copy(), self.N.copy(), self.UV.copy(), self.C.copy(), self.T.copy(), self.mat, self.double)

    def xf(self, M):
        """apply a 4x4 transform (returns a new Geo)"""
        g = self.copy(); M = np.asarray(M, float)
        g.P = g.P @ M[:3, :3].T + M[:3, 3]
        try: Mi = np.linalg.inv(M[:3, :3]).T
        except np.linalg.LinAlgError: Mi = M[:3, :3]
        g.N = norm(g.N @ Mi.T)
        if np.linalg.det(M[:3, :3]) < 0: g.T = g.T[:, [0, 2, 1]]
        return g

    def tint(self, rgb, a=None):
        g = self.copy(); g.C[:, :3] *= np.asarray(rgb, float)
        if a is not None: g.C[:, 3] = a
        return g

    def fix_winding(self):
        """make the triangle winding agree with the vertex normals (CCW = front in glTF)"""
        p0, p1, p2 = self.P[self.T[:, 0]], self.P[self.T[:, 1]], self.P[self.T[:, 2]]
        gn = np.cross(p1 - p0, p2 - p0)
        vn = self.N[self.T[:, 0]] + self.N[self.T[:, 1]] + self.N[self.T[:, 2]]
        flip = np.einsum('ij,ij->i', gn, vn) < 0
        self.T[flip] = self.T[flip][:, [0, 2, 1]]
        return self

def merge(geos):
    geos = [g for g in geos if g is not None and len(g.T)]
    if not geos: return None
    off = np.cumsum([0] + [len(g.P) for g in geos[:-1]])
    return Geo(np.vstack([g.P for g in geos]), np.vstack([g.N for g in geos]), np.vstack([g.UV for g in geos]),
               np.vstack([g.C for g in geos]), np.vstack([g.T + o for g, o in zip(geos, off)]), geos[0].mat, geos[0].double)

# ------------------------------------------------------------------ primitives
_FACES = [  # normal, a, b  with cross(a,b)=normal
    ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
    ((1, 0, 0), (0, 0, -1), (0, 1, 0)), ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    ((0, 1, 0), (1, 0, 0), (0, 0, -1)), ((0, -1, 0), (1, 0, 0), (0, 0, 1))]

def box(size, mat, uvs=1.0, center=(0, 0, 0), faces='all'):
    sx, sy, sz = size; h = np.array([sx, sy, sz]) / 2.0; c = np.array(center, float)
    P = []; N = []; UV = []; T = []
    for k, (n, a, b) in enumerate(_FACES):
        if faces != 'all' and k not in faces: continue
        n = np.array(n, float); a = np.array(a, float); b = np.array(b, float)
        ha = abs(a @ h); hb = abs(b @ h); hn = abs(n @ h)
        base = len(P)
        for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = n * hn + a * ha * sa + b * hb * sb
            P.append(p + c); N.append(n); UV.append(((a @ p) * uvs, -(b @ p) * uvs))
        T += [(base, base + 1, base + 2), (base, base + 2, base + 3)]
    return Geo(P, N, UV, None, T, mat).fix_winding()

def rbox(size, r, mat, uvs=1.0, center=(0, 0, 0), k=2):
    """box with smoothly rounded edges (radius r); k = segments per 45 degrees of the rim arc"""
    h = np.array(size, float) / 2.0; r = min(r, h.min() * 0.98); c = np.array(center, float)
    rim = (-r + r * np.tan(np.radians(45.0) * np.arange(k + 1) / k))[::-1] * -1.0   # outward distance from the inner edge: 0..r
    def axis(hh):
        pos = (hh - r) + r * np.tan(np.radians(45.0) * np.arange(k + 1) / k)          # inner edge -> face edge
        pts = np.concatenate([-pos[::-1], [0.0], pos]) if hh - r > 1e-6 else np.concatenate([-pos[::-1], pos])
        return np.unique(np.round(pts, 6))
    P = []; N = []; UV = []; T = []
    for n, a, b in _FACES:
        n = np.array(n, float); a = np.array(a, float); b = np.array(b, float)
        ha = abs(a @ h); hb = abs(b @ h); hn = abs(n @ h)
        ga = axis(ha); gb = axis(hb); base = len(P)
        for jb in gb:
            for ja in ga:
                p = n * hn + a * ja + b * jb
                q = np.clip(p, -(h - r), h - r); d = p - q; L = np.linalg.norm(d)
                nn = d / L if L > 1e-9 else n
                P.append(q + nn * r + c); N.append(nn); UV.append(((a @ p) * uvs, -(b @ p) * uvs))
        W = len(ga)
        for j in range(len(gb) - 1):
            for i in range(W - 1):
                v0 = base + j * W + i; T += [(v0, v0 + 1, v0 + W + 1), (v0, v0 + W + 1, v0 + W)]
    return Geo(P, N, UV, None, T, mat).fix_winding()

def cylinder(r0, r1, height, mat, seg=20, uvs=1.0, caps=(True, True), y0=0.0, smooth=True):
    """along +Y from y0 to y0+height, r0 at the bottom, r1 at the top"""
    ang = np.linspace(0, 2 * np.pi, seg + 1); cs, sn = np.cos(ang), np.sin(ang)
    slope = (r0 - r1) / max(height, 1e-9)
    P = []; N = []; UV = []; T = []
    ravg = (r0 + r1) / 2; tiles = max(1, round(2 * np.pi * ravg * uvs))
    for i, (r, y, vv) in enumerate(((r0, y0, y0), (r1, y0 + height, y0 + height))):
        for j in range(seg + 1):
            P.append((r * cs[j], y, r * sn[j])); N.append(norm((cs[j], slope, sn[j]))); UV.append((j / seg * tiles, -vv * uvs))
    for j in range(seg):
        a, b, c, d = j, j + 1, seg + 1 + j + 1, seg + 1 + j; T += [(a, b, c), (a, c, d)]
    for top, (r, y) in enumerate(((r0, y0), (r1, y0 + height))):
        if not caps[top] or r < 1e-6: continue
        base = len(P); nn = (0, 1, 0) if top else (0, -1, 0)
        P.append((0, y, 0)); N.append(nn); UV.append((0.5 * 0, 0))
        for j in range(seg):
            P.append((r * cs[j], y, r * sn[j])); N.append(nn); UV.append((r * cs[j] * uvs, -r * sn[j] * uvs))
        for j in range(seg): T.append((base, base + 1 + j, base + 1 + (j + 1) % seg))
    return Geo(P, N, UV, None, T, mat).fix_winding()

def ellipsoid(radii, mat, seg=20, rings=12, uvs=1.0, center=(0, 0, 0)):
    rx, ry, rz = radii; P = []; N = []; UV = []; T = []
    for i in range(rings + 1):
        th = np.pi * i / rings
        for j in range(seg + 1):
            ph = 2 * np.pi * j / seg
            d = np.array((np.sin(th) * np.cos(ph), np.cos(th), np.sin(th) * np.sin(ph)))
            P.append(d * (rx, ry, rz) + center); N.append(norm(d / (rx * rx, ry * ry, rz * rz) * 1.0 + 0.0))
            UV.append((j / seg * max(1, 2 * np.pi * (rx + rz) / 2 * uvs), i / rings * np.pi * ry * uvs))
    for i in range(rings):
        for j in range(seg):
            a = i * (seg + 1) + j; T += [(a, a + 1, a + seg + 2), (a, a + seg + 2, a + seg + 1)]
    return Geo(P, N, UV, None, T, mat).fix_winding()

def lathe(profile, mat, seg=24, uvs=1.0, creases=(), closed_bottom=False):
    """surface of revolution; profile = [(radius, y), ...] bottom->top; creases = indices with a hard edge"""
    prof = np.array(profile, float); n = len(prof)
    segn = []  # outward normal of each profile segment
    for i in range(n - 1):
        dr, dy = prof[i + 1] - prof[i]; segn.append(norm((dy, -dr)))
    ang = np.linspace(0, 2 * np.pi, seg + 1); cs, sn = np.cos(ang), np.sin(ang)
    rows = []  # list of (profile idx, normal2d)
    for i in range(n):
        if i in creases and 0 < i < n - 1:
            rows.append((i, segn[i - 1])); rows.append((i, segn[i]))
        else:
            if i == 0: nn = segn[0]
            elif i == n - 1: nn = segn[-1]
            else: nn = norm(segn[i - 1] + segn[i])
            rows.append((i, nn))
    P = []; N = []; UV = []; T = []; vacc = 0.0; prev = None
    tiles = max(1, round(2 * np.pi * prof[:, 0].max() * uvs))
    for ri, (i, nn) in enumerate(rows):
        r, y = prof[i]
        if prev is not None and prev != i: vacc += np.linalg.norm(prof[i] - prof[prev])
        prev = i
        for j in range(seg + 1):
            P.append((r * cs[j], y, r * sn[j])); N.append((nn[0] * cs[j], nn[1], nn[0] * sn[j])); UV.append((j / seg * tiles, -vacc * uvs))
    W = seg + 1
    for ri in range(len(rows) - 1):
        if rows[ri][0] == rows[ri + 1][0]: continue
        for j in range(seg):
            a = ri * W + j; T += [(a, a + 1, a + W + 1), (a, a + W + 1, a + W)]
    g = Geo(P, N, UV, None, T, mat).fix_winding()
    if closed_bottom:
        r0, y0 = prof[0]
        if r0 > 1e-6: g = merge([g, cylinder(r0, r0, 0.0001, mat, seg, uvs, (True, False), y0)])
    return g

def tube(path, radii, mat, seg=10, uvs=1.0, cap_end=True, tiles=None):
    """sweep a circle along a polyline with per-point radii (parallel-transport frames)"""
    path = np.asarray(path, float); radii = np.asarray(radii, float); n = len(path)
    tang = np.zeros_like(path)
    tang[1:-1] = path[2:] - path[:-2]; tang[0] = path[1] - path[0]; tang[-1] = path[-1] - path[-2]; tang = norm(tang)
    ref = np.array((0, 0, 1.0)) if abs(tang[0][2]) < 0.9 else np.array((1.0, 0, 0))
    u = norm(np.cross(tang[0], ref)); P = []; N = []; UV = []; T = []; acc = 0.0
    rmax = radii.max(); tl = tiles or max(1, round(2 * np.pi * rmax * uvs))
    for i in range(n):
        if i > 0:
            # rotate previous frame to the new tangent
            a, b = tang[i - 1], tang[i]; ax = np.cross(a, b); s = np.linalg.norm(ax)
            if s > 1e-9:
                ax /= s; ang = np.arctan2(s, a @ b)
                u = u * np.cos(ang) + np.cross(ax, u) * np.sin(ang) + ax * (ax @ u) * (1 - np.cos(ang))
            acc += np.linalg.norm(path[i] - path[i - 1])
        v = np.cross(tang[i], u)
        for j in range(seg + 1):
            t = 2 * np.pi * j / seg; d = u * np.cos(t) + v * np.sin(t)
            P.append(path[i] + d * radii[i]); N.append(d); UV.append((j / seg * tl, -acc * uvs))
    W = seg + 1
    for i in range(n - 1):
        for j in range(seg):
            a = i * W + j; T += [(a, a + 1, a + W + 1), (a, a + W + 1, a + W)]
    if cap_end and radii[-1] > 1e-4:
        base = len(P); P.append(path[-1]); N.append(tang[-1]); UV.append((0, 0))
        for j in range(seg): P.append(P[(n - 1) * W + j]); N.append(tang[-1]); UV.append((0, 0))
        for j in range(seg): T.append((base, base + 1 + j, base + 1 + (j + 1) % seg))
    return Geo(P, N, UV, None, T, mat).fix_winding()

def quad(center, right, up, w, h, mat, uv_rect=(0, 0, 1, 1), normal=None, double=True, color=None):
    """camera-facing style card. right/up are direction vectors"""
    c = np.array(center, float); r = norm(right) * w / 2; u = norm(up) * h / 2
    P = [c - r - u, c + r - u, c + r + u, c - r + u]
    nn = norm(np.cross(r, u)) if normal is None else norm(normal)
    u0, v0, u1, v1 = uv_rect
    UV = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
    C = None if color is None else np.tile(np.asarray(color, float), (4, 1))
    g = Geo(P, [nn] * 4 if normal is None else None or [nn] * 4, UV, C, [(0, 1, 2), (0, 2, 3)], mat, double)
    # keep the *plane* winding (so the card's front faces its geometric normal)
    return g

def grid_surface(fn, nx, nz, x0, x1, z0, z1, mat, uvs=1.0):
    """height-field patch y=fn(x,z) (vectorised) with smooth normals, facing +Y"""
    xs = np.linspace(x0, x1, nx + 1); zs = np.linspace(z0, z1, nz + 1)
    X, Z = np.meshgrid(xs, zs); Y = fn(X, Z)
    e = 0.01; dx = (fn(X + e, Z) - fn(X - e, Z)) / (2 * e); dz = (fn(X, Z + e) - fn(X, Z - e)) / (2 * e)
    N = norm(np.stack([-dx, np.ones_like(dx), -dz], -1).reshape(-1, 3))
    P = np.stack([X, Y, Z], -1).reshape(-1, 3); UV = np.stack([X * uvs, -Z * uvs], -1).reshape(-1, 2)
    T = []
    for j in range(nz):
        for i in range(nx):
            a = j * (nx + 1) + i; T += [(a, a + nx + 1, a + nx + 2), (a, a + nx + 2, a + 1)]
    return Geo(P, N, UV, None, T, mat).fix_winding()

# ------------------------------------------------------------------ noise (3D value noise, vectorised)
def _hash(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

def vnoise(p, seed=0):
    p = np.asarray(p, float); i = np.floor(p).astype(np.int64); f = p - i
    f = f * f * (3 - 2 * f); out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                out = out + w * _hash(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    return out * 2 - 1

def fbm3(p, octaves=4, seed=0, lac=2.0, gain=0.5):
    a = 1.0; s = 0; f = 1.0; tot = 0
    for o in range(octaves):
        s = s + a * vnoise(np.asarray(p) * f, seed + o * 17); tot += a; a *= gain; f *= lac
    return s / tot

# ------------------------------------------------------------------ organic helpers
def icosphere(sub=3):
    t = (1 + 5 ** 0.5) / 2
    V = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
         (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    V = [tuple(norm(v)) for v in V]
    for _ in range(sub):
        cache = {}; NF = []
        def mid(a, b):
            k = (min(a, b), max(a, b))
            if k not in cache:
                V.append(tuple(norm((np.array(V[a]) + np.array(V[b])) / 2))); cache[k] = len(V) - 1
            return cache[k]
        for a, b, c in F:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a); NF += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        F = NF
    return np.array(V), np.array(F)

def smooth_normals(P, T):
    N = np.zeros_like(P); p0, p1, p2 = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
    fn = np.cross(p1 - p0, p2 - p0)
    for k in range(3): np.add.at(N, T[:, k], fn)
    return norm(N)

def rock(radius, mat, seed=0, squash=0.7, rough=0.25, facets=5, sub=3, center=(0, 0, 0)):
    V, F = icosphere(sub); rng = np.random.default_rng(seed)
    R = radius * (1 + rough * fbm3(V * 1.7 + seed * 3.1, 4, seed)); P = V * R[:, None]
    P[:, 1] *= squash
    for _ in range(facets):  # planar cuts -> chunky boulders
        n = norm(rng.normal(size=3)); d = radius * rng.uniform(0.62, 0.85); s = P @ n
        over = s > d; P[over] -= np.outer(s[over] - d, n)
    P[:, 1] = np.maximum(P[:, 1], -radius * squash * 0.55)
    P += center
    N = smooth_normals(P, F)
    return Geo(P, N, None, None, F, mat).fix_winding()
