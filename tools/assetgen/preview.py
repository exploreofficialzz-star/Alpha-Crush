"""Software preview renderer (z-buffer + Blinn-Phong) so generated assets can be inspected without an engine."""
import numpy as np
from PIL import Image, ImageDraw
from meshkit import Geo, Tm, Sm, Rx, Ry, Rz, norm
from gltf import Node, _quat

def _node_matrix(n):
    return Tm(*n.t) @ Rz(n.euler[2]) @ Ry(n.euler[1]) @ Rx(n.euler[0]) @ Sm(*n.s)

def flatten(node, parent=None):
    M = _node_matrix(node) if parent is None else parent @ _node_matrix(node)
    out = [g.xf(M) for g in node.geos]
    for c in node.children:
        if c.name.startswith('COL_'): continue
        out += flatten(c, M)
    return out

_TEX = {}
def load_tex(path):
    if path not in _TEX: _TEX[path] = np.asarray(Image.open(path).convert('RGBA'), np.float32) / 255.0
    return _TEX[path]

def render(geos, mat_colors=None, textures=None, size=(640, 640), az=35, el=18, fov=28, bg=(0.62, 0.74, 0.88), target=None,
           dist_scale=1.0, ground=False, light_az=-40, light_el=45, ssaa=1, eye_pos=None):
    mat_colors = mat_colors or {}; textures = textures or {}
    allp = np.vstack([g.P for g in geos]); lo, hi = allp.min(0), allp.max(0)
    ctr = (lo + hi) / 2 if target is None else np.array(target, float)
    radius = np.linalg.norm(hi - lo) / 2
    W, H = size[0] * ssaa, size[1] * ssaa
    a, e = np.radians(az), np.radians(el)
    cam_dir = np.array((np.sin(a) * np.cos(e), np.sin(e), np.cos(a) * np.cos(e)))
    dist = radius / np.sin(np.radians(fov) / 2) * dist_scale
    eye = ctr + cam_dir * dist if eye_pos is None else np.array(eye_pos, float)
    f = norm(ctr - eye); r = norm(np.cross(f, (0, 1, 0))); u = np.cross(r, f)
    la, le = np.radians(light_az + az), np.radians(light_el)
    L = norm((np.sin(la) * np.cos(le), np.sin(le), np.cos(la) * np.cos(le)))
    zbuf = np.full((H, W), np.inf, np.float32); img = np.zeros((H, W, 3), np.float32); img[:] = bg
    # simple gradient background
    img *= np.linspace(1.08, 0.86, H)[:, None, None]
    focal = 0.5 * H / np.tan(np.radians(fov) / 2)
    if ground:
        gp = 0.0
    for g in geos:
        P = g.P - eye; x = P @ r; y = P @ u; z = P @ f
        sx = W / 2 + focal * x / z; sy = H / 2 - focal * y / z
        base = np.array(mat_colors.get(g.mat, (0.6, 0.6, 0.6)), np.float32)[:3]
        tex = textures.get(g.mat)
        V = g.C[:, :3].astype(np.float32); Nn = g.N.astype(np.float32)
        for t in g.T:
            i0, i1, i2 = t
            if z[i0] <= 0.05 or z[i1] <= 0.05 or z[i2] <= 0.05: continue
            x0, x1, x2 = sx[i0], sx[i1], sx[i2]; y0, y1, y2 = sy[i0], sy[i1], sy[i2]
            minx = max(int(np.floor(min(x0, x1, x2))), 0); maxx = min(int(np.ceil(max(x0, x1, x2))), W - 1)
            miny = max(int(np.floor(min(y0, y1, y2))), 0); maxy = min(int(np.ceil(max(y0, y1, y2))), H - 1)
            if minx > maxx or miny > maxy: continue
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-9: continue
            if not g.double and den > 0: continue   # back-face cull (screen y is down)
            px, py = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
            w0 = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
            w1 = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
            w2 = 1 - w0 - w1
            m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
            if not m.any(): continue
            zz = 1.0 / (w0 / z[i0] + w1 / z[i1] + w2 / z[i2])   # perspective-correct depth (approx)
            sub = zbuf[miny:maxy + 1, minx:maxx + 1]
            m &= zz < sub
            if not m.any(): continue
            n = (w0[..., None] * Nn[i0] + w1[..., None] * Nn[i1] + w2[..., None] * Nn[i2])
            n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
            if g.double:   # flip normal for back faces (like the engine does)
                if den > 0: n = -n
            col = np.broadcast_to(base, n.shape).copy()
            col *= (w0[..., None] * V[i0] + w1[..., None] * V[i1] + w2[..., None] * V[i2])
            if tex is not None:
                uv = w0[..., None] * g.UV[i0] + w1[..., None] * g.UV[i1] + w2[..., None] * g.UV[i2]
                th, tw = tex.shape[:2]
                tx = (np.floor((uv[..., 0] % 1.0) * tw).astype(int)) % tw; ty = (np.floor((uv[..., 1] % 1.0) * th).astype(int)) % th
                texel = tex[ty, tx]
                if texel.shape[-1] == 4:
                    m &= texel[..., 3] > 0.5
                    if not m.any(): continue
                col = col * (texel[..., :3] * 1.0) if mat_colors.get(g.mat) is not None else texel[..., :3] * V[i0]
            diff = np.clip(n @ L, 0, 1)
            sky = 0.5 + 0.5 * n[..., 1]
            amb = (0.30 * sky + 0.12 * (1 - sky))[..., None] * np.array((0.8, 0.9, 1.0))
            Hh = norm(L + norm(eye - (g.P[i0])))
            spec = (np.clip(n @ Hh, 0, 1) ** 24 * 0.12 * diff)[..., None]
            lit = col * (amb + diff[..., None] * np.array((1.0, 0.95, 0.85)) * 0.85) + spec
            sub[m] = zz[m]
            reg = img[miny:maxy + 1, minx:maxx + 1]; reg[m] = lit[m]
    img = np.clip(img, 0, 1) ** (1 / 2.2)
    out = Image.fromarray((img * 255).astype(np.uint8))
    if ssaa > 1: out = out.resize(size, Image.LANCZOS)
    return out

def sheet(images, labels=None, cols=3, pad=6, label_h=18):
    w, h = images[0].size; rows = (len(images) + cols - 1) // cols
    S = Image.new('RGB', (cols * (w + pad) + pad, rows * (h + label_h + pad) + pad), (30, 30, 34)); d = ImageDraw.Draw(S)
    for i, im in enumerate(images):
        x = pad + (i % cols) * (w + pad); y = pad + (i // cols) * (h + label_h + pad)
        S.paste(im, (x, y + label_h))
        if labels: d.text((x + 4, y + 3), labels[i], fill=(235, 235, 235))
    return S
