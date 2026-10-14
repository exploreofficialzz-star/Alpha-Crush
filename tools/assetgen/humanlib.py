"""Building blocks for the humanoid generator (numpy / scipy / scikit-image only).

  * SDF helpers that the old sdf.py does not have (torus, lofted ellipse stacks, noise, planes)
  * adaptive narrow-band marching cubes (fine voxels only near the surface)
  * quadric-error-metric mesh decimation (so a 6 mm scan-like mesh becomes a phone-friendly one)
  * vertex ambient occlusion straight from the signed distance field
  * proximity skin weights with mesh-diffusion smoothing
  * a small textured software rasteriser used for visual QA and for the UI portraits

Conventions follow the rest of assetgen: +Y up, metres, the character faces -Z, right side is +X.
"""
import heapq
import numpy as np
from scipy import sparse
from scipy.interpolate import PchipInterpolator
from skimage import measure

# ----------------------------------------------------------------------------- sdf helpers
def _a(x): return np.asarray(x, np.float64)

def sph(p, c, r): return np.linalg.norm(p - _a(c), axis=-1) - r

def ell(p, c, radii):
    """ellipsoid (first-order distance approximation, exact on the axes)"""
    q = (p - _a(c)) / _a(radii)
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q / _a(radii), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

def cap(p, a, b, ra, rb=None):
    """tapered capsule from a (radius ra) to b (radius rb)"""
    rb = ra if rb is None else rb
    a = _a(a); b = _a(b); ba = b - a
    t = np.clip(((p - a) @ ba) / (ba @ ba), 0.0, 1.0)
    r = ra + (rb - ra) * t
    return np.linalg.norm(p - (a + ba * t[..., None]), axis=-1) - r

def cap_t(p, a, b):
    a = _a(a); b = _a(b); ba = b - a
    return np.clip(((p - a) @ ba) / (ba @ ba), 0.0, 1.0)

def torus_y(p, c, R, r):
    """torus lying in the XZ plane (axis = Y)"""
    q = p - _a(c)
    return np.hypot(np.hypot(q[..., 0], q[..., 2]) - R, q[..., 1]) - r

def rbox(p, c, half, r):
    q = np.abs(p - _a(c)) - (_a(half) - r)
    return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(axis=-1), 0) - r

def smin(a, b, k):
    if k <= 0: return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)

def smax(a, b, k): return -smin(-a, -b, k)

def union(ds, k):
    d = ds[0]
    for x in ds[1:]: d = smin(d, x, k)
    return d

def half_y(p, y, keep_above=True):
    """plane y = const; negative on the kept side"""
    return (y - p[..., 1]) if keep_above else (p[..., 1] - y)

class Loft:
    """Elliptic cross-section stack along Y: radii / centre offsets are PCHIP-interpolated through
    control rows (y, a(x half width), b(z half depth), cx, cz)."""
    def __init__(self, rows, table_step=0.002):
        rows = np.asarray(rows, float); rows = rows[np.argsort(rows[:, 0])]
        self.y0, self.y1 = rows[0, 0], rows[-1, 0]
        ys = np.arange(self.y0, self.y1 + table_step, table_step)
        self.ys = ys
        self.a = PchipInterpolator(rows[:, 0], rows[:, 1])(ys)
        self.b = PchipInterpolator(rows[:, 0], rows[:, 2])(ys)
        self.cx = PchipInterpolator(rows[:, 0], rows[:, 3])(ys) if rows.shape[1] > 3 else np.zeros_like(ys)
        self.cz = PchipInterpolator(rows[:, 0], rows[:, 4])(ys) if rows.shape[1] > 4 else np.zeros_like(ys)

    def __call__(self, p, cap_round=0.02):
        y = np.clip(p[..., 1], self.y0, self.y1)
        a = np.interp(y, self.ys, self.a); b = np.interp(y, self.ys, self.b)
        cx = np.interp(y, self.ys, self.cx); cz = np.interp(y, self.ys, self.cz)
        qx = (p[..., 0] - cx) / a; qz = (p[..., 2] - cz) / b
        d2 = (np.hypot(qx, qz) - 1.0) * np.minimum(a, b)
        # soft end caps
        dy = np.maximum(self.y0 - p[..., 1], p[..., 1] - self.y1)
        return smax(d2, dy, cap_round) if cap_round > 0 else np.maximum(d2, dy)

# --- cheap gradient noise (value noise on a hashed lattice, trilinear, vectorised)
def _hash3(ix, iy, iz, seed):
    h = (ix * 374761393 + iy * 668265263 + iz * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float64) / 65535.0

def noise3(p, freq=1.0, seed=1):
    q = p * freq
    i = np.floor(q).astype(np.int64); f = q - i
    u = f * f * (3 - 2 * f)
    def h(dx, dy, dz): return _hash3(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    x00 = h(0, 0, 0) * (1 - u[..., 0]) + h(1, 0, 0) * u[..., 0]
    x10 = h(0, 1, 0) * (1 - u[..., 0]) + h(1, 1, 0) * u[..., 0]
    x01 = h(0, 0, 1) * (1 - u[..., 0]) + h(1, 0, 1) * u[..., 0]
    x11 = h(0, 1, 1) * (1 - u[..., 0]) + h(1, 1, 1) * u[..., 0]
    y0 = x00 * (1 - u[..., 1]) + x10 * u[..., 1]
    y1 = x01 * (1 - u[..., 1]) + x11 * u[..., 1]
    return (y0 * (1 - u[..., 2]) + y1 * u[..., 2]) * 2.0 - 1.0

def fbm3(p, freq=1.0, seed=1, octaves=3):
    s = 0.0; a = 0.5; f = freq
    for o in range(octaves):
        s = s + a * noise3(p, f, seed + o * 17); a *= 0.5; f *= 2.03
    return s

def grad(fn, p, e=0.0025):
    g = np.zeros_like(p)
    for i in range(3):
        o = np.zeros(3); o[i] = e
        g[:, i] = fn(p + o) - fn(p - o)
    n = np.linalg.norm(g, axis=1, keepdims=True)
    return g / np.maximum(n, 1e-9)

# ----------------------------------------------------------------------------- adaptive marching cubes
def mesh_adaptive(fn, lo, hi, voxel, block=10):
    """Marching cubes where the SDF `fn` (vectorised over (n,3)) is only evaluated near the surface."""
    lo = _a(lo); hi = _a(hi)
    n = np.ceil((hi - lo) / voxel).astype(int) + 1
    vol = np.empty(tuple(n), np.float32)
    cb = block
    nb = np.ceil((n - 1) / cb).astype(int)
    # coarse corner samples
    cs = [lo[i] + np.arange(nb[i] + 1) * cb * voxel for i in range(3)]
    G = np.stack(np.meshgrid(*cs, indexing='ij'), -1).reshape(-1, 3)
    cd = fn(G).reshape(nb[0] + 1, nb[1] + 1, nb[2] + 1)
    diag = cb * voxel * 1.8
    for bi in range(nb[0]):
        for bj in range(nb[1]):
            for bk in range(nb[2]):
                corners = cd[bi:bi + 2, bj:bj + 2, bk:bk + 2]
                sl = tuple(slice(b * cb, min((b + 1) * cb + 1, n[a])) for a, b in enumerate((bi, bj, bk)))
                if corners.min() > diag:
                    vol[sl] = 1.0
                elif corners.max() < -diag:
                    vol[sl] = -1.0
                else:
                    axes = [lo[a] + np.arange(s.start, s.stop) * voxel for a, s in enumerate(sl)]
                    pts = np.stack(np.meshgrid(*axes, indexing='ij'), -1).reshape(-1, 3)
                    vol[sl] = fn(pts).reshape(tuple(len(x) for x in axes)).astype(np.float32)
    if vol.min() > 0 or vol.max() < 0:
        return None, None
    verts, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel, voxel, voxel))
    return verts + lo, faces.astype(np.int64)

def project_to_surface(fn, P, iters=2, max_step=0.004):
    P = P.copy()
    for _ in range(iters):
        d = fn(P)
        g = grad(fn, P)
        step = np.clip(d, -max_step, max_step)[:, None] * g
        P = P - step
    return P

# ----------------------------------------------------------------------------- mesh utilities
def face_normals(P, T):
    n = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    return n, np.linalg.norm(n, axis=1)

def adjacency(n, T):
    i = np.concatenate([T[:, 0], T[:, 1], T[:, 2], T[:, 1], T[:, 2], T[:, 0]])
    j = np.concatenate([T[:, 1], T[:, 2], T[:, 0], T[:, 0], T[:, 1], T[:, 2]])
    A = sparse.coo_matrix((np.ones(len(i)), (i, j)), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    return A

def taubin(P, T, iters=3, lam=0.5, mu=-0.53):
    A = adjacency(len(P), T)
    deg = np.asarray(A.sum(1)).ravel(); deg[deg == 0] = 1
    W = sparse.diags(1.0 / deg) @ A
    P = P.copy()
    for _ in range(iters):
        P = P + lam * (W @ P - P)
        P = P + mu * (W @ P - P)
    return P

def compact(P, T, *attrs):
    used = np.unique(T)
    remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
    return (P[used], remap[T]) + tuple(a[used] for a in attrs)

# ----------------------------------------------------------------------------- QEM decimation
def decimate(P, T, target_tris, importance=None, max_flip_dot=0.25, verbose=False):
    """Garland-Heckbert edge collapse on a closed manifold triangle mesh. `importance` (per vertex,
    >=1) makes a region collapse later, i.e. keeps more triangles there (face, hands, ears)."""
    P = _a(P).copy(); T = np.asarray(T, np.int64).copy()
    n = len(P); m = len(T)
    nrm, area2 = face_normals(P, T)
    ok = area2 > 1e-14
    nn = np.zeros_like(nrm); nn[ok] = nrm[ok] / area2[ok, None]
    d = -np.einsum('ij,ij->i', nn, P[T[:, 0]])
    plane = np.concatenate([nn, d[:, None]], 1)
    K = plane[:, :, None] * plane[:, None, :] * (area2 * 0.5)[:, None, None]
    Q = np.zeros((n, 4, 4))
    for k in range(3): np.add.at(Q, T[:, k], K)
    if importance is not None: Q *= _a(importance)[:, None, None]
    vf = [set() for _ in range(n)]
    for fi in range(m):
        a, b, c = T[fi]
        vf[a].add(fi); vf[b].add(fi); vf[c].add(fi)
    alive_f = np.ones(m, bool); alive_v = np.ones(n, bool); ver = np.zeros(n, np.int64)
    # boundary vertices (open meshes such as the hair): never move them and never merge two of them
    ecount = {}
    for a, b, c in T:
        for u, v in ((a, b), (b, c), (c, a)):
            e = (u, v) if u < v else (v, u)
            ecount[e] = ecount.get(e, 0) + 1
    bnd = np.zeros(n, bool)
    for (u, v), k in ecount.items():
        if k == 1: bnd[u] = bnd[v] = True
    Tl = [list(t) for t in T]
    Pl = [P[i] for i in range(n)]

    def nbrs(v):
        s = set()
        for f in vf[v]: s.update(Tl[f])
        s.discard(v); return s

    def edge_cost(u, v):
        Qs = Q[u] + Q[v]
        A = Qs[:3, :3]; b = -Qs[:3, 3]
        best = None
        try:
            if abs(np.linalg.det(A)) > 1e-12:
                w = np.linalg.solve(A, b)
                if np.linalg.norm(w - 0.5 * (Pl[u] + Pl[v])) < 0.03: best = w
        except np.linalg.LinAlgError:
            pass
        cands = [Pl[u], Pl[v], 0.5 * (Pl[u] + Pl[v])]
        if best is not None: cands.append(best)
        bc = None; bw = None
        for w in cands:
            h = np.append(w, 1.0); c = float(h @ Qs @ h)
            if bc is None or c < bc: bc, bw = c, w
        return bc, bw

    heap = []; cnt = 0
    seen = set()
    for a, b, c in T:
        for u, v in ((a, b), (b, c), (c, a)):
            e = (u, v) if u < v else (v, u)
            if e in seen: continue
            seen.add(e); cost, w = edge_cost(*e)
            heapq.heappush(heap, (cost, cnt, e[0], e[1], 0, 0, w)); cnt += 1
    nf = int(alive_f.sum())
    while nf > target_tris and heap:
        cost, _, u, v, vu, vv, w = heapq.heappop(heap)
        if not (alive_v[u] and alive_v[v]) or ver[u] != vu or ver[v] != vv: continue
        if bnd[u] and bnd[v]: continue
        if bnd[v]:
            u, v = v, u
        if bnd[u]:
            w = Pl[u]
        fu = vf[u]; fv = vf[v]
        shared = fu & fv
        if len(shared) != 2: continue
        nu = nbrs(u); nv = nbrs(v)
        opp = set()
        for f in shared: opp.update(Tl[f])
        opp.discard(u); opp.discard(v)
        if (nu & nv) != opp: continue
        bad = False
        for f in (fu | fv) - shared:
            tri = [w if x in (u, v) else None for x in Tl[f]]
            pts = [w if t is not None else Pl[x] for t, x in zip(tri, Tl[f])]
            n1 = np.cross(pts[1] - pts[0], pts[2] - pts[0])
            q0 = [Pl[x] for x in Tl[f]]
            n0 = np.cross(q0[1] - q0[0], q0[2] - q0[0])
            l1 = np.linalg.norm(n1); l0 = np.linalg.norm(n0)
            if l1 < 1e-12 or (l0 > 1e-12 and (n1 @ n0) / (l1 * l0) < max_flip_dot): bad = True; break
        if bad: continue
        # collapse v into u at w
        Pl[u] = w; Q[u] = Q[u] + Q[v]
        for f in shared:
            alive_f[f] = False; nf -= 1
            for x in Tl[f]:
                if x != u and x != v: vf[x].discard(f)
            vf[u].discard(f); vf[v].discard(f)
        for f in list(fv - shared):
            Tl[f] = [u if x == v else x for x in Tl[f]]
            vf[u].add(f)
        vf[v] = set(); alive_v[v] = False; ver[u] += 1
        for x in nbrs(u):
            e = (u, x) if u < x else (x, u)
            ver[x] += 0
            c2, w2 = edge_cost(*e)
            heapq.heappush(heap, (c2, cnt, e[0], e[1], ver[e[0]], ver[e[1]], w2)); cnt += 1
    keep = np.nonzero(alive_f)[0]
    T2 = np.array([Tl[f] for f in keep], np.int64)
    P2 = np.array(Pl)
    P3, T3 = compact(P2, T2)
    if verbose: print(f"  decimate {m} -> {len(T3)} tris, {len(P3)} verts")
    return P3, T3

# ----------------------------------------------------------------------------- ambient occlusion
def sdf_ao(fn, P, N, dists=(0.012, 0.03, 0.06, 0.11), strength=1.0):
    occ = np.zeros(len(P)); wsum = 0.0
    for i, h in enumerate(dists):
        w = 0.6 ** i
        d = fn(P + N * h)
        occ += w * np.clip((h - d) / h, 0.0, 1.0); wsum += w
    return np.clip(1.0 - strength * occ / wsum, 0.0, 1.0)

# ----------------------------------------------------------------------------- skin weights
def bone_distance(P, a, b):
    a = _a(a); b = _a(b); ba = b - a
    t = np.clip(((P - a) @ ba) / max(ba @ ba, 1e-12), 0, 1)
    return np.linalg.norm(P - (a + ba * t[:, None]), axis=1), t

def skin_weights(P, T, bones, smooth_iters=2, max_infl=4, side_rule=True):
    """bones: list of dict(name, a, b, r, sigma, side) with side in {-1, 0, 1}.
    Weight ~ exp(-(max(0, d - r) / sigma)^2) computed in log space so the nearest bone always wins cleanly.
    Narrow sigma on limbs keeps torso vertices out of the arms (no 'tent' at the armpit); wide sigma on the trunk
    gives long, smooth waist and hip blends."""
    n = len(P); nb = len(bones)
    logit = np.full((n, nb), -1e9)
    for k, bn in enumerate(bones):
        d, _ = bone_distance(P, bn["a"], bn["b"])
        lg = -(np.maximum(d - bn["r"], 0.0) / bn["sigma"]) ** 2
        if side_rule and bn.get("side", 0) != 0:
            wrong = (P[:, 0] * bn["side"]) < -0.02          # a limb bone never moves the opposite half of the body
            lg = np.where(wrong, -1e9, lg)
        logit[:, k] = lg
    W = np.exp(logit - logit.max(1, keepdims=True))
    W[W < 1e-4] = 0.0
    W /= W.sum(1, keepdims=True)
    A = adjacency(n, T); deg = np.asarray(A.sum(1)).ravel(); deg[deg == 0] = 1
    S = sparse.diags(1.0 / deg) @ A
    for _ in range(smooth_iters):
        W = 0.6 * W + 0.4 * (S @ W)
    idx = np.argsort(-W, axis=1)[:, :max_infl]
    Wt = np.take_along_axis(W, idx, 1)
    Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-9)
    return idx.astype(np.uint16), Wt.astype(np.float32)

# ----------------------------------------------------------------------------- software renderer (QA / portraits)
def look_at(eye, target, up=(0, 1, 0)):
    eye = _a(eye); target = _a(target); f = target - eye; f /= np.linalg.norm(f)
    r = np.cross(f, _a(up)); r /= np.linalg.norm(r); u = np.cross(r, f)
    return r, u, f

def _bilinear(tex, uv):
    h, w = tex.shape[:2]
    x = (uv[:, 0] % 1.0) * w - 0.5; y = (uv[:, 1] % 1.0) * h - 0.5
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    x0m = x0 % w; x1m = (x0 + 1) % w; y0m = y0 % h; y1m = (y0 + 1) % h
    return (tex[y0m, x0m] * (1 - fx) * (1 - fy) + tex[y0m, x1m] * fx * (1 - fy) +
            tex[y1m, x0m] * (1 - fx) * fy + tex[y1m, x1m] * fx * fy)

class Prim:
    """one renderable primitive: world-space arrays + a material dict"""
    def __init__(self, P, N, UV, C, T, mat):
        self.P, self.N, self.UV, self.C, self.T, self.mat = P, N, UV, C, T, mat

def _raster(prims, view, proj_scale, size, ss):
    """Return per-pixel (prim id, tri id, barycentrics, depth) with a z-buffer."""
    r, u, f, eye = view
    W, H = size[0] * ss, size[1] * ss
    zbuf = np.full(W * H, np.inf); pid = np.full(W * H, -1, np.int32); tid = np.full(W * H, -1, np.int64)
    bary = np.zeros((W * H, 2))
    for k, pr in enumerate(prims):
        rel = pr.P - eye
        x = rel @ r; y = rel @ u; z = rel @ f
        persp = proj_scale["persp"]
        if persp:
            sx = x / np.maximum(z, 1e-3) * proj_scale["f"]; sy = y / np.maximum(z, 1e-3) * proj_scale["f"]
        else:
            sx = x * proj_scale["f"]; sy = y * proj_scale["f"]
        px = (sx * 0.5 + 0.5) * W + proj_scale.get("ox", 0) * W; py = (0.5 - sy * 0.5 * (size[0] / size[1])) * H + proj_scale.get("oy", 0) * H
        T = pr.T
        x0 = px[T[:, 0]]; x1 = px[T[:, 1]]; x2 = px[T[:, 2]]
        y0 = py[T[:, 0]]; y1 = py[T[:, 1]]; y2 = py[T[:, 2]]
        z0 = z[T[:, 0]]; z1 = z[T[:, 1]]; z2 = z[T[:, 2]]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        valid = (np.abs(area) > 1e-9) & (z0 > 0.01) & (z1 > 0.01) & (z2 > 0.01)
        if pr.mat.get("cull", True):
            valid &= area < 0   # screen y points down, so front faces (CCW in world) have negative signed area here
        minx = np.floor(np.minimum(np.minimum(x0, x1), x2)).astype(int).clip(0, W - 1)
        maxx = np.ceil(np.maximum(np.maximum(x0, x1), x2)).astype(int).clip(0, W - 1)
        miny = np.floor(np.minimum(np.minimum(y0, y1), y2)).astype(int).clip(0, H - 1)
        maxy = np.ceil(np.maximum(np.maximum(y0, y1), y2)).astype(int).clip(0, H - 1)
        for ti in np.nonzero(valid)[0]:
            xs = np.arange(minx[ti], maxx[ti] + 1) + 0.5; ys = np.arange(miny[ti], maxy[ti] + 1) + 0.5
            if len(xs) == 0 or len(ys) == 0: continue
            gx, gy = np.meshgrid(xs, ys)
            inv = 1.0 / area[ti]
            w0 = ((x1[ti] - gx) * (y2[ti] - gy) - (x2[ti] - gx) * (y1[ti] - gy)) * inv
            w1 = ((x2[ti] - gx) * (y0[ti] - gy) - (x0[ti] - gx) * (y2[ti] - gy)) * inv
            w2 = 1.0 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not inside.any(): continue
            zz = w0 * z0[ti] + w1 * z1[ti] + w2 * z2[ti]
            ix = gx[inside].astype(int); iy = gy[inside].astype(int)
            lin = iy * W + ix
            better = zz[inside] < zbuf[lin]
            if not better.any(): continue
            lin = lin[better]
            zbuf[lin] = zz[inside][better]; pid[lin] = k; tid[lin] = ti
            bary[lin, 0] = w0[inside][better]; bary[lin, 1] = w1[inside][better]
    return zbuf, pid, tid, bary

def render(prims, eye, target, size=(640, 800), fov_deg=28.0, ortho_height=None, ss=2, lights=None, bg=(0.80, 0.86, 0.94), sky_bottom=None,
           shadow=True, return_mask=False):
    """prims: list of Prim. Returns uint8 image (H, W, 3)."""
    eye = _a(eye); target = _a(target)
    r, u, f = look_at(eye, target)
    persp = ortho_height is None
    scale = {"persp": persp, "f": (1.0 / np.tan(np.radians(fov_deg) / 2)) if persp else (2.0 / ortho_height)}
    zbuf, pid, tid, bary = _raster(prims, (r, u, f, eye), scale, size, ss)
    W, H = size[0] * ss, size[1] * ss
    img = np.zeros((H * W, 3))
    # background gradient
    yy = (np.arange(H * W) // W) / H
    top = _a(bg); bot = _a(sky_bottom) if sky_bottom is not None else top * 0.92
    img[:] = top[None, :] * (1 - yy[:, None]) + bot[None, :] * yy[:, None]
    covered = pid >= 0
    L = lights or {}
    key = _a(L.get("key", (-0.45, 0.70, -0.55))); key /= np.linalg.norm(key)      # from upper-left-front (camera sits at -Z side)
    fill = _a(L.get("fill", (0.7, 0.2, -0.4))); fill /= np.linalg.norm(fill)
    rim = _a(L.get("rim", (0.3, 0.35, 0.9))); rim /= np.linalg.norm(rim)
    # world-space attributes for covered pixels
    P_all = np.zeros((H * W, 3)); N_all = np.zeros((H * W, 3)); UV_all = np.zeros((H * W, 2)); C_all = np.ones((H * W, 4)); alb = np.ones((H * W, 3))
    spec_s = np.zeros(H * W); rough = np.ones(H * W) * 0.6; rim_amt = np.zeros(H * W); rimcol = np.ones((H * W, 3))
    for k, pr in enumerate(prims):
        sel = np.nonzero(pid == k)[0]
        if len(sel) == 0: continue
        T = pr.T[tid[sel]]
        b0 = bary[sel, 0:1]; b1 = bary[sel, 1:2]; b2 = 1.0 - b0 - b1
        P_all[sel] = pr.P[T[:, 0]] * b0 + pr.P[T[:, 1]] * b1 + pr.P[T[:, 2]] * b2
        n = pr.N[T[:, 0]] * b0 + pr.N[T[:, 1]] * b1 + pr.N[T[:, 2]] * b2
        N_all[sel] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
        uv = pr.UV[T[:, 0]] * b0 + pr.UV[T[:, 1]] * b1 + pr.UV[T[:, 2]] * b2
        c = pr.C[T[:, 0]] * b0 + pr.C[T[:, 1]] * b1 + pr.C[T[:, 2]] * b2
        m = pr.mat
        base = _a(m.get("color", (1, 1, 1)))[None, :] * np.ones((len(sel), 3))
        tex = m.get("tex")
        if tex is not None:
            t = _bilinear(tex, uv * _a(m.get("uv_scale", (1.0, 1.0)))[None, :])
            base = base * t[:, :3]
        base = base * (c[:, :3] if m.get("vcol", True) else 1.0)
        alb[sel] = base
        rough[sel] = m.get("rough", 0.6); spec_s[sel] = m.get("spec", 0.3); rim_amt[sel] = m.get("rim", 0.0)
        rimcol[sel] = _a(m.get("rim_tint", (1, 1, 1)))
    # shadow map (orthographic from the key light)
    sh = np.ones(H * W)
    if shadow and covered.any():
        lr, lu, lf = look_at(target + key * 6.0, target)
        ls = 2.0 / (np.max(np.linalg.norm((P_all[covered] - target), axis=1)) * 2.4 + 0.5)
        S = 1024
        zl = np.full(S * S, np.inf)
        for pr in prims:
            rel = pr.P - (target + key * 6.0)
            lx = (rel @ lr) * ls * 0.5 * S + S / 2; ly = (S / 2 - (rel @ lu) * ls * 0.5 * S); lz = rel @ lf
            # splat vertices only (cheap) - dense enough at 6-12 mm spacing
            ix = np.clip(lx.astype(int), 0, S - 1); iy = np.clip(ly.astype(int), 0, S - 1)
            np.minimum.at(zl, iy * S + ix, lz)
            cen = pr.P[pr.T].mean(1) - (target + key * 6.0)
            cx = np.clip(((cen @ lr) * ls * 0.5 * S + S / 2).astype(int), 0, S - 1)
            cy = np.clip((S / 2 - (cen @ lu) * ls * 0.5 * S).astype(int), 0, S - 1)
            np.minimum.at(zl, cy * S + cx, cen @ lf)
        zl = zl.reshape(S, S)
        from scipy import ndimage
        zl = ndimage.minimum_filter(zl, size=5)
        rel = P_all[covered] - (target + key * 6.0)
        lx = (rel @ lr) * ls * 0.5 * S + S / 2; ly = (S / 2 - (rel @ lu) * ls * 0.5 * S); lz = rel @ lf
        acc = np.zeros(len(lz))
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            ix = np.clip(lx.astype(int) + dx, 0, S - 1); iy = np.clip(ly.astype(int) + dy, 0, S - 1)
            acc += (lz - 0.03 < zl[iy, ix]).astype(float)
        sh[covered] = acc / 9.0
    V = -(P_all - eye); V /= np.maximum(np.linalg.norm(V, axis=1, keepdims=True), 1e-9)
    N = N_all
    ndl = np.einsum('ij,j->i', N, key); wrap = np.clip((ndl + 0.25) / 1.25, 0, 1)
    diff = 0.95 * wrap * (0.25 + 0.75 * sh) + 0.30 * np.clip(np.einsum('ij,j->i', N, fill), 0, 1)
    hemi = 0.38 + 0.20 * N[:, 1]
    ao = np.mean(np.stack([C_all[:, 0]]), 0)
    Hh = key + V; Hh /= np.maximum(np.linalg.norm(Hh, axis=1, keepdims=True), 1e-9)
    ndh = np.clip(np.einsum('ij,ij->i', N, Hh), 0, 1)
    shin = 2.0 / np.maximum(rough ** 2, 0.02)
    spec = spec_s * (ndh ** np.clip(shin, 4, 260)) * np.clip(ndl, 0, 1) * (0.3 + 0.7 * sh)
    fres = (1.0 - np.clip(np.einsum('ij,ij->i', N, V), 0, 1)) ** 3
    rimlight = rim_amt * fres * np.clip(np.einsum('ij,j->i', N, rim) * 0.5 + 0.7, 0, 1)
    col = alb * (diff + hemi)[:, None] + spec[:, None] + rimlight[:, None] * rimcol * 0.8
    col = col / (1.0 + 0.15 * col)          # soft shoulder
    col = np.clip(col, 0, 1) ** (1 / 2.2)
    img[covered] = col[covered]
    img = img.reshape(H, W, 3)
    cov = covered.reshape(H, W).astype(np.float64)
    if ss > 1:
        img = img.reshape(size[1], ss, size[0], ss, 3).mean((1, 3))
        cov = cov.reshape(size[1], ss, size[0], ss).mean((1, 3))
    out = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    if return_mask:
        return out, cov
    return out
