"""Signed-distance-field modelling + marching-cubes meshing (numpy / scikit-image)."""
import numpy as np
from skimage import measure
from meshkit import Geo, norm

def _v(p, c): return p - np.asarray(c, float)

def sph(p, c, r): return np.linalg.norm(_v(p, c), axis=-1) - r

def ell(p, c, radii):
    q = _v(p, c) / np.asarray(radii, float); k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(_v(p, c) / (np.asarray(radii, float) ** 2), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

def cap(p, a, b, ra, rb=None):
    """tapered capsule (round cone, good for gentle tapers)"""
    rb = ra if rb is None else rb; a = np.asarray(a, float); b = np.asarray(b, float); ba = b - a
    t = np.clip(((p - a) @ ba) / (ba @ ba), 0, 1); r = ra + (rb - ra) * t
    return np.linalg.norm(p - (a + ba * t[..., None]), axis=-1) - r

def rbx(p, c, half, r):
    q = np.abs(_v(p, c)) - (np.asarray(half, float) - r)
    return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(axis=-1), 0) - r

def smin(a, b, k):
    if k <= 0: return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1); return b * (1 - h) + a * h - k * h * (1 - h)

def smax(a, b, k): return -smin(-a, -b, k)

def union(ds, k):
    d = ds[0]
    for x in ds[1:]: d = smin(d, x, k)
    return d

def mesh_sdf(fn, lo, hi, voxel, mat, mask_fn=None, uv_fn=None):
    lo = np.asarray(lo, float); hi = np.asarray(hi, float)
    ax = [np.arange(lo[i], hi[i] + voxel, voxel) for i in range(3)]
    G = np.stack(np.meshgrid(*ax, indexing='ij'), -1).reshape(-1, 3)
    vol = fn(G).reshape(len(ax[0]), len(ax[1]), len(ax[2])).astype(np.float32)
    if vol.min() > 0 or vol.max() < 0: return None
    verts, faces, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel, voxel, voxel))
    verts = verts + lo
    e = voxel * 0.6; N = np.zeros_like(verts)
    for i in range(3):
        o = np.zeros(3); o[i] = e
        N[:, i] = fn(verts + o) - fn(verts - o)
    N = norm(N)
    C = mask_fn(verts) if mask_fn else None
    UV = np.stack([verts[:, 0], -verts[:, 1]], -1) if uv_fn is None else uv_fn(verts)
    return Geo(verts, N, UV, C, faces, mat).fix_winding()
