"""Procedural textures for the humans (numpy / PIL / scipy).

Skin, hair and cloth textures are *neutral multipliers* (near white with darker detail). The game tints them with
`albedo_color`, so every skin tone / hair colour / garment colour reuses the same maps and the face painting
(brows, lips, lashes, blush) stays tone-correct: lips are "tone x pink", brows are "tone x dark".
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

FACE_TEX = (1024, 512)           # two 512 islands: front projection | back projection


# ------------------------------------------------------------------------------------------------ mapping
class FaceMap:
    """planar projection of the head used for both the UVs and the painting (so they always agree)"""
    def __init__(self, h):
        self.h = h
        self.cx = 0.0
        self.cy = h.head_c[1]
        self.W = h.hw * 1.52
        self.Hh = h.hh * 1.20
        self.z_seam = h.head_c[2] + 0.014 * (h.hh / 0.205)

    def uv(self, P, front):
        """P (n,3) world positions; front (n,) bool -> UV in the 2:1 atlas (front island left, back island right)"""
        xl = (P[:, 0] - self.cx) / self.W
        v = (self.cy + self.Hh / 2 - P[:, 1]) / self.Hh
        u_front = (0.5 - xl) * 0.5
        u_back = 0.5 + (0.5 + xl) * 0.5
        return np.stack([np.where(front, u_front, u_back), v], 1)

    def px(self, x, y):
        """metres -> pixel in the FRONT island (512 x 512 inside the 1024x512 atlas)"""
        u = 0.5 - (x - self.cx) / self.W
        v = (self.cy + self.Hh / 2 - y) / self.Hh
        return u * 512.0, v * 512.0

    def m2px(self, dx, dy):
        return dx / self.W * 512.0, dy / self.Hh * 512.0


# ------------------------------------------------------------------------------------------------ helpers
def _noise(shape, scale, seed, octaves=3):
    rs = np.random.RandomState(seed)
    out = np.zeros(shape); amp = 1.0; tot = 0.0
    for o in range(octaves):
        sh = (max(2, int(shape[0] / scale)), max(2, int(shape[1] / scale)))
        n = rs.rand(*sh)
        n = ndimage.zoom(n, (shape[0] / sh[0], shape[1] / sh[1]), order=3, mode='wrap')[:shape[0], :shape[1]]
        out += amp * (n - 0.5); tot += amp; amp *= 0.5; scale /= 2.0
        scale = max(scale, 1.0)
    return out / tot * 2.0


def _mask_ellipse(shape, cx, cy, rx, ry, soft=0.35, angle=0.0):
    H, W = shape
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    x -= cx; y -= cy
    ca, sa = np.cos(angle), np.sin(angle)
    xr = x * ca + y * sa; yr = -x * sa + y * ca
    d = np.sqrt((xr / max(rx, 1e-3)) ** 2 + (yr / max(ry, 1e-3)) ** 2)
    return np.clip((1.0 - d) / max(soft, 1e-3), 0.0, 1.0) ** 1.0


def _mask_poly(shape, pts, width, blur=0.8, ss=4):
    H, W = shape
    im = Image.new('L', (W * ss, H * ss), 0)
    dr = ImageDraw.Draw(im)
    pp = [(x * ss, y * ss) for x, y in pts]
    dr.line(pp, fill=255, width=max(1, int(round(width * ss))), joint='curve')
    for (x, y) in (pp[0], pp[-1]):
        r = max(1, int(round(width * ss / 2)))
        dr.ellipse([x - r, y - r, x + r, y + r], fill=255)
    im = im.resize((W, H), Image.LANCZOS)
    if blur > 0: im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, np.float64) / 255.0


def _bez(p0, p1, p2, n=24):
    t = np.linspace(0, 1, n)[:, None]
    p0 = np.array(p0); p1 = np.array(p1); p2 = np.array(p2)
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2


def _mul(img, mask, color):
    """multiply img by lerp(1, color, mask)"""
    c = np.array(color, np.float64)[None, None, :]
    m = mask[..., None]
    return img * (1.0 - m + m * c)


def _normal_from_height(hmap, strength):
    gy, gx = np.gradient(hmap)
    nx = -gx * strength; ny = gy * strength; nz = np.ones_like(hmap)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / n, ny / n, nz / n], -1) * 0.5 + 0.5


def _save(arr, path, jpg=False, q=92):
    a = (np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8)
    im = Image.fromarray(a)
    if jpg: im.save(path, quality=q, optimize=True)
    else: im.save(path, optimize=True)


def _tileable_noise(n, scale, seed):
    rs = np.random.RandomState(seed)
    k = max(2, int(n / scale))
    base = rs.rand(k, k)
    return ndimage.zoom(np.tile(base, (3, 3)), n / k, order=3)[n:2 * n, n:2 * n] - 0.5


# ------------------------------------------------------------------------------------------------ face
def paint_face(h, kind, seed=1):
    """returns (albedo (512,1024,3), height (512,1024)) for the head atlas"""
    fm = FaceMap(h)
    D = h.D; hd = D["head"]
    H_, W_ = FACE_TEX[1], FACE_TEX[0]
    S = (512, 512)
    alb = np.ones((512, 512, 3), np.float64)
    hgt = np.zeros((512, 512), np.float64)
    rs = np.random.RandomState(seed)
    k = h.hh / 0.205
    child = D["child"]; female = D["sex"] == "f"

    # --- large-scale skin variation (never leaves a narrow band so every tone stays natural)
    lo = _noise(S, 90, seed + 1, 3); mid = _noise(S, 18, seed + 2, 2)
    alb *= (1.0 + 0.030 * lo[..., None] * np.array([1.0, 0.9, 0.8]))
    alb *= (1.0 + 0.012 * mid[..., None])

    # --- warmth: cheeks, nose, ears are redder; eye sockets slightly cooler/darker; chin lighter
    ex = hd["ipd"] / 2; ey = h.eye_y
    for sgn in (1, -1):
        cxp, cyp = fm.px(sgn * (ex + 0.004), ey - 0.030 * k)
        rx, ry = fm.m2px(0.026 * k, 0.020 * k)
        alb = _mul(alb, _mask_ellipse(S, cxp, cyp, rx, ry, 0.9), (1.0, 0.92, 0.92) if not child else (1.0, 0.90, 0.90))
        cxp, cyp = fm.px(sgn * (ex + 0.001), ey - 0.003)
        rx, ry = fm.m2px(0.025 * k, 0.013 * k)
        alb = _mul(alb, _mask_ellipse(S, cxp, cyp, rx, ry, 0.95), (0.95, 0.92, 0.95))
    cxp, cyp = fm.px(0.0, h.nose_base_y + 0.004)
    rx, ry = fm.m2px(0.016 * k, 0.014 * k)
    alb = _mul(alb, _mask_ellipse(S, cxp, cyp, rx, ry, 0.95), (1.0, 0.93, 0.93))

    # --- lips: tone x pink, upper slightly darker than lower; vertical lip lines in the height map
    my = h.mouth_y; mw = hd["mouth_w"] / 2
    ucx, ucy = fm.px(0.0, my + 0.0042)
    lcx, lcy = fm.px(0.0, my - 0.0070)
    rxu, ryu = fm.m2px(mw * 0.88, 0.0068)
    rxl, ryl = fm.m2px(mw * 0.78, 0.0080)
    lipU = _mask_ellipse(S, ucx, ucy, rxu, ryu, 0.55); lipL = _mask_ellipse(S, lcx, lcy, rxl, ryl, 0.55)
    lipcol_u = (0.98, 0.72, 0.72) if female else (0.98, 0.76, 0.76)
    lipcol_l = (1.0, 0.66, 0.68) if female else (1.0, 0.72, 0.72)
    alb = _mul(alb, lipU, lipcol_u); alb = _mul(alb, lipL, lipcol_l)
    bow_cx, bow_cy = fm.px(0.0, my + 0.0080)
    bow_rx, bow_ry = fm.m2px(mw * 0.16, 0.0026)
    lipU = lipU * (1.0 - 0.55 * _mask_ellipse(S, bow_cx, bow_cy, bow_rx, bow_ry, 0.9))
    lipmask = np.clip(lipU + lipL, 0, 1)
    seam_dark = _mask_ellipse(S, fm.px(0.0, my - 0.0007)[0], fm.px(0.0, my - 0.0007)[1], *fm.m2px(mw * 0.96, 0.0026), 0.9)
    alb = _mul(alb, seam_dark, (0.80, 0.70, 0.72))
    yy, xx = np.mgrid[0:512, 0:512].astype(np.float64)
    hgt += 0.12 * lipmask * (np.sin(xx * 1.9 + 3.0 * _noise(S, 6, seed + 5, 1)) * 0.5 + 0.5)
    # mouth line: dark curve with lifted corners (a calm, friendly smile)
    p0 = fm.px(-mw * 1.02, my + 0.0010); p1 = fm.px(0.0, my - 0.0016); p2 = fm.px(mw * 1.02, my + 0.0010)
    line = _mask_poly(S, _bez(p0, p1, p2, 32), 1.6, 0.7)
    alb = _mul(alb, line, (0.50, 0.40, 0.40))
    hgt -= 0.5 * line

    # --- eyes: lash lines, lid creases, inner corner pink, under-eye line
    r = hd["eye_r"]
    for sgn in (1, -1):
        ecx = sgn * ex; ecy = ey - 0.07 * r
        sx, sy = 1.18 * r, 0.47 * r
        # upper lash line (thicker toward the outer corner), lower lid line (faint)
        pts = []
        for t in np.linspace(np.pi * 0.02, np.pi * 0.98, 40):
            x = ecx + np.cos(t) * sx * sgn
            y = ecy + np.sin(t) * sy * 1.08
            pts.append(fm.px(x, y))
        up = _mask_poly(S, pts, 2.6 if not female else 3.2, 0.9)
        alb = _mul(alb, up, (0.28, 0.24, 0.24))
        hgt -= 0.18 * up
        # lashes: short flicks at the outer half of the upper line
        lashes = np.zeros(S)
        outer = [p for i, p in enumerate(pts) if i < 18]
        for (px_, py_) in outer[::2]:
            dx = 1 if sgn == -1 else -1
            q = _mask_poly(S, [(px_, py_), (px_ + dx * rs.uniform(1.5, 3.0), py_ - rs.uniform(2.5, 5.0 if female else 3.5))], 1.0, 0.6)
            lashes = np.maximum(lashes, q)
        alb = _mul(alb, lashes, (0.32, 0.28, 0.28))
        lows = []
        for t in np.linspace(np.pi * 1.08, np.pi * 1.92, 30):
            lows.append(fm.px(ecx + np.cos(t) * sx * sgn, ecy + np.sin(t) * sy * 1.12))
        lo_l = _mask_poly(S, lows, 1.3, 1.0)
        alb = _mul(alb, lo_l, (0.82, 0.72, 0.72))
        # eyelid crease above the opening
        cr = []
        for t in np.linspace(np.pi * 0.10, np.pi * 0.90, 30):
            cr.append(fm.px(ecx + np.cos(t) * sx * 1.04 * sgn, ecy + np.sin(t) * sy * 1.75 + 0.002))
        crease = _mask_poly(S, cr, 1.6, 1.4)
        alb = _mul(alb, crease, (0.86, 0.80, 0.80))
        hgt -= 0.35 * crease
        # tear duct (inner corner)
        icx, icy = fm.px(ecx - sgn * sx * 0.98, ecy - 0.0004)
        rx2, ry2 = fm.m2px(0.0035, 0.0030)
        alb = _mul(alb, _mask_ellipse(S, icx, icy, rx2, ry2, 0.9), (1.0, 0.72, 0.72))

    # --- eyebrows: many soft hair strokes following an arch
    brow_w = (0.0058 if not female else 0.0040) * k * (1.25 if not child else 1.0)
    if kind == "man": brow_w *= 1.25
    for sgn in (1, -1):
        by = ey + 0.0190 * k + (0.003 if not child else 0.0)
        xin = sgn * (ex - 0.014 * k); xout = sgn * (ex + 0.020 * k); xmid = sgn * (ex + 0.004 * k)
        p0 = fm.px(xin, by - 0.0015); p1 = fm.px(xmid + sgn * 0.002, by + 0.0075 * k); p2 = fm.px(xout, by - 0.0042)
        curve = _bez(p0, p1, p2, 40)
        bm = np.zeros(S)
        for i in range(len(curve) - 1):
            # taper: thickest at the inner third
            t = i / (len(curve) - 1)
            wid = (1.0 - 0.55 * t) * fm.m2px(brow_w, 0)[0] * 1.9
            for j in range(3):
                off = rs.uniform(-0.8, 0.8)
                a = curve[i] + np.array([0.0, off]); b = curve[i + 1] + np.array([rs.uniform(-0.6, 0.6), off + rs.uniform(-0.5, 0.5)])
                bm = np.maximum(bm, _mask_poly(S, [tuple(a), tuple(b)], max(0.8, wid * 0.55), 0.55) * rs.uniform(0.55, 1.0))
        alb = _mul(alb, bm, (0.40, 0.34, 0.32))
        hgt += 0.10 * bm

    # --- nostrils
    for sgn in (1, -1):
        nx_, ny_ = fm.px(sgn * hd["nose_w"] * 0.52, h.nose_base_y + 0.0035)
        rx2, ry2 = fm.m2px(hd["nose_w"] * 0.30, 0.0034)
        alb = _mul(alb, _mask_ellipse(S, nx_, ny_, rx2, ry2, 0.7), (0.45, 0.32, 0.32))

    # --- freckles / stubble
    if kind == "girl" or kind == "boy":
        n_fr = 90 if kind == "girl" else 38
        for _ in range(n_fr):
            sgn = rs.choice([-1, 1])
            x = sgn * abs(rs.normal(0.020, 0.012)); y = ey - 0.020 * k + rs.normal(0.0, 0.010)
            if abs(x) > 0.045 or abs(y - (ey - 0.020 * k)) > 0.022: continue
            cx, cy = fm.px(x, y)
            rr = rs.uniform(0.9, 1.9)
            alb = _mul(alb, _mask_ellipse(S, cx, cy, rr, rr, 0.8), (0.88, 0.78, 0.70))
    if kind == "man":
        stub = (rs.rand(*S) < 0.40).astype(np.float64)
        jaw = np.zeros(S)
        # beard-shadow zone: lower face + upper lip, fading toward the cheeks
        jcx, jcy = fm.px(0.0, h.D["chin"] + 0.050)
        rx2, ry2 = fm.m2px(0.060, 0.058)
        jaw = _mask_ellipse(S, jcx, jcy, rx2, ry2, 1.1)
        lipsz = _mask_ellipse(S, *fm.px(0.0, my + 0.011), *fm.m2px(0.024, 0.010), 0.9)
        zone = np.clip(jaw + lipsz, 0, 1) * (1.0 - 0.9 * lipmask)
        sm = ndimage.gaussian_filter(stub, 0.8)
        alb = _mul(alb, zone * (0.35 + 0.65 * sm), (0.80, 0.78, 0.78))

    # --- pores / fine grain (fades toward the island edges where projection stretches)
    edge = 1.0 - np.clip((np.abs(xx - 256.0) - 150.0) / 100.0, 0, 1)
    pore = _noise(S, 2.2, seed + 9, 2)
    alb *= (1.0 + 0.014 * pore[..., None] * edge[..., None])
    hgt += 0.10 * pore * edge + 0.05 * _noise(S, 9, seed + 10, 2) * edge

    # --- back island: plain skin, ears pinker, a little neck-hair shadow; same tone family
    back = np.ones((512, 512, 3))
    back *= (1.0 + 0.025 * _noise(S, 80, seed + 21, 3)[..., None] * np.array([1.0, 0.9, 0.8]))
    back *= (1.0 + 0.010 * _noise(S, 3, seed + 22, 2)[..., None])
    bh = 0.08 * _noise(S, 2.5, seed + 23, 2)
    for sgn in (1, -1):
        # ears live at x = +-hw/2 on the head sides; the back island is mirrored (u = 0.5 + x/W ...)
        ex_u = 0.5 + (sgn * (h.hw / 2) - fm.cx) / fm.W
        ey_v = (fm.cy + fm.Hh / 2 - (h.head_c[1] - 0.018 * k)) / fm.Hh
        back = _mul(back, _mask_ellipse(S, ex_u * 512, ey_v * 512, 38 * k, 70 * k, 1.0), (1.0, 0.88, 0.86))
    full = np.ones((512, 1024, 3)); full[:, :512] = alb; full[:, 512:] = back
    hfull = np.zeros((512, 1024)); hfull[:, :512] = hgt; hfull[:, 512:] = bh
    # feather the island borders so bilinear filtering never bleeds the other island
    return np.clip(full, 0, 1.0), hfull


# ------------------------------------------------------------------------------------------------ body skin / cloth
def tile_skin(seed=3, n=256):
    a = np.ones((n, n, 3))
    a *= (1.0 + 0.03 * _tileable_noise(n, 60, seed)[..., None] * np.array([1.0, 0.9, 0.8]))
    a *= (1.0 + 0.012 * _tileable_noise(n, 5, seed + 1)[..., None])
    hmap = 0.6 * _tileable_noise(n, 3, seed + 2) + 0.3 * _tileable_noise(n, 9, seed + 3)
    return np.clip(a, 0, 1), hmap


def tile_knit(n=256, seed=5):
    """jersey / t-shirt knit: rows of tiny V stitches"""
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    period = 8.0
    cell_x = (x % period) / period; cell_y = (y % (period * 1.25)) / (period * 1.25)
    v = np.abs(cell_x - 0.5) * 2.0
    stitch = np.clip(1.0 - np.abs(cell_y - (0.15 + 0.6 * v)) * 4.0, 0, 1)
    hmap = stitch * 0.8 + 0.15 * _tileable_noise(n, 3, seed)
    alb = 0.93 + 0.07 * (stitch - 0.5) + 0.04 * _tileable_noise(n, 2, seed + 1) + 0.03 * _tileable_noise(n, 40, seed + 2)
    return np.clip(np.repeat(alb[..., None], 3, 2), 0, 1), hmap


def tile_denim(n=256, seed=7):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    twill = np.sin((x + y) * 2 * np.pi / 6.0) * 0.5 + 0.5
    warp = np.sin(x * 2 * np.pi / 3.0) * 0.5 + 0.5
    hmap = 0.6 * twill + 0.3 * warp + 0.2 * _tileable_noise(n, 2, seed)
    fade = _tileable_noise(n, 48, seed + 2)
    alb = 0.80 + 0.10 * twill + 0.05 * (warp - 0.5) + 0.12 * fade + 0.03 * _tileable_noise(n, 1.5, seed + 3)
    out = np.repeat(np.clip(alb, 0, 1)[..., None], 3, 2)
    out[..., 2] *= 1.0; out[..., 0] *= 0.98
    return np.clip(out, 0, 1), hmap


def tile_canvas(n=256, seed=9):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    w1 = np.sin(x * 2 * np.pi / 4.0) * 0.5 + 0.5
    w2 = np.sin(y * 2 * np.pi / 4.0) * 0.5 + 0.5
    cross = (((x // 2 + y // 2) % 2) == 0)
    hmap = np.where(cross, w1, w2) * 0.6 + 0.25 * _tileable_noise(n, 2, seed)
    alb = 0.88 + 0.08 * (hmap - 0.4) + 0.05 * _tileable_noise(n, 30, seed + 1)
    return np.clip(np.repeat(alb[..., None], 3, 2), 0, 1), hmap


def tile_rubber(n=128, seed=11):
    hmap = 0.5 * _tileable_noise(n, 2, seed) + 0.5 * _tileable_noise(n, 8, seed + 1)
    alb = 0.90 + 0.06 * hmap
    return np.clip(np.repeat(alb[..., None], 3, 2), 0, 1), hmap


# ------------------------------------------------------------------------------------------------ hair
def hair_tex(style, seed=1, w=512, hgt=512):
    """strand texture: vertical strands (u = around the head, v = down); tileable in u"""
    rs = np.random.RandomState(seed)
    base = np.full((hgt, w), 0.70)
    strands = np.zeros((hgt, w))
    n = 420 if style != "short_side" else 380
    wavy = style in ("bob",)
    for i in range(n):
        x0 = rs.uniform(0, w); wd = rs.uniform(0.8, 2.4)
        amp = rs.uniform(0.5, 3.5) if wavy else rs.uniform(0.2, 1.4)
        fr = rs.uniform(0.01, 0.03); ph = rs.uniform(0, 6.28)
        ys = np.arange(hgt)
        xs = (x0 + amp * np.sin(ys * fr * (2 if wavy else 1) + ph)) % w
        val = rs.uniform(0.35, 1.0)
        for dx in (-1, 0, 1):
            xi = ((xs + dx) % w).astype(int)
            strands[ys, xi] = np.maximum(strands[ys, xi], val * (1.0 - 0.45 * abs(dx)))
    strands = ndimage.gaussian_filter(strands, (1.2, 0.7))
    clump = ndimage.gaussian_filter(_noise((hgt, w), 24, seed + 3, 2), (6, 1.2))
    sheen = np.exp(-((np.arange(hgt) - hgt * 0.35) / (hgt * 0.22)) ** 2)[:, None]
    alb = 0.42 + 0.58 * np.clip(strands * 1.5, 0, 1) * (0.75 + 0.25 * clump) + 0.0 * sheen
    alb = np.clip(alb * (0.85 + 0.15 * (1.0 - np.arange(hgt)[:, None] / hgt * 0.3)), 0, 1)
    height = strands + 0.4 * clump
    return np.repeat(alb[..., None], 3, 2), height


# ------------------------------------------------------------------------------------------------ eyes
def eye_tex(n=256, iris=(0.44, 0.26, 0.12), seed=3):
    rs = np.random.RandomState(seed)
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    cx = cy = (n - 1) / 2.0
    rr = np.hypot(x - cx, y - cy) / (n / 2.0)             # 1.0 at the equator
    ang = np.arctan2(y - cy, x - cx)
    sclera = np.array([0.94, 0.92, 0.89])
    img = np.ones((n, n, 3)) * sclera
    # vignette: shadow from the lids
    img *= (1.0 - 0.30 * np.clip((rr - 0.55) / 0.45, 0, 1) ** 1.5)[..., None]
    top = np.clip((cy - y) / (n / 2.0), 0, 1)
    img *= (1.0 - 0.28 * top ** 2)[..., None]
    # faint veins
    veins = _noise((n, n), 10, seed + 4, 2)
    img[..., 1:] *= (1.0 - 0.07 * np.clip(veins, 0, 1) * np.clip((rr - 0.6) / 0.4, 0, 1))[..., None]
    # iris
    ir = 0.50; pr = 0.22
    streak = _noise((n, n), 3, seed + 5, 1) * 0.5 + np.sin(ang * 40.0 + 6.0 * _noise((n, n), 12, seed + 6, 1)) * 0.5
    t = np.clip((rr - pr) / (ir - pr), 0, 1)
    ic = np.array(iris)
    irisc = ic[None, None, :] * (0.65 + 0.55 * (1.0 - t)[..., None]) * (0.85 + 0.15 * streak[..., None])
    ring = np.clip((rr - (ir - 0.07)) / 0.07, 0, 1)
    irisc = irisc * (1.0 - 0.75 * ring[..., None])
    inside = (rr < ir)
    edge = np.clip((ir - rr) / 0.012, 0, 1)
    img = img * (1.0 - edge[..., None]) + irisc * edge[..., None]
    pupil = np.clip((pr - rr) / 0.012, 0, 1)
    img = img * (1.0 - pupil[..., None]) + np.array([0.02, 0.015, 0.015])[None, None, :] * pupil[..., None]
    # catch-light (soft, upper-left), a second faint one lower-right
    for (u, v, rad, a) in ((0.36, 0.34, 0.055, 0.95), (0.60, 0.64, 0.028, 0.35)):
        d = np.hypot((x / n) - u, (y / n) - v)
        img = img + (np.clip(1.0 - d / rad, 0, 1) ** 1.5)[..., None] * a
    return np.clip(img, 0, 1)


# ------------------------------------------------------------------------------------------------ export
def normal_png(hmap, strength, path):
    n = _normal_from_height(hmap, strength)
    _save(n, path)
