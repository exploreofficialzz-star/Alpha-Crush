"""Tileable procedural noise + PBR map helpers (numpy / scipy / PIL)."""
import numpy as np
from scipy.spatial import cKDTree
from scipy import ndimage as ndi
from PIL import Image

def rng(seed): return np.random.default_rng(seed)

def fbm_tile(n, beta=2.4, seed=0, lo=1.0, hi=None, aniso=None):
    """Tileable 1/f^beta noise in [0,1] via FFT. aniso=(angle_deg, stretch) elongates features along the angle."""
    r = rng(seed); fx = np.fft.fftfreq(n)[:, None] * n; fy = np.fft.fftfreq(n)[None, :] * n
    if aniso:
        a = np.radians(aniso[0]); s = aniso[1]
        u = fx * np.cos(a) + fy * np.sin(a); v = -fx * np.sin(a) + fy * np.cos(a)
        f = np.sqrt((u / s) ** 2 + v ** 2)       # frequency along the stretch direction is cheap -> long features
    else:
        f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    amp = f ** (-beta / 2.0); amp[0, 0] = 0
    amp *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-6)) ** 4)
    if hi: amp *= 1.0 / (1.0 + (f / hi) ** 4)
    z = np.fft.ifft2(np.fft.fft2(r.standard_normal((n, n))) * amp).real
    z = (z - z.mean()) / (z.std() + 1e-9)
    return np.clip(z / 6.0 + 0.5, 0, 1)

def norm01(a):
    a = np.asarray(a, float); return (a - a.min()) / max(a.max() - a.min(), 1e-9)

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-12), 0, 1); return t * t * (3 - 2 * t)

def voronoi_tile(n, cells, seed=0, jitter=0.9):
    """Tileable Voronoi. returns f1, f2 (distance in pixels), cell id of the nearest feature, centers"""
    r = rng(seed); g = np.arange(cells)
    cx, cy = np.meshgrid(g, g)
    pts = np.stack([(cx + 0.5 + (r.random((cells, cells)) - 0.5) * jitter) / cells * n,
                    (cy + 0.5 + (r.random((cells, cells)) - 0.5) * jitter) / cells * n], -1).reshape(-1, 2)
    tree = cKDTree(pts, boxsize=n)
    yy, xx = np.mgrid[0:n, 0:n]; q = np.stack([xx.ravel() + 0.5, yy.ravel() + 0.5], -1)
    d, i = tree.query(q, k=2)
    return d[:, 0].reshape(n, n), d[:, 1].reshape(n, n), i[:, 0].reshape(n, n), pts

def ramp(x, stops):
    """colour ramp: stops=[(t,(r,g,b)),...] -> (...,3)"""
    ts = np.array([s[0] for s in stops]); cs = np.array([s[1] for s in stops], float)
    x = np.clip(x, ts[0], ts[-1])
    return np.stack([np.interp(x, ts, cs[:, k]) for k in range(3)], -1)

def warp(a, n, amount, seed=0, scale=1.0):
    """tileable domain warp of a 2D array by low-frequency noise"""
    dx = (fbm_tile(n, 3.0, seed, hi=6) - 0.5) * 2 * amount; dy = (fbm_tile(n, 3.0, seed + 1, hi=6) - 0.5) * 2 * amount
    yy, xx = np.mgrid[0:n, 0:n]
    return ndi.map_coordinates(a, [(yy + dy) % n, (xx + dx) % n], order=1, mode='wrap')

def height_to_normal(h, strength=2.0):
    """OpenGL-style (Y+ up) tangent normal map from a tileable height field in [0,1]"""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5      # image up = decreasing row
    nx, ny, nz = -dx * strength * h.shape[0] / 64.0, -dy * strength * h.shape[0] / 64.0, np.ones_like(h)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5

def to8(a): return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)

def save_pbr(outdir, name, albedo, height, rough, ao=None, metal=None, normal_strength=2.0, jpg=True, alpha=None):
    """writes <name>_albedo.jpg, <name>_normal.jpg (q92, 4:4:4), <name>_orm.png (half resolution: smooth data).
    ORM = R ambient occlusion, G roughness, B metallic (glTF packing)."""
    import os
    n = albedo.shape[0]
    Image.fromarray(to8(albedo)).save(os.path.join(outdir, f'{name}_albedo.jpg'), quality=90, subsampling=0)
    nm = Image.fromarray(to8(height_to_normal(height, normal_strength)))
    if n > 512: nm = nm.resize((512, 512), Image.LANCZOS)     # ground normals tile at 512; albedo keeps full detail
    nm.save(os.path.join(outdir, f'{name}_normal.jpg'), quality=92, subsampling=0)
    ao = np.ones_like(height) if ao is None else np.broadcast_to(ao, height.shape)
    metal = np.zeros_like(height) if metal is None else np.broadcast_to(metal, height.shape)
    rough = np.broadcast_to(rough, height.shape)
    orm = Image.fromarray(to8(np.dstack([ao, rough, metal])))
    half = max(128, n // 2)
    if half < n: orm = orm.resize((half, half), Image.LANCZOS)
    orm.save(os.path.join(outdir, f'{name}_orm.png'), optimize=True)

def srgb_mean(img): return (np.asarray(img).reshape(-1, 3).mean(0))
