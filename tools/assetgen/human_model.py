"""Signed-distance-field model of the four game humans: boy, girl (children) and man, woman (villagers).

The figure is modelled in a relaxed A-pose (arms ~8 deg away from the body) with the face toward -Z.
Everything is defined for the +X ("right") side and mirrored, except hair partings.

Landmarks come from standard anthropometric tables (stature, shoulder / hip breadth, limb segment
lengths, head height-breadth-depth) scaled for a 9-10 year old child, an adult man and an adult woman.
"""
import numpy as np
from scipy.interpolate import PchipInterpolator
from humanlib import (sph, ell, cap, cap_t, torus_y, rbox, smin, smax, union, Loft, fbm3, noise3, _a)

MIRROR = np.array([-1.0, 1.0, 1.0])

# ------------------------------------------------------------------------------------------ dimensions
KIND = {
    "boy": dict(
        sex="m", child=True, H=1.32,
        head=dict(hh=0.226, hw=0.148, hd=0.195, eye_r=0.0120, ipd=0.060, eye_f=0.465, nose_len=0.014, nose_w=0.0120,
                  mouth_w=0.046, mouth_f=0.185, chin_f=0.06, brow=0.9, ear=0.95, jaw=0.88, cheek=1.0),
        chin=1.094, neck_base=1.028, neck_r=0.042, neck_z=0.010,
        sh_x=0.115, sh_y=0.990, elbow_y=0.765, wrist_y=0.598, hip_x=0.070, hip_y=0.650, crotch_y=0.585, knee_y=0.352, ankle_y=0.062,
        waist_y=0.790, chest_y=0.920,
        rows=[(0.545, 0.086, 0.068, 0, 0.004), (0.600, 0.096, 0.073, 0, 0.004), (0.650, 0.102, 0.076, 0, 0.004),
              (0.720, 0.098, 0.074, 0, 0.005), (0.790, 0.092, 0.072, 0, 0.006), (0.860, 0.098, 0.072, 0, 0.002),
              (0.930, 0.106, 0.075, 0, -0.002), (0.985, 0.110, 0.070, 0, -0.002), (1.012, 0.098, 0.060, 0, 0.0), (1.038, 0.052, 0.050, 0, 0.008)],
        delt=0.034, trap=0.025, butt=(0.043, 0.058, 0.044), bust=0.0,
        arm_r=(0.034, 0.028, 0.028, 0.020), leg_r=(0.060, 0.042, 0.042, 0.029), calf=0.030, hand=0.80, foot=(0.215, 0.040),
        shirt_t=0.0120, pants_t=0.0075, sleeve=0.58, hem_y=0.70, waist_cut=0.755, shirt_flare=0.0,
        pack=(0.0, 0.84, 0.092), pack_scale=0.44, hat_scale=0.46,
    ),
    "girl": dict(
        sex="f", child=True, H=1.30,
        head=dict(hh=0.221, hw=0.143, hd=0.189, eye_r=0.0118, ipd=0.058, eye_f=0.465, nose_len=0.013, nose_w=0.0112,
                  mouth_w=0.045, mouth_f=0.185, chin_f=0.055, brow=0.7, ear=0.9, jaw=0.80, cheek=1.12),
        chin=1.079, neck_base=1.015, neck_r=0.038, neck_z=0.010,
        sh_x=0.108, sh_y=0.975, elbow_y=0.760, wrist_y=0.592, hip_x=0.068, hip_y=0.640, crotch_y=0.578, knee_y=0.348, ankle_y=0.060,
        waist_y=0.780, chest_y=0.905,
        rows=[(0.540, 0.085, 0.067, 0, 0.004), (0.595, 0.097, 0.072, 0, 0.004), (0.640, 0.105, 0.075, 0, 0.004),
              (0.715, 0.096, 0.072, 0, 0.005), (0.780, 0.085, 0.068, 0, 0.005), (0.850, 0.090, 0.069, 0, 0.002),
              (0.915, 0.098, 0.072, 0, -0.002), (0.968, 0.102, 0.068, 0, -0.002), (0.998, 0.092, 0.059, 0, 0.0), (1.022, 0.048, 0.047, 0, 0.008)],
        delt=0.032, trap=0.023, butt=(0.044, 0.060, 0.046), bust=0.0,
        arm_r=(0.032, 0.026, 0.026, 0.019), leg_r=(0.058, 0.040, 0.040, 0.027), calf=0.029, hand=0.77, foot=(0.210, 0.038),
        shirt_t=0.0120, pants_t=0.0075, sleeve=0.58, hem_y=0.69, waist_cut=0.745, shirt_flare=0.006,
        pack=(0.0, 0.83, 0.086), pack_scale=0.43, hat_scale=0.45,
    ),
    "man": dict(
        sex="m", child=False, H=1.76,
        head=dict(hh=0.232, hw=0.153, hd=0.197, eye_r=0.0120, ipd=0.064, eye_f=0.495, nose_len=0.029, nose_w=0.0155,
                  mouth_w=0.054, mouth_f=0.178, chin_f=0.07, brow=1.25, ear=1.05, jaw=1.15, cheek=0.9),
        chin=1.528, neck_base=1.468, neck_r=0.057, neck_z=0.016,
        sh_x=0.178, sh_y=1.425, elbow_y=1.115, wrist_y=0.862, hip_x=0.095, hip_y=0.905, crotch_y=0.815, knee_y=0.500, ankle_y=0.078,
        waist_y=1.070, chest_y=1.275,
        rows=[(0.775, 0.148, 0.098, 0, 0.004), (0.860, 0.168, 0.106, 0, 0.004), (0.905, 0.172, 0.108, 0, 0.004),
              (1.000, 0.158, 0.105, 0, 0.004), (1.070, 0.148, 0.099, 0, 0.002), (1.180, 0.160, 0.104, 0, -0.002),
              (1.275, 0.168, 0.112, 0, -0.005), (1.360, 0.172, 0.104, 0, -0.002), (1.425, 0.158, 0.086, 0, 0.004), (1.475, 0.078, 0.072, 0, 0.012)],
        delt=0.049, trap=0.038, butt=(0.052, 0.082, 0.074), bust=0.0, pec=0.058,
        arm_r=(0.049, 0.039, 0.040, 0.028), leg_r=(0.082, 0.057, 0.056, 0.036), calf=0.043, hand=1.0, foot=(0.285, 0.050),
        shirt_t=0.0140, pants_t=0.0095, sleeve=0.55, hem_y=0.86, waist_cut=1.000, shirt_flare=0.0,
        pack=(0.0, 1.21, 0.128), pack_scale=0.52, hat_scale=0.55,
    ),
    "woman": dict(
        sex="f", child=False, H=1.65,
        head=dict(hh=0.220, hw=0.143, hd=0.186, eye_r=0.0116, ipd=0.060, eye_f=0.495, nose_len=0.024, nose_w=0.0135,
                  mouth_w=0.051, mouth_f=0.182, chin_f=0.062, brow=0.8, ear=0.95, jaw=0.88, cheek=1.08),
        chin=1.432, neck_base=1.378, neck_r=0.045, neck_z=0.014,
        sh_x=0.156, sh_y=1.335, elbow_y=1.050, wrist_y=0.810, hip_x=0.092, hip_y=0.855, crotch_y=0.770, knee_y=0.470, ankle_y=0.072,
        waist_y=1.020, chest_y=1.200,
        rows=[(0.725, 0.141, 0.096, 0, 0.004), (0.795, 0.159, 0.104, 0, 0.006), (0.855, 0.166, 0.106, 0, 0.006),
              (0.935, 0.151, 0.099, 0, 0.004), (1.020, 0.124, 0.086, 0, 0.002), (1.115, 0.140, 0.092, 0, -0.002),
              (1.200, 0.143, 0.101, 0, -0.004), (1.290, 0.146, 0.092, 0, -0.002), (1.340, 0.134, 0.078, 0, 0.004), (1.385, 0.062, 0.058, 0, 0.012)],
        delt=0.043, trap=0.031, butt=(0.050, 0.080, 0.078), bust=0.046,
        arm_r=(0.041, 0.034, 0.034, 0.023), leg_r=(0.084, 0.053, 0.052, 0.032), calf=0.038, hand=0.91, foot=(0.250, 0.044),
        shirt_t=0.0130, pants_t=0.0085, sleeve=0.55, hem_y=0.80, waist_cut=0.960, shirt_flare=0.0,
        pack=(0.0, 1.14, 0.114), pack_scale=0.48, hat_scale=0.52,
    ),
}

ARM_ANGLE = 19.0    # degrees, upper arm away from vertical (an A-pose: arms must never touch the hips,
FORE_ANGLE = 12.0   # otherwise the mesher fuses them to the body and skinning stretches a web between them)


def mir(p):
    return p * MIRROR


class Human:
    def __init__(self, kind):
        self.kind = kind
        self.D = D = KIND[kind]
        self.H = D["H"]
        h = D["head"]
        self.hh, self.hw, self.hd = h["hh"], h["hw"], h["hd"]
        self.head_c = np.array([0.0, D["chin"] + 0.5 * self.hh, 0.0])       # centre of the head box
        self.loft = Loft(D["rows"])
        # --- skeleton landmarks (right side; left is mirrored)
        sx, sy = D["sh_x"], D["sh_y"]
        self.S = np.array([sx, sy, 0.0])
        tu = np.tan(np.radians(ARM_ANGLE)); tf = np.tan(np.radians(FORE_ANGLE))
        self.E = np.array([sx + (sy - D["elbow_y"]) * tu, D["elbow_y"], -0.006])
        self.W = np.array([self.E[0] + (D["elbow_y"] - D["wrist_y"]) * tf, D["wrist_y"], -0.022])
        self.Hp = np.array([D["hip_x"], D["hip_y"], 0.0])
        self.K = np.array([D["hip_x"] * 1.10, D["knee_y"], -0.006])
        self.A = np.array([D["hip_x"] * 1.32, D["ankle_y"], 0.002])
        self.neck_c = np.array([0.0, D["neck_base"] - 0.015, D["neck_z"]])
        self.head_joint = np.array([0.0, D["chin"] + 0.10 * self.hh, 0.0])
        self.hips_joint = np.array([0.0, D["hip_y"] - 0.01, 0.0])
        self.spine_joint = np.array([0.0, D["waist_y"], 0.0])
        self.neck_joint = np.array([0.0, D["neck_base"] - 0.01, 0.0])
        # hand frame: direction the forearm points
        fa = self.W - self.E; self.hand_dir = fa / np.linalg.norm(fa)
        self.hand_s = D["hand"]
        # face landmarks (the base head surface is probed so features sit ON the skin, not beside it)
        self._init_face()
        eye_y = D["chin"] + h["eye_f"] * self.hh
        self.eye_y = eye_y
        self.mouth_y = D["chin"] + h["mouth_f"] * self.hh
        self.nose_base_y = D["chin"] + (0.305 if D["child"] else 0.29) * self.hh
        self.crown_y = D["chin"] + self.hh
        zeye = self.zs(eye_y - self.head_c[1], h["ipd"] / 2)
        self.face_front = zeye
        self.eye_c = np.array([h["ipd"] / 2, eye_y, zeye + h["eye_r"] * 0.90 + self.head_c[2]])
        self.build_hair_cfg()

    # ---------------------------------------------------------------------------------------- head
    def head_base(self, q):
        """skull + face mass + jaw + chin + cheeks, in head-box coordinates (origin = box centre, face toward -Z)"""
        D = self.D; h = D["head"]; hh, hw, hd = self.hh, self.hw, self.hd
        k = hh / 0.205                                         # scale from the 9-year-old reference
        ck = h["cheek"]; jw = h["jaw"]
        cran = ell(q, (0, 0.037 * k, 0.010 * k), (hw * 0.5, 0.0655 * k, hd * 0.489))
        face = ell(q, (0, -0.045 * k, -0.020 * k), (hw * 0.435, 0.075 * k, hd * 0.348))
        d = smin(cran, face, 0.035 * k)
        for sgn in (1, -1):
            d = smin(d, sph(q, (sgn * 0.033 * k * (hw / 0.14), -0.034 * k, -0.054 * k), 0.024 * k * ck), 0.035 * k)
            d = smin(d, cap(q, (sgn * 0.052 * k * (hw / 0.14), -0.028 * k, 0.032 * k), (sgn * 0.022 * k, -0.080 * k, -0.052 * k), 0.027 * k * jw, 0.020 * k * jw), 0.03 * k)
        d = smin(d, sph(q, (0, -0.0875 * k, -0.062 * k - (h["chin_f"] - 0.06) * 0.4), 0.0175 * k * (0.9 + 0.35 * jw)), 0.03 * k)
        return d

    def _init_face(self):
        """column of the base head at x = 0 and x = ipd/2: where is the skin surface (z) for a given height?"""
        h = self.D["head"]
        ys = np.linspace(-0.55 * self.hh, 0.55 * self.hh, 221)
        def column(x):
            pts = np.stack([np.full_like(ys, x), ys, np.zeros_like(ys)], 1)
            lo = np.zeros_like(ys); hi = np.full_like(ys, -0.20)
            for _ in range(40):
                mid = 0.5 * (lo + hi); pts[:, 2] = mid
                inside = self.head_base(pts) < 0
                lo = np.where(inside, mid, lo); hi = np.where(inside, hi, mid)
            return 0.5 * (lo + hi)
        self._zs_ys = ys
        self._zs0 = column(0.0)
        self._zse = column(h["ipd"] / 2)

    def zs(self, y_local, x=0.0):
        col = self._zs0 if abs(x) < 1e-6 else self._zse
        return float(np.interp(y_local, self._zs_ys, col))

    def head_sdf(self, p):
        D = self.D; h = D["head"]; hh, hw, hd = self.hh, self.hw, self.hd
        c = self.head_c
        q = p - c
        kid = D["child"]
        k = hh / 0.205
        d = self.head_base(q)
        # brow ridge
        by = self.eye_y - c[1] + 0.017 * k
        bz = self.zs(by, h["ipd"] / 2) + 0.004
        d = smin(d, cap(q, (-hw * 0.30, by, bz), (hw * 0.30, by, bz), 0.0105 * k * h["brow"]), 0.02 * k)
        # nose: root between the eyes, bridge, tip and wings (sized from the surface profile)
        nw = h["nose_w"]
        ny = self.nose_base_y - c[1]
        nz_base = self.zs(ny)
        tip = np.array([0.0, ny + 0.007 * k, nz_base - h["nose_len"]])
        ry = self.eye_y - c[1] + 0.003 * k
        root = np.array([0.0, ry, self.zs(ry) + 0.003])
        d = smin(d, cap(q, root, tip, nw * 0.36, nw * 0.62), 0.012 * k)
        d = smin(d, sph(q, tip + (0, -0.001, 0.001), nw * 0.60), 0.008 * k)
        for sgn in (1, -1):
            d = smin(d, sph(q, (sgn * nw * 0.92, ny + 0.003 * k, nz_base - h["nose_len"] * 0.38), nw * 0.52), 0.010 * k)
            d = smax(d, -sph(q, (sgn * nw * 0.50, ny - 0.0015 * k, nz_base - h["nose_len"] * 0.30), nw * 0.27), 0.003)       # nostril
        # lips, seam and corners sized from the profile at the mouth line
        my = self.mouth_y - c[1]
        lz = self.zs(my)
        mw = h["mouth_w"] / 2
        up = ell(q, (0, my + 0.0040, lz + 0.0030), (mw * 0.80, 0.0058, 0.0088))
        lo = ell(q, (0, my - 0.0068, lz + 0.0038), (mw * 0.70, 0.0066, 0.0092))
        d = smin(d, smin(up, lo, 0.003), 0.005)
        seam = ell(q, (0, my - 0.0004, lz - 0.0030), (mw * 0.97, 0.0009, 0.0070))
        d = smax(d, -seam, 0.0010)
        for sgn in (1, -1):
            d = smax(d, -sph(q, (sgn * mw * 1.0, my + 0.0012, lz + 0.0010), 0.0026), 0.003)
        # eyes: orbit depression, lid mass, almond opening, skin behind the eyeball
        r = h["eye_r"]
        for sgn in (1, -1):
            ec = self.eye_c * np.array([sgn, 1, 1]) - c
            d = smax(d, -ell(q, ec + (0, 0.0, -r * 0.55), (r * 1.70, r * 1.30, r * 0.80)), 0.012 * k)        # orbit
            d = smin(d, ell(q, ec + (0, 0.0, -0.0005), (r * 1.62, r * 1.22, r * 1.12)), 0.007 * k)           # lids
            almond = ell(q, ec + (0, -r * 0.07, -r * 0.45), (r * 1.26, r * 0.50, r * 1.30))
            d = smax(d, -almond, 0.0018)
            d = smin(d, sph(q, ec, r * 0.985), 0.002)
        # ears: tall oval with a hollowed bowl and a lobe
        e = h["ear"]
        for sgn in (1, -1):
            ex = sgn * (hw / 2 * 0.985)
            ec = np.array([ex, -0.018 * k, 0.030 * k])
            ear = ell(q, ec, (0.0100 * e, 0.0440 * e * k, 0.0265 * e * k))
            ear = smin(ear, sph(q, ec + (sgn * 0.001, -0.030 * e * k, 0.002), 0.0105 * e * k), 0.010)
            bowl = ell(q, ec + (sgn * 0.0075 * e, 0.003, -0.002), (0.0090 * e, 0.0270 * e * k, 0.0135 * e * k))
            ear = smax(ear, -bowl, 0.004)
            d = smin(d, ear, 0.010)
        return d

    # ---------------------------------------------------------------------------------------- torso & limbs
    def core_sdf(self, p):
        D = self.D
        d = self.loft(p, 0.03)
        for sgn in (1, -1):
            pp = p if sgn == 1 else mir(p)
            d = smin(d, sph(pp, self.S + (0.008, -0.012, 0.0), D["delt"]), 0.04)                      # deltoid
            d = smin(d, cap(pp, (0.0, D["neck_base"] - 0.005, 0.01), (D["sh_x"] - 0.03, D["sh_y"] + 0.012, 0.004), D["trap"] * 0.9, D["trap"] * 0.7), 0.04)
            bx, by, bz = D["butt"]
            d = smin(d, sph(pp, (bx, D["hip_y"] - 0.045, 0.052 if D["child"] else 0.060), bz), 0.06)                           # glutes
            if D["bust"] > 0:
                d = smin(d, sph(pp, (0.050, D["chest_y"] - 0.010, -0.074), D["bust"]), 0.05)
            if D.get("pec", 0) > 0:
                d = smin(d, ell(pp, (0.060, D["chest_y"] + 0.012, -0.060), (D["pec"], 0.045, 0.045)), 0.05)
        if D["child"]:
            d = smin(d, sph(p, (0, D["waist_y"] - 0.02, -0.042), 0.042), 0.08)                          # tummy
        return d

    def upper_arm_sdf(self, p):
        a = self.D["arm_r"]
        d = cap(p, self.S, self.E, a[0], a[1])
        d = smin(d, sph(p, self.E, a[1] * 1.04), 0.02)
        return d

    def forearm_sdf(self, p):
        a = self.D["arm_r"]
        d = cap(p, self.E, self.W, a[2], a[3])
        # forearm muscle belly
        m = self.E + (self.W - self.E) * 0.28
        d = smin(d, sph(p, m + (0.0, 0.0, 0.002), a[2] * 1.02), 0.03)
        return d

    def leg_sdf(self, p):
        D = self.D; l = D["leg_r"]
        d = cap(p, self.Hp, self.K, l[0], l[1])
        d = smin(d, sph(p, self.K + (0, 0, -0.004), l[1] * 0.90), 0.03)
        d = smin(d, cap(p, self.K, self.A, l[2], l[3]), 0.03)
        # calf belly (back of the shin)
        cc = self.K + (self.A - self.K) * 0.30 + np.array([0.0, 0.0, 0.020])
        d = smin(d, ell(p, cc, (D["calf"], D["calf"] * 1.55, D["calf"] * 1.0)), 0.04)
        # quadriceps / thigh mass
        tc = self.Hp + (self.K - self.Hp) * 0.38 + np.array([0.0, 0.0, -0.006])
        d = smin(d, ell(p, tc, (l[0] * 0.90, l[0] * 1.8, l[0] * 0.90)), 0.06)
        return d

    def hand_sdf(self, p):
        """hand hanging from the right wrist; palm faces the body (-X), thumb forward (-Z)."""
        s = self.hand_s
        down = self.hand_dir                                      # forearm direction (pointing down)
        # build local frame: ly = along the hand (down), lz = forward-ish, lx = outward
        ly = down / np.linalg.norm(down)
        lx = np.cross(np.array([0.0, 0.0, 1.0]), ly); lx /= np.linalg.norm(lx)
        lz = -np.cross(lx, ly)                                    # +Z = toward the back of the body
        q = p - self.W
        lp = np.stack([q @ lx, q @ ly, q @ lz], -1)              # local: x outward, y DOWN along the hand (positive), z toward the back
        # palm: flat slab (x thin) wide along z
        palm = rbox(lp, (-0.002 * s, 0.045 * s, 0.0), (0.0125 * s, 0.047 * s, 0.037 * s), 0.011 * s)
        d = palm
        # fingers: index (front, -z) .. little finger (back)
        zs = np.array([-0.0285, -0.0095, 0.0095, 0.0275]) * s
        ln = np.array([0.074, 0.081, 0.075, 0.060]) * s
        rs = np.array([0.0092, 0.0095, 0.0088, 0.0074]) * s
        for i in range(4):
            k0 = np.array([-0.002 * s, 0.088 * s, zs[i]])
            k1 = k0 + np.array([-0.004 * s, ln[i] * 0.52, 0.0])
            k2 = k1 + np.array([-0.0145 * s, ln[i] * 0.48 * 0.92, 0.0])                  # fingers curl toward the palm (-x)
            d = smin(d, cap(lp, k0, k1, rs[i], rs[i] * 0.92), 0.004)
            d = smin(d, cap(lp, k1, k2, rs[i] * 0.92, rs[i] * 0.78), 0.004)
            d = smin(d, sph(lp, k2, rs[i] * 0.78), 0.003)
        # thumb
        t0 = np.array([-0.001 * s, 0.026 * s, -0.036 * s])
        t1 = t0 + np.array([-0.010 * s, 0.032 * s, -0.020 * s])
        t2 = t1 + np.array([-0.012 * s, 0.026 * s, -0.008 * s])
        d = smin(d, cap(lp, t0, t1, 0.0125 * s, 0.0105 * s), 0.006)
        d = smin(d, cap(lp, t1, t2, 0.0105 * s, 0.0088 * s), 0.004)
        d = smin(d, sph(lp, t2, 0.0088 * s), 0.003)
        # wrist cuff blends into the forearm
        d = smin(d, sph(p, self.W, self.D["arm_r"][3] * 0.98), 0.015)
        return d

    def foot_sdf_skin(self, p):
        """bare foot hidden in the shoe (only gives the ankle some volume)"""
        return sph(p, self.A, self.D["leg_r"][3] * 0.98)

    # ---------------------------------------------------------------------------------------- skin
    def skin_sdf(self, p):
        D = self.D
        d = self.core_sdf(p)
        # neck
        d = smin(d, cap(p, self.neck_c, np.array([0.0, D["chin"] + 0.015, D["neck_z"] * 0.6]), D["neck_r"], D["neck_r"] * 0.92), 0.03)
        d = smin(d, self.head_sdf(p), 0.025)
        for sgn in (1, -1):
            pp = p if sgn == 1 else mir(p)
            d = smin(d, self.upper_arm_sdf(pp), 0.035)
            d = smin(d, self.forearm_sdf(pp), 0.03)
            d = smin(d, self.hand_sdf(pp), 0.01)
            d = smin(d, self.leg_sdf(pp), 0.045)
            d = smin(d, self.foot_sdf_skin(pp), 0.02)
        return d

    # ---------------------------------------------------------------------------------------- clothes
    def _fold_noise(self, p, amp):
        """fabric folds: low-frequency ridges that run around limbs + fine wrinkle noise"""
        return amp * (0.6 * fbm3(p, 14.0, 5, 2) + 0.4 * fbm3(p * np.array([1.0, 3.2, 1.0]), 9.0, 11, 2))

    def _joint_creases(self, p, side=True):
        """horizontal creases around the elbows, hips and knees (bunched cloth)"""
        D = self.D
        out = np.zeros(len(p))
        for jy, wid, amp in ((self.E[1], 0.035, 0.0016), (self.K[1], 0.040, 0.0012), (D["hip_y"] + 0.02, 0.05, 0.0016)):
            g = np.exp(-((p[:, 1] - jy) / wid) ** 2)
            ph = (p[:, 1] - jy) * 2 * np.pi / 0.045 + 5.0 * p[:, 0] + 3.0 * p[:, 2]
            out += amp * g * np.sin(ph) * (0.6 + 0.4 * noise3(p, 18.0, 31))
        return out

    def shirt_sdf(self, p):
        D = self.D; t = D["shirt_t"]
        core = self.core_sdf(p)
        d = core
        for sgn in (1, -1):
            pp = p if sgn == 1 else mir(p)
            lr0 = self.D["leg_r"][0]
            d = smin(d, cap(pp, self.Hp + np.array([0.0, 0.012, 0.0]), self.Hp + (self.K - self.Hp) * 0.30, lr0 * 0.95, lr0 * 0.88), 0.04)   # drapes over the hips
            arm = self.upper_arm_sdf(pp)
            # sleeve: inflated upper arm clipped at `sleeve` of its length
            tt = cap_t(pp, self.S, self.E)
            L = np.linalg.norm(self.E - self.S)
            sl = smax(arm - (t + 0.004), (tt - D["sleeve"]) * L, 0.006)
            sl = sl - 0.0022 * np.exp(-(((tt - D["sleeve"]) * L) / 0.010) ** 2)           # sleeve hem
            d = smin(d, sl + t * 0.2, 0.02)
        d = d - t
        # hem (flat with a gentle curve), collar scoop
        hem = D["hem_y"] + 0.012 * (p[:, 2] / 0.1) + D["shirt_flare"] * 0
        d = smax(d, hem - p[:, 1], 0.004)
        d = d - 0.0022 * np.exp(-((p[:, 1] - hem) / 0.010) ** 2)                      # bottom hem
        if D["shirt_flare"] > 0:
            d = d - D["shirt_flare"] * np.clip((D["hem_y"] + 0.12 - p[:, 1]) / 0.12, 0, 1)
        collar_y = D["neck_base"] + 0.008
        d = smax(d, p[:, 1] - collar_y - 0.01, 0.01)
        scoop = ell(p, (0, D["neck_base"] + 0.020, -0.012), (D["neck_r"] * 1.55, 0.046, D["neck_r"] * 2.0))
        d = smax(d, -scoop, 0.010)
        # neckline rib
        d = d + self._fold_noise(p, 0.0016) + self._joint_creases(p) * 0.6
        return d

    def pants_sdf(self, p):
        D = self.D; t = D["pants_t"]
        d = self.loft(p, 0.03)
        for sgn in (1, -1):
            pp = p if sgn == 1 else mir(p)
            leg = self.leg_sdf(pp)
            d = smin(d, leg, 0.05)
            bx, by, bz = D["butt"]
            d = smin(d, sph(pp, (bx, D["hip_y"] - 0.045, 0.052 if D["child"] else 0.060), bz), 0.06)
        if D["child"]:
            d = smin(d, sph(p, (0, D["waist_y"] - 0.02, -0.042), 0.042), 0.08)
        d = d - t
        # waist (keep below) and cuffs (keep above); trousers hang slightly looser lower down
        loose = 0.004 * np.clip((D["hip_y"] - p[:, 1]) / 0.4, 0, 1)
        d = d - loose
        d = smax(d, p[:, 1] - D["waist_cut"], 0.006)
        cuff = D["ankle_y"] + (0.045 if D["child"] else 0.05)
        d = smax(d, cuff - p[:, 1], 0.006)
        d = d - 0.0024 * np.exp(-((p[:, 1] - cuff) / 0.010) ** 2)                     # turned-up cuff
        # flare at the cuff
        d = d - 0.004 * np.clip((cuff + 0.12 - p[:, 1]) / 0.12, 0, 1)
        # waistband + belt loops
        band = np.exp(-((p[:, 1] - (D["waist_cut"] - 0.014)) / 0.016) ** 2)
        d = d - 0.0022 * band
        d = d + self._fold_noise(p, 0.0018) + self._joint_creases(p)
        return d

    def shoe_sdf(self, p):
        D = self.D; L, W_ = D["foot"]
        s = L / 0.275
        a = self.A
        def one(pp):
            q = pp - np.array([a[0], 0.0, a[2]])
            body = ell(q, (0, 0.050 * s, -0.045 * s), (0.044 * s, 0.050 * s, 0.112 * s))
            toe = ell(q, (0, 0.036 * s, -0.125 * s), (0.049 * s, 0.037 * s, 0.075 * s))
            collar = cap(q, (0, 0.050 * s, 0.015 * s), (0, 0.100 * s, 0.014 * s), 0.046 * s, 0.043 * s)
            d = smin(smin(body, toe, 0.02 * s), collar, 0.02 * s)
            # opening at the ankle
            d = smax(d, -sph(q, (0, 0.112 * s, 0.012 * s), 0.036 * s), 0.006)
            # tongue / laces ridge
            lace = cap(q, (0, 0.085 * s, -0.040 * s), (0, 0.056 * s, -0.095 * s), 0.011 * s)
            d = smin(d, lace, 0.01 * s)
            return d
        d = one(p)
        d = smax(d, -p[:, 1], 0.003)
        return d

    def sole_sdf(self, p):
        D = self.D; L, _ = D["foot"]; s = L / 0.275; a = self.A
        q = p - np.array([a[0], 0.0, a[2]])
        sole = rbox(q, (0.0, 0.013 * s, -0.062 * s), (0.050 * s, 0.013 * s, 0.150 * s), 0.011 * s)
        # toe cap spring
        return sole

    def shoes_all(self, p):
        d = self.shoe_sdf(p)
        d = smin(d, self.sole_sdf(p), 0.004)
        pm = mir(p)
        e = self.shoe_sdf(pm)
        e = smin(e, self.sole_sdf(pm), 0.004)
        return np.minimum(d, e)

    def shoe_upper_all(self, p):
        return np.minimum(self.shoe_sdf(p), self.shoe_sdf(mir(p)))

    def sole_all(self, p):
        return np.minimum(self.sole_sdf(p), self.sole_sdf(mir(p)))

    # ---------------------------------------------------------------------------------------- combined
    def regions(self, p):
        """dict of region SDFs (negative = inside) used for both the union surface and material labels"""
        return {
            "skin": self.skin_sdf(p),
            "shirt": self.shirt_sdf(p),
            "pants": self.pants_sdf(p),
            "shoe": self.shoe_upper_all(p),
            "sole": self.sole_all(p),
        }

    def body_sdf(self, p):
        r = self.regions(p)
        d = smin(r["skin"], r["shirt"], 0.004)
        d = smin(d, r["pants"], 0.004)
        d = smin(d, r["shoe"], 0.004)
        d = smin(d, r["sole"], 0.003)
        return d

    LABELS = ["skin", "shirt", "pants", "shoe", "sole"]

    def labels(self, P):
        r = self.regions(P)
        stack = np.stack([r["skin"] + 0.0020, r["shirt"] - 0.0015, r["pants"] + 0.0004, r["shoe"] + 0.0003, r["sole"] - 0.0006], 1)
        return np.argmin(stack, axis=1)

    # ---------------------------------------------------------------------------------------- eyes
    def eyes(self):
        r = self.D["head"]["eye_r"]
        return [(np.array([s, 1, 1]) * self.eye_c, r) for s in (1, -1)]

    # ---------------------------------------------------------------------------------------- hair
    def build_hair_cfg(self):
        self.hair_style = {"boy": "short", "girl": "ponytail", "man": "short_side", "woman": "bob"}[self.kind]

    def _hairline(self, a, style):
        """height of the hair edge (relative to the head-box centre) as a function of the angle from the face"""
        k = self.hh / 0.205
        a = np.abs(a)
        if style in ("short", "short_side"):
            pts = [(0, 0.036), (0.5, 0.038), (0.95, 0.028), (1.35, 0.008), (1.65, -0.006), (2.2, -0.035), (3.14, -0.052)]
        elif style == "ponytail":
            pts = [(0, 0.030), (0.5, 0.034), (0.95, 0.022), (1.35, 0.000), (1.65, -0.020), (2.2, -0.050), (3.14, -0.068)]
        else:   # bob: the curtain falls well below the ear
            pts = [(0, 0.030), (0.5, 0.034), (0.95, 0.010), (1.35, -0.050), (1.65, -0.100), (2.2, -0.125), (3.14, -0.135)]
        xs = [t[0] for t in pts]; ys = [t[1] * k for t in pts]
        return PchipInterpolator(xs, ys)(np.clip(a, 0, 3.14))

    def hair_sdf(self, p):
        D = self.D; hh, hw, hd = self.hh, self.hw, self.hd
        c = self.head_c; q = p - c
        k = hh / 0.205
        th = (0.0105 if D["child"] else 0.014)
        base = ell(q, (0, 0.037 * k, 0.010 * k), (hw * 0.5 + th, 0.0655 * k + th, hd * 0.489 + th))
        style = self.hair_style
        d = base
        rs = np.random.RandomState(7)
        if style in ("short", "short_side"):
            d = smin(d, ell(q, (0.004, 0.062 * k, 0.0), (hw * 0.5 * 0.82, 0.050 * k, hd * 0.42)), 0.03 * k)        # crown volume
            # fringe / quiff: a few overlapping swept locks
            locks = [((-0.045, 0.060, -0.060), (0.020, 0.050, -0.090), 0.015, 0.010),
                     ((-0.010, 0.066, -0.058), (0.040, 0.044, -0.086), 0.015, 0.009),
                     ((0.025, 0.066, -0.052), (0.058, 0.040, -0.076), 0.014, 0.008),
                     ((-0.055, 0.050, -0.040), (-0.052, 0.036, -0.074), 0.012, 0.008)]
            for a0, b0, r0, r1 in locks:
                d = smin(d, cap(q, np.array(a0) * k, np.array(b0) * k, r0 * k, r1 * k), 0.012 * k)
        elif style == "bob":
            d = smin(d, ell(q, (0, 0.058 * k, 0.004), (hw * 0.5 * 0.88, 0.058 * k, hd * 0.44)), 0.03 * k)
            for sgn in (1, -1):
                d = smin(d, cap(q, (sgn * (hw / 2 + th * 0.2), 0.0, 0.012 * k), (sgn * (hw / 2 + th * 1.0), -0.115 * k, 0.020 * k), 0.036 * k, 0.034 * k), 0.03 * k)
            d = smin(d, cap(q, (-0.045 * k, -0.020 * k, hd / 2 + th * 0.2), (0.045 * k, -0.125 * k, hd / 2 + th * 0.4), 0.052 * k, 0.046 * k), 0.05 * k)
            d = smin(d, cap(q, (0.060 * k, 0.062 * k, -0.060 * k), (-0.040 * k, 0.046 * k, -0.092 * k), 0.018 * k, 0.012 * k), 0.012 * k)
            d = smin(d, cap(q, (-0.040 * k, 0.046 * k, -0.092 * k), (-0.068 * k, 0.010 * k, -0.075 * k), 0.012 * k, 0.009 * k), 0.012 * k)
        elif style == "ponytail":
            d = smin(d, ell(q, (0, 0.060 * k, 0.002), (hw * 0.5 * 0.84, 0.050 * k, hd * 0.43)), 0.03 * k)
            locks = [((0.052, 0.060, -0.058), (-0.030, 0.046, -0.090), 0.016, 0.011),
                     ((-0.030, 0.046, -0.090), (-0.060, 0.016, -0.072), 0.011, 0.008),
                     ((0.015, 0.064, -0.056), (0.055, 0.040, -0.082), 0.015, 0.009)]
            for a0, b0, r0, r1 in locks:
                d = smin(d, cap(q, np.array(a0) * k, np.array(b0) * k, r0 * k, r1 * k), 0.012 * k)
            tie = np.array([0.0, 0.046 * k, hd * 0.5 + th * 0.2])
            d = smin(d, sph(q, tie, 0.016 * k), 0.02 * k)
            pts = [tie, tie + (0, 0.004 * k, 0.034 * k), tie + (0, -0.040 * k, 0.062 * k), tie + (0, -0.100 * k, 0.074 * k), tie + (0, -0.170 * k, 0.070 * k)]
            rad = [0.018 * k, 0.025 * k, 0.024 * k, 0.019 * k, 0.008 * k]
            for i in range(len(pts) - 1):
                d = smin(d, cap(q, pts[i], pts[i + 1], rad[i], rad[i + 1]), 0.03 * k)
            self.ponytail_tip = c + pts[-1]
            self.ponytail_root = c + tie
        # hairline cut: hair only above a smooth curve that rides down toward the nape
        ang = np.arctan2(q[:, 0], -q[:, 2])
        yh = self._hairline(ang, style)
        front = np.clip(1.0 - np.abs(ang) / 1.25, 0.0, 1.0)
        tuft = noise3(np.stack([ang * 6.0, np.zeros_like(ang), np.full_like(ang, 3.0)], 1), 1.0, 41)
        yh = yh + front * (0.007 * k * np.sin(ang * 9.0 + 1.3) + 0.008 * k * tuft)
        sty_k = 0.013 * k
        cut = smax(d, yh - q[:, 1], sty_k)
        # strands: gentle irregular grooves that follow the angle around the head
        n1 = noise3(np.stack([ang * 3.0, q[:, 1] * 12.0, np.zeros_like(ang)], 1), 1.0, 3)
        lump = fbm3(np.stack([q[:, 0], q[:, 1], q[:, 2]], 1) * 1.0, 38.0, 21, 2)
        cut = cut + 0.0005 * np.sin(ang * 26.0 + n1 * 2.5) + 0.0030 * lump
        return cut

    # ---------------------------------------------------------------------------------------- skeleton
    def bones(self):
        """capsule segments used for proximity skin weights (right side listed once, mirrored)"""
        D = self.D
        out = []
        ay = lambda y: float(np.interp(y, self.loft.ys, self.loft.a))
        def add(name, a, b, r, sigma, side=0):
            out.append(dict(name=name, a=np.array(a, float), b=np.array(b, float), r=r, sigma=sigma, side=side))
        add("Hips", (0, D["hip_y"], 0), (0, D["waist_y"] - 0.08, 0), ay(D["hip_y"]) * 0.85, 0.045)
        add("Spine", (0, D["waist_y"] - 0.06, 0), (0, D["neck_base"] - 0.04, 0), ay(D["chest_y"]) * 0.95, 0.05)
        add("Neck", (0, D["neck_base"] - 0.03, D["neck_z"]), (0, D["chin"] + 0.02, D["neck_z"] * 0.6), D["neck_r"] * 1.05, 0.02)
        add("Head", (0, D["chin"] + 0.035, 0.0), (0, D["chin"] + self.hh, 0.0), self.hw * 0.62, 0.03)
        for nm, sgn in (("R", 1), ("L", -1)):
            m = np.array([sgn, 1, 1])
            add("UpperArm_" + nm, self.S * m, self.E * m, max(D["arm_r"][0], D["delt"]) * 1.15, 0.014, sgn)
            add("Forearm_" + nm, self.E * m, self.W * m, D["arm_r"][2] * 1.05, 0.013, sgn)
            add("Hand_" + nm, self.W * m, (self.W + self.hand_dir * 0.18 * self.hand_s) * m, 0.032 * self.hand_s, 0.012, sgn)
            add("Thigh_" + nm, (self.Hp + (self.K - self.Hp) * 0.12) * m, self.K * m, D["leg_r"][0] * 1.05, 0.018, sgn)
            add("Shin_" + nm, self.K * m, self.A * m, D["leg_r"][2] * 1.05, 0.014, sgn)
            add("Foot_" + nm, self.A * m, (self.A + np.array([0, -0.02, -D["foot"][0] * 0.55])) * m, 0.04, 0.012, sgn)
        return out

    def joints(self):
        """name -> (parent, world position)"""
        J = {"Hips": (None, self.hips_joint), "Spine": ("Hips", self.spine_joint), "Neck": ("Spine", self.neck_joint),
             "Head": ("Neck", self.head_joint)}
        for nm, sgn in (("R", 1), ("L", -1)):
            m = np.array([sgn, 1, 1])
            J["UpperArm_" + nm] = ("Spine", self.S * m)
            J["Forearm_" + nm] = ("UpperArm_" + nm, self.E * m)
            J["Hand_" + nm] = ("Forearm_" + nm, self.W * m)
            J["Thigh_" + nm] = ("Hips", self.Hp * m)
            J["Shin_" + nm] = ("Thigh_" + nm, self.K * m)
            J["Foot_" + nm] = ("Shin_" + nm, self.A * m)
        return J

    def bbox(self):
        H = self.H
        return (np.array([-0.40, -0.02, -0.34]), np.array([0.40, H + 0.04, 0.34]))
