"""Build the four skinned human characters (boy, girl, man, woman).

    python3 build_humans.py boy girl man woman        # production quality (slow: decimation)
    python3 build_humans.py --draft boy               # coarse, fast, for design iteration

Outputs (relative to the project root):
    assets/models/avatar_<kind>.glb            skinned mesh + skeleton (no embedded images)
    assets/textures/avatar/*.png|jpg           skin / hair / eye / fabric maps
    assets/ui/portraits/<kind>.png             transparent portrait used by the character-select screen
    visuals/avatar_specs.gd                    generated constants (height, attach points, bone list)
"""
import json, os, struct, sys, time
import numpy as np
from PIL import Image
from scipy import sparse
from scipy.sparse import csgraph

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from humanlib import (mesh_adaptive, project_to_surface, grad, sdf_ao, skin_weights, decimate, Prim, render,
                      adjacency, compact, smin)
from human_model import Human
import human_tex as T

CORE_JOINTS = ["Hips", "Spine", "Neck", "Head", "UpperArm_R", "Forearm_R", "Hand_R", "UpperArm_L", "Forearm_L", "Hand_L",
               "Thigh_R", "Shin_R", "Foot_R", "Thigh_L", "Shin_L", "Foot_L"]
MAT_NAMES = ["avatar_skin_head", "avatar_skin_body", "avatar_shirt", "avatar_pants", "avatar_shoe", "avatar_sole", "avatar_hair", "avatar_eye"]

STAGE = "all"      # "mesh" | "decimate" | "all"  (set by --stage=...; lets a build be split into <5 min steps)
VOXEL = {"boy": 0.0042, "girl": 0.0042, "man": 0.0060, "woman": 0.0056}
BODY_TRIS = {"boy": 11500, "girl": 11500, "man": 13500, "woman": 13000}
HAIR_TRIS = {"boy": 3200, "girl": 3600, "man": 3000, "woman": 3600}


# ------------------------------------------------------------------------------------------------ mesh helpers
def drop_small_components(P, T, min_tris=300):
    n = len(P)
    A = adjacency(n, T)
    ncomp, lab = csgraph.connected_components(A, directed=False)
    counts = np.bincount(lab[T[:, 0]], minlength=ncomp)
    keep_comp = counts >= min_tris
    keep = keep_comp[lab[T[:, 0]]]
    P2, T2 = compact(P, T[keep])
    return P2, T2


def fix_winding(P, T, sdf):
    """make triangle winding agree with the outward SDF gradient (CCW seen from outside)"""
    cen = P[T].mean(1)
    nrm = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    g = grad(sdf, cen)
    dots = np.einsum('ij,ij->i', nrm, g)
    if (dots < 0).mean() > 0.5:
        T = T[:, [0, 2, 1]]
    return T


def boundary_vertices(T, n):
    from collections import Counter
    c = Counter()
    for a, b, d in T:
        for u, v in ((a, b), (b, d), (d, a)):
            c[(min(u, v), max(u, v))] += 1
    bv = np.zeros(n, bool)
    for (u, v), k in c.items():
        if k == 1: bv[u] = bv[v] = True
    return bv



def refine_boundaries(P, T, label_fn, iters=14):
    """Split triangles whose corners carry two different material labels exactly on the label boundary, so the seam
    between shirt / trousers / skin / shoe is a clean line instead of a triangle-sized zigzag.
    Returns (P2, T2, tri_label)."""
    vl = label_fn(P)
    L = vl[T]
    same = (L[:, 0] == L[:, 1]) & (L[:, 1] == L[:, 2])
    two = (~same) & ((L[:, 0] == L[:, 1]) | (L[:, 1] == L[:, 2]) | (L[:, 0] == L[:, 2]))
    three = (~same) & (~two)
    tri_label = L[:, 0].copy()
    if three.any():
        tri_label[three] = label_fn(P[T[three]].mean(1))
    idx = np.nonzero(two)[0]
    if len(idx) == 0:
        return P, T, tri_label
    Ti = T[idx]; Li = L[idx]
    odd = np.where(Li[:, 0] == Li[:, 1], 2, np.where(Li[:, 1] == Li[:, 2], 0, 1))
    ar = np.arange(len(idx))
    ia = (odd + 1) % 3; ib = (odd + 2) % 3
    a = Ti[ar, ia]; b = Ti[ar, ib]; c = Ti[ar, odd]
    La = vl[a]; Lc = vl[c]
    # unique crossing edges (a-c and b-c), each bisected between its two endpoints
    e1 = np.stack([np.minimum(a, c), np.maximum(a, c)], 1)
    e2 = np.stack([np.minimum(b, c), np.maximum(b, c)], 1)
    edges = np.concatenate([e1, e2], 0)
    uniq, inv = np.unique(edges, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    u = uniq[:, 0]; v = uniq[:, 1]
    Lu = vl[u]
    lo_p = P[u].copy(); hi_p = P[v].copy()
    for _ in range(iters):
        mid = 0.5 * (lo_p + hi_p)
        same_as_u = label_fn(mid) == Lu
        lo_p = np.where(same_as_u[:, None], mid, lo_p)
        hi_p = np.where(same_as_u[:, None], hi_p, mid)
    newp = 0.5 * (lo_p + hi_p)
    base = len(P)
    P2 = np.concatenate([P, newp], 0)
    n_idx = base + inv
    p_ac = n_idx[:len(idx)]; q_bc = n_idx[len(idx):]
    t1 = np.stack([a, b, q_bc], 1); t2 = np.stack([a, q_bc, p_ac], 1); t3 = np.stack([p_ac, q_bc, c], 1)
    keep = ~two
    T2 = np.concatenate([T[keep], t1, t2, t3], 0)
    lab2 = np.concatenate([tri_label[keep], La, La, Lc], 0)
    return P2, T2, lab2

def uv_sphere(center, r, nlat=12, nlon=18):
    th = np.linspace(0, np.pi, nlat + 1); ph = np.linspace(0, 2 * np.pi, nlon + 1)
    TH, PH = np.meshgrid(th, ph, indexing='ij')
    X = np.sin(TH) * np.sin(PH); Y = np.cos(TH); Z = -np.sin(TH) * np.cos(PH)    # pole of "forward" faces -Z: use Z-axis pole below
    # rotate so the sphere's pole (iris centre) points to -Z
    V = np.stack([X, Z, -Y], -1).reshape(-1, 3)
    # now the first axis' pole is at (0,0,-1)
    tri = []
    W = nlon + 1
    for i in range(nlat):
        for j in range(nlon):
            a = i * W + j; b = a + 1; c = a + W; d = c + 1
            if i > 0: tri.append((a, b, c))
            if i < nlat - 1: tri.append((b, d, c))
    return V * r + center, V.copy(), np.array(tri, np.int64)


# ------------------------------------------------------------------------------------------------ glTF writer (skinned)
def write_skinned_glb(path, joint_names, joint_parent, joint_pos, prims, extras=None):
    """prims: list of dict(material, P, N, UV, C, J, W, T) all float32/uint arrays"""
    blob = bytearray(); views = []; accessors = []
    def add_view(data, target=None):
        while len(blob) % 4: blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), **({"target": target} if target else {})})
        blob.extend(data); return len(views) - 1
    def add_acc(view, ctype, count, atype, mn=None, mx=None, normalized=False):
        a = {"bufferView": view, "componentType": ctype, "count": int(count), "type": atype}
        if mn is not None: a["min"] = [float(x) for x in mn]; a["max"] = [float(x) for x in mx]
        if normalized: a["normalized"] = True
        accessors.append(a); return len(accessors) - 1
    nodes = [{"name": "Avatar", "children": []}]
    idx = {}
    for nm in joint_names:
        idx[nm] = len(nodes)
        par = joint_parent[nm]
        pos = joint_pos[nm] - (joint_pos[par] if par else np.zeros(3))
        nodes.append({"name": nm, "translation": [float(x) for x in pos]})
    for nm in joint_names:
        par = joint_parent[nm]
        (nodes[idx[par]].setdefault("children", []) if par else nodes[0]["children"]).append(idx[nm])
    # inverse bind matrices (pure translations)
    ibm = np.zeros((len(joint_names), 16), np.float32)
    for i, nm in enumerate(joint_names):
        m = np.eye(4); m[:3, 3] = -joint_pos[nm]
        ibm[i] = m.T.reshape(-1)           # column-major
    v = add_view(ibm.tobytes()); ibm_acc = add_acc(v, 5126, len(joint_names), "MAT4")
    prim_defs = []; materials = []
    for pr in prims:
        P = pr["P"].astype(np.float32); N = pr["N"].astype(np.float32); UV = pr["UV"].astype(np.float32)
        C = pr["C"].astype(np.float32); J = pr["J"].astype(np.uint8); Wt = pr["W"].astype(np.float32); Tt = pr["T"]
        attrs = {}
        attrs["POSITION"] = add_acc(add_view(P.tobytes(), 34962), 5126, len(P), "VEC3", P.min(0), P.max(0))
        attrs["NORMAL"] = add_acc(add_view(N.tobytes(), 34962), 5126, len(N), "VEC3")
        attrs["TEXCOORD_0"] = add_acc(add_view(UV.tobytes(), 34962), 5126, len(UV), "VEC2")
        attrs["COLOR_0"] = add_acc(add_view(C.tobytes(), 34962), 5126, len(C), "VEC4")
        attrs["JOINTS_0"] = add_acc(add_view(J.tobytes(), 34962), 5121, len(J), "VEC4")
        attrs["WEIGHTS_0"] = add_acc(add_view(Wt.tobytes(), 34962), 5126, len(Wt), "VEC4")
        if len(P) < 65535:
            ind = Tt.astype(np.uint16).reshape(-1); ict = 5123
        else:
            ind = Tt.astype(np.uint32).reshape(-1); ict = 5125
        iacc = add_acc(add_view(ind.tobytes(), 34963), ict, len(ind), "SCALAR")
        mid = len(materials)
        materials.append({"name": pr["material"], "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0,
                                                                           "roughnessFactor": 0.7}, "doubleSided": False})
        prim_defs.append({"attributes": attrs, "indices": iacc, "material": mid, "mode": 4})
    mesh_node = len(nodes)
    nodes.append({"name": "Body", "mesh": 0, "skin": 0})
    nodes[0]["children"].append(mesh_node)
    gltf = {"asset": {"version": "2.0", "generator": "Alpha Crush human generator 2.3"},
            "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes,
            "skins": [{"name": "Armature", "joints": [idx[n] for n in joint_names], "inverseBindMatrices": ibm_acc, "skeleton": idx["Hips"]}],
            "meshes": [{"name": "Body", "primitives": prim_defs}], "materials": materials,
            "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}]}
    if extras: gltf["asset"]["extras"] = extras
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4: js += b" "
    while len(blob) % 4: blob.append(0)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    with open(path, "wb") as f: f.write(out)


# ------------------------------------------------------------------------------------------------ main build
def pack_prim(material, P, N, UV, C, T, J, W):
    return dict(material=material, P=P, N=N, UV=UV, C=C, T=T, J=J, W=W)


def tri_planar_uv(P, T, nrm, scale):
    """per-triangle dominant-axis planar projection; returns (corner positions, corner uv, axis key per tri)"""
    ax = np.argmax(np.abs(nrm), axis=1)
    UV = np.zeros((len(T), 3, 2))
    for k in range(3):
        p = P[T[:, k]]
        u = np.where(ax == 0, p[:, 2], np.where(ax == 1, p[:, 0], p[:, 0]))
        v = np.where(ax == 0, -p[:, 1], np.where(ax == 1, p[:, 2], -p[:, 1]))
        UV[:, k, 0] = u * scale; UV[:, k, 1] = v * scale
    return UV, ax


def split_by_group(P, N, C, J, W, T, tri_group, tri_uv, tri_key, material_for_group):
    """Split the triangle list into primitives by group, welding (vertex, key) duplicates. tri_uv (m,3,2)."""
    out = []
    for g, mat in material_for_group.items():
        sel = np.nonzero(tri_group == g)[0]
        if len(sel) == 0: continue
        Tg = T[sel]; UVg = tri_uv[sel]; Kg = tri_key[sel]
        keys = Tg.astype(np.int64) * 8 + Kg[:, None]
        # also separate by rounded uv so different uv at the same key (wrapped hair) never merge
        uvr = np.round(UVg * 4096).astype(np.int64)
        flat_key = np.stack([keys.reshape(-1), uvr.reshape(-1, 2)[:, 0], uvr.reshape(-1, 2)[:, 1]], 1)
        uniq, first, inv = np.unique(flat_key, axis=0, return_index=True, return_inverse=True)
        vi = Tg.reshape(-1)[first]
        out.append(pack_prim(mat, P[vi], N[vi], UVg.reshape(-1, 2)[first], C[vi], inv.reshape(-1, 3).astype(np.int64), J[vi], W[vi]))
    return out


def geometry_key(kind, vox, tris, draft):
    """cache key for meshes: depends on the SDF model + mesher code, but NOT on the skeleton / skin-weight helpers"""
    import hashlib, re
    model = open(os.path.join(HERE, "human_model.py")).read()
    model = re.sub(r"    def bones\(self\):.*?(?=\n    def bbox)", "", model, flags=re.S)
    lib = open(os.path.join(HERE, "humanlib.py")).read()
    lib = re.sub(r"def bone_distance.*?(?=\n# -+ software renderer)", "", lib, flags=re.S)
    return hashlib.md5((model + lib + f"{kind}|{vox}|{tris}|{draft}").encode()).hexdigest()[:10]


def build_kind(kind, draft=False, seed=1, crop=None, vox_override=None, tris_override=None):
    t0 = time.time()
    h = Human(kind)
    D = h.D
    vox = vox_override or VOXEL[kind] * (2.2 if draft else 1.0)
    lo, hi = crop if crop else h.bbox()
    sdf = h.body_sdf
    import hashlib
    cache = "/tmp/humancache"; os.makedirs(cache, exist_ok=True)
    key = geometry_key(kind, vox, tris_override or BODY_TRIS[kind], draft)
    fine_path = os.path.join(cache, f"{kind}_{key}_fine.npz"); dec_path = os.path.join(cache, f"{kind}_{key}_dec.npz")
    if os.path.exists(dec_path):
        z = np.load(dec_path); P, Tt = z["P"], z["T"]
        print(f"[{kind}] using cached decimated mesh ({len(Tt)} tris)", flush=True)
    else:
        if os.path.exists(fine_path):
            z = np.load(fine_path); P, Tt = z["P"], z["T"]
            print(f"[{kind}] using cached fine mesh ({len(Tt)} tris)", flush=True)
        else:
            print(f"[{kind}] meshing at {vox*1000:.1f} mm ...", flush=True)
            P, Tt = mesh_adaptive(sdf, lo, hi, vox)
            P = project_to_surface(sdf, P, 2)
            Tt = fix_winding(P, Tt, sdf)
            P, Tt = drop_small_components(P, Tt, 200)
            np.savez(fine_path, P=P, T=Tt)
            print(f"[{kind}]   fine mesh {len(Tt)} tris  ({time.time()-t0:.0f}s)", flush=True)
        if STAGE == "mesh":
            return None
        # ----- importance: keep the face, ears and hands detailed while decimating
        imp = np.ones(len(P))
        hc = h.head_c
        dh = np.linalg.norm(P - hc, axis=1)
        imp += 3.0 * (dh < h.hh * 0.62)
        front_face = (dh < h.hh * 0.55) & (P[:, 2] < hc[2] + 0.01) & (P[:, 1] < hc[1] + 0.045 * h.hh / 0.205)
        imp += 6.0 * front_face
        for sgn in (1, -1):
            wp = h.W * np.array([sgn, 1, 1])
            imp += 5.0 * (np.linalg.norm(P - (wp + np.array([0, -0.07 * h.hand_s, 0])), axis=1) < 0.10 * h.hand_s)
        if not draft:
            P, Tt = decimate(P, Tt, tris_override or BODY_TRIS[kind], importance=imp, verbose=True)
            print(f"[{kind}]   decimated  ({time.time()-t0:.0f}s)", flush=True)
        np.savez(dec_path, P=P, T=Tt)
        if STAGE == "decimate":
            return None
    hc = h.head_c
    # one projection pass (clamped) so decimated vertices sit on the surface again
    P = project_to_surface(sdf, P, 1, max_step=0.003)
    Tt = fix_winding(P, Tt, sdf)
    # seams between materials follow the true garment edges (shirt hem, sleeve ends, cuffs, soles)
    P, Tt, lab = refine_boundaries(P, Tt, h.labels)
    N = grad(sdf, P)
    # ----- vertex AO (weaker on the face so eye sockets do not turn into dark rings)
    ao = sdf_ao(sdf, P, N, dists=(0.010, 0.025, 0.055, 0.10), strength=1.0)
    near_face = np.clip(1.0 - (np.linalg.norm(P - hc, axis=1) - h.hh * 0.45) / (h.hh * 0.25), 0, 1)
    ao = ao + (1.0 - ao) * 0.55 * near_face
    ao = np.clip(0.25 + 0.75 * ao, 0, 1)
    # ----- skin weights
    bones = h.bones()
    names = [b["name"] for b in bones]
    Jidx, Wt = skin_weights(P, Tt, bones, smooth_iters=2)
    # map bones list order -> CORE_JOINTS order
    order = [names.index(n) for n in CORE_JOINTS]
    remap = np.zeros(len(names), np.uint8)
    for new, old in enumerate(order): remap[old] = new
    Jidx = remap[Jidx]
    # a shirt hangs from the torso: its vertices must not follow the thighs (otherwise the hem swings like a tent)
    leg_ids = np.array([CORE_JOINTS.index(n) for n in CORE_JOINTS if n.startswith(("Thigh", "Shin", "Foot"))])
    shirt_v = (h.labels(P) == 1)[:, None] & np.isin(Jidx, leg_ids)
    Wt = np.where(shirt_v, 0.0, Wt)
    dead = Wt.sum(1) < 1e-6
    Jidx[dead, 0] = CORE_JOINTS.index("Hips"); Wt[dead, 0] = 1.0
    Wt = (Wt / Wt.sum(1, keepdims=True)).astype(np.float32)
    # ----- labels per triangle (evaluate at centroids)
    cen = P[Tt].mean(1)
    tn = np.cross(P[Tt[:, 1]] - P[Tt[:, 0]], P[Tt[:, 2]] - P[Tt[:, 0]])
    tn /= np.maximum(np.linalg.norm(tn, axis=1, keepdims=True), 1e-12)
    fm = T.FaceMap(h)
    group = np.zeros(len(Tt), int)       # 0 head skin, 1 body skin, 2 shirt, 3 pants, 4 shoe, 5 sole
    is_skin = lab == 0
    head_zone = cen[:, 1] > (D["chin"] - 0.004)
    group[is_skin & head_zone] = 0
    group[is_skin & ~head_zone] = 1
    group[lab == 1] = 2; group[lab == 2] = 3; group[lab == 3] = 4; group[lab == 4] = 5
    # ----- UVs
    tri_uv = np.zeros((len(Tt), 3, 2)); tri_key = np.zeros(len(Tt), np.int64)
    front = cen[:, 2] < fm.z_seam
    for k in range(3):
        tri_uv[:, k, :] = fm.uv(P[Tt[:, k]], front)
    key_head = np.where(front, 6, 7)
    cloth_scale = {2: 1.0 / 0.30, 3: 1.0 / 0.30, 4: 1.0 / 0.26, 5: 1.0 / 0.12, 1: 1.0 / 0.30}
    UVp, ax = tri_planar_uv(P, Tt, tn, 1.0)
    for g, sc in cloth_scale.items():
        m = group == g
        tri_uv[m] = UVp[m] * sc; tri_key[m] = ax[m]
    mh = group == 0
    tri_key[mh] = key_head[mh]
    mat_for_group = {0: "avatar_skin_head", 1: "avatar_skin_body", 2: "avatar_shirt", 3: "avatar_pants", 4: "avatar_shoe", 5: "avatar_sole"}
    Cc = np.stack([ao, ao, ao, np.ones_like(ao)], 1)
    prims = split_by_group(P, N, Cc, Jidx, Wt, Tt, group, tri_uv, tri_key, mat_for_group)
    stats = {p["material"]: len(p["T"]) for p in prims}
    # ----- hair
    jpos = h.joints()
    hair = build_hair(h, kind, vox, draft)
    if hair is not None: prims.append(hair)
    # ----- eyes
    eyes = build_eyes(h)
    prims.append(eyes)
    total = sum(len(p["T"]) for p in prims)
    print(f"[{kind}]   tris {stats} hair={len(hair['T']) if hair else 0} eyes={len(eyes['T'])} total={total}  ({time.time()-t0:.0f}s)", flush=True)
    return h, prims, dict(P=P, N=N, T=Tt, J=Jidx, W=Wt, ao=ao)


def build_hair(h, kind, vox, draft):
    hc = h.head_c
    ext = 0.26 if h.hair_style in ("bob", "ponytail") else 0.22
    lo = hc + np.array([-0.20, -ext, -0.20]); hi = hc + np.array([0.20, 0.20, 0.30 if h.hair_style == "ponytail" else 0.22])
    v = vox * (0.8 if not draft else 1.0)
    P, Tt = mesh_adaptive(h.hair_sdf, lo, hi, v, block=14)
    if P is None: return None
    P = project_to_surface(h.hair_sdf, P, 1, max_step=0.003)
    Tt = fix_winding(P, Tt, h.hair_sdf)
    # drop everything buried in the body / scalp
    cen = P[Tt].mean(1)
    keep = h.body_sdf(cen) > 0.0007
    Tt = Tt[keep]
    P, Tt = compact(P, Tt)
    P, Tt = drop_small_components(P, Tt, 150)
    if not draft:
        # protect the open border (hairline) from being collapsed
        bv = boundary_vertices(Tt, len(P))
        imp = np.where(bv, 40.0, 1.0)
        P, Tt = decimate(P, Tt, HAIR_TRIS[kind], importance=imp, verbose=True)
    P = project_to_surface(h.hair_sdf, P, 1, max_step=0.002)
    Tt = fix_winding(P, Tt, h.hair_sdf)
    N = grad(h.hair_sdf, P)
    ao = sdf_ao(h.hair_sdf, P, N, dists=(0.008, 0.02, 0.045), strength=0.8)
    # AO against the head too: hair next to the scalp / neck is darker
    ao = np.minimum(ao, 0.35 + 0.65 * np.clip((h.body_sdf(P) - 0.0) / 0.03, 0, 1))
    ao = np.clip(0.30 + 0.70 * ao, 0, 1)
    C = np.stack([ao, ao, ao, np.ones_like(ao)], 1)
    # UV: cylindrical around the head axis, strands run along v
    q = P - hc
    ang = np.arctan2(q[:, 0], -q[:, 2]) / (2 * np.pi) + 0.5
    uvk = 3.0
    tri_u = ang[Tt] * uvk
    # fix the wrap seam: make u continuous inside each triangle
    mx = tri_u.max(1, keepdims=True)
    tri_u = np.where(mx - tri_u > uvk * 0.5, tri_u + uvk, tri_u)
    tv = ((hc[1] + 0.14) - P[Tt][:, :, 1]) / 0.16
    tri_uv = np.stack([tri_u, tv], -1)
    tri_key = np.zeros(len(Tt), np.int64)
    J = np.zeros((len(P), 4), np.uint8); W = np.zeros((len(P), 4), np.float32)
    J[:, 0] = CORE_JOINTS.index("Head"); W[:, 0] = 1.0
    extra_joint = None
    if h.hair_style == "ponytail" and hasattr(h, "ponytail_root"):
        # weight the tail to a dedicated "Ponytail" bone so it can swing
        root = h.ponytail_root; tip = h.ponytail_tip
        axis = tip - root; L2 = axis @ axis
        t = np.clip(((P - root) @ axis) / L2, 0, 1)
        # only the tail (behind and below the tie) moves
        behind = (P[:, 2] > root[2] - 0.01) & (P[:, 1] < root[1] + 0.01)
        w = np.where(behind, np.clip((t - 0.10) / 0.45, 0, 1) ** 1.2, 0.0)
        J[:, 1] = len(CORE_JOINTS)           # Ponytail = last joint
        W[:, 1] = w; W[:, 0] = 1.0 - w
    g = np.zeros(len(Tt), int)
    prim = split_by_group(P, N, C, J, W, Tt, g, tri_uv, tri_key, {0: "avatar_hair"})
    return prim[0] if prim else None


def build_eyes(h):
    Ps, Ns, UVs, Cs, Ts, Js, Ws = [], [], [], [], [], [], []
    base = 0
    for ctr, r in h.eyes():
        P, N, Tt = uv_sphere(ctr, r, 10, 16)
        # planar front projection (iris faces -Z): u from x, v from y;  u runs opposite to +x like the face map
        UV = np.stack([0.5 - (P[:, 0] - ctr[0]) / (2 * r), 0.5 - (P[:, 1] - ctr[1]) / (2 * r)], 1)
        Ps.append(P); Ns.append(N); UVs.append(UV); Ts.append(Tt + base); base += len(P)
    P = np.concatenate(Ps); N = np.concatenate(Ns); UV = np.concatenate(UVs); Tt = np.concatenate(Ts)
    J = np.zeros((len(P), 4), np.uint8); W = np.zeros((len(P), 4), np.float32)
    J[:, 0] = CORE_JOINTS.index("Head"); W[:, 0] = 1.0
    C = np.ones((len(P), 4), np.float32)
    return pack_prim("avatar_eye", P, N, UV, C, Tt, J, W)


# ------------------------------------------------------------------------------------------------ textures & preview
TONES = {"boy": (0.60, 0.40, 0.29), "girl": (0.90, 0.72, 0.60), "man": (0.46, 0.31, 0.22), "woman": (0.78, 0.56, 0.43)}
HAIRC = {"boy": (0.12, 0.08, 0.05), "girl": (0.34, 0.20, 0.10), "man": (0.10, 0.07, 0.05), "woman": (0.18, 0.11, 0.07)}
SHIRTC = {"boy": (0.22, 0.52, 0.80), "girl": (0.86, 0.34, 0.45), "man": (0.78, 0.42, 0.20), "woman": (0.30, 0.62, 0.52)}
SHOEC = {"boy": (0.80, 0.22, 0.16), "girl": (0.62, 0.36, 0.74), "man": (0.35, 0.24, 0.16), "woman": (0.55, 0.30, 0.22)}
PANTSC = {"boy": (0.18, 0.28, 0.46), "girl": (0.26, 0.30, 0.50), "man": (0.20, 0.28, 0.42), "woman": (0.24, 0.30, 0.46)}


def make_textures(h, kind, outdir, seed=1):
    os.makedirs(outdir, exist_ok=True)
    alb, hgt = T.paint_face(h, kind, seed=seed * 7 + 3)
    T._save(alb, os.path.join(outdir, f"skin_head_{kind}.png"))
    T.normal_png(hgt, 1.6, os.path.join(outdir, f"skin_head_{kind}_n.png"))
    tex = {"skin_head": alb}
    sk, skh = T.tile_skin()
    T._save(sk, os.path.join(outdir, "skin_body.png")); T.normal_png(skh, 1.2, os.path.join(outdir, "skin_body_n.png"))
    kn, knh = T.tile_knit(); T._save(kn, os.path.join(outdir, "fabric_knit.png")); T.normal_png(knh, 2.2, os.path.join(outdir, "fabric_knit_n.png"))
    dn, dnh = T.tile_denim(); T._save(dn, os.path.join(outdir, "fabric_denim.png")); T.normal_png(dnh, 2.4, os.path.join(outdir, "fabric_denim_n.png"))
    cv, cvh = T.tile_canvas(); T._save(cv, os.path.join(outdir, "fabric_canvas.png")); T.normal_png(cvh, 2.0, os.path.join(outdir, "fabric_canvas_n.png"))
    rb, rbh = T.tile_rubber(); T._save(rb, os.path.join(outdir, "rubber.png")); T.normal_png(rbh, 1.5, os.path.join(outdir, "rubber_n.png"))
    hr, hrh = T.hair_tex(h.hair_style, seed=seed + 5)
    T._save(hr, os.path.join(outdir, f"hair_{kind}.png")); T.normal_png(hrh, 2.0, os.path.join(outdir, f"hair_{kind}_n.png"))
    ey = T.eye_tex(256, iris=(0.40, 0.23, 0.10), seed=seed + 2)
    T._save(ey, os.path.join(outdir, "eye.png"))
    return dict(skin_head=alb, skin_body=sk, knit=kn, denim=dn, canvas=cv, rubber=rb, hair=hr, eye=ey)


def preview_prims(h, kind, prims, tex, pose_fn=None):
    tone = np.array(TONES[kind]); mats = {
        "avatar_skin_head": dict(color=tone, tex=tex["skin_head"], rough=0.55, spec=0.22, rim=0.35, rim_tint=(1.0, 0.7, 0.6)),
        "avatar_skin_body": dict(color=tone, tex=tex["skin_body"], uv_scale=(1, 1), rough=0.58, spec=0.18, rim=0.30, rim_tint=(1.0, 0.7, 0.6)),
        "avatar_shirt": dict(color=SHIRTC[kind], tex=tex["knit"], rough=0.9, spec=0.05, rim=0.12),
        "avatar_pants": dict(color=PANTSC[kind], tex=tex["denim"], rough=0.85, spec=0.06, rim=0.10),
        "avatar_shoe": dict(color=SHOEC[kind], tex=tex["canvas"], rough=0.7, spec=0.08, rim=0.08),
        "avatar_sole": dict(color=(0.90, 0.88, 0.82), tex=tex["rubber"], rough=0.8, spec=0.05),
        "avatar_hair": dict(color=HAIRC[kind], tex=tex["hair"], rough=0.45, spec=0.38, rim=0.35),
        "avatar_eye": dict(color=(1, 1, 1), tex=tex["eye"], rough=0.06, spec=0.9, vcol=False),
    }
    out = []
    for p in prims:
        out.append(Prim(p["P"], p["N"], p["UV"], p["C"], p["T"], mats[p["material"]]))
    return out



def euler_yxz(e):
    """Godot's Euler order (YXZ) as a 3x3 matrix"""
    x, y, z = e
    cx, sx, cy, sy, cz, sz = np.cos(x), np.sin(x), np.cos(y), np.sin(y), np.cos(z), np.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]); Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]); Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


IDLE_POSE = {"UpperArm_R": (0.0, 0.0, -0.13), "UpperArm_L": (0.0, 0.0, 0.13), "Forearm_R": (0.14, 0, 0), "Forearm_L": (0.14, 0, 0),
             "Hand_R": (0.12, 0, 0), "Hand_L": (0.12, 0, 0), "Head": (0.03, 0, 0), "Spine": (-0.01, 0, 0)}


def pose_vertices(P, N, J, W, names, pos, par, rot):
    """linear-blend skinning on the CPU with the same joint hierarchy the game uses (QA renders and portraits)"""
    G = {}
    def glob(n):
        if n in G: return G[n]
        M = np.eye(4); M[:3, :3] = euler_yxz(rot.get(n, (0, 0, 0)))
        local = np.eye(4); local[:3, 3] = pos[n] - (pos[par[n]] if par[n] else 0)
        G[n] = (glob(par[n]) @ local @ M) if par[n] else (local @ M)
        return G[n]
    Ms = []
    for n in names:
        bind = np.eye(4); bind[:3, 3] = pos[n]
        Ms.append(glob(n) @ np.linalg.inv(bind))
    Ms = np.stack(Ms)
    Pn = np.zeros_like(P); Nn = np.zeros_like(N)
    for k in range(4):
        w = W[:, k:k + 1]; M = Ms[J[:, k]]
        Pn += w * (np.einsum('nij,nj->ni', M[:, :3, :3], P) + M[:, :3, 3])
        Nn += w * np.einsum('nij,nj->ni', M[:, :3, :3], N)
    Nn /= np.maximum(np.linalg.norm(Nn, axis=1, keepdims=True), 1e-9)
    return Pn, Nn


def pose_prims(h, prims, rot=None):
    jd = h.joints(); names = list(CORE_JOINTS)
    pos = {n: np.array(jd[n][1], float) for n in names}; par = {n: jd[n][0] for n in names}
    out = []
    for p in prims:
        if p["material"] == "avatar_hair" and h.hair_style == "ponytail" and p["J"].max() >= len(names):
            out.append(p); continue            # ponytail bone is not part of the QA skeleton
        Pn, Nn = pose_vertices(p["P"], p["N"], p["J"], p["W"], names, pos, par, rot or IDLE_POSE)
        q = dict(p); q["P"] = Pn; q["N"] = Nn; out.append(q)
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    global STAGE
    draft = "--draft" in sys.argv
    for a in sys.argv:
        if a.startswith("--stage="): STAGE = a.split("=", 1)[1]
    kinds = args or ["boy", "girl", "man", "woman"]
    models = os.path.join(ROOT, "assets", "models"); texdir = os.path.join(ROOT, "assets", "textures", "avatar")
    portdir = os.path.join(ROOT, "assets", "ui", "portraits")
    os.makedirs(models, exist_ok=True); os.makedirs(portdir, exist_ok=True)
    specs = {}
    for kind in kinds:
        built = build_kind(kind, draft=draft)
        if built is None:
            print(f"[{kind}] stage '{STAGE}' done"); continue
        h, prims, body = built
        tex = make_textures(h, kind, texdir)
        J = h.joints()
        names = list(CORE_JOINTS)
        parent = {n: J[n][0] for n in names}
        pos = {n: np.array(J[n][1], float) for n in names}
        if h.hair_style == "ponytail":
            names.append("Ponytail"); parent["Ponytail"] = "Head"; pos["Ponytail"] = np.array(h.ponytail_root, float)
        out = os.path.join(models, f"avatar_{kind}.glb")
        write_skinned_glb(out, names, parent, pos, prims)
        print(f"[{kind}] wrote {out} ({os.path.getsize(out)//1024} KB)", flush=True)
        D = h.D
        specs[kind] = dict(height=h.H, crown=float(h.crown_y), chin=float(D["chin"]), pack=[float(x) for x in D["pack"]],
                           head_c=[float(x) for x in h.head_c], ponytail=(h.hair_style == "ponytail"),
                           eye_y=float(h.eye_y), neck_base=float(D["neck_base"]), foot=float(D["foot"][0]),
                           hat_y=float(h.crown_y - 0.012 - 0.05 * (h.hh / 0.205)), joints=names)
        np.savez_compressed(os.path.join("/tmp", f"human_{kind}.npz"), P=body["P"], N=body["N"], T=body["T"], J=body["J"], W=body["W"])
        if "--noportrait" not in sys.argv:
            make_portrait(h, kind, prims, tex, portdir)
            make_bust(h, kind, prims, tex, portdir)
    json.dump(specs, open(os.path.join("/tmp", "human_specs_" + "_".join(kinds) + ".json"), "w"), indent=1)
    import gen_specs, write_imports
    gen_specs.main()
    write_imports.main()


def make_bust(h, kind, prims, tex, portdir, size=(384, 384)):
    """square head-and-shoulders crop used for the HUD badge and as a quality check"""
    pp = preview_prims(h, kind, pose_prims(h, prims), tex)
    c = h.head_c
    ang = np.radians(-18)
    dist = 0.78 * (h.hh / 0.215)
    eye = np.array([np.sin(ang) * dist, c[1] + 0.02, -np.cos(ang) * dist])
    target = np.array([0.0, c[1] - 0.045, 0.0])
    img, alpha = render(pp, eye=eye, target=target, size=size, fov_deg=24, ss=2, bg=(0.85, 0.9, 0.97), return_mask=True)
    rgba = np.dstack([img, (alpha * 255).astype(np.uint8)])
    Image.fromarray(rgba, "RGBA").save(os.path.join(portdir, f"{kind}_bust.png"), optimize=True)


def make_portrait(h, kind, prims, tex, portdir, size=(560, 860)):
    pp = preview_prims(h, kind, pose_prims(h, prims), tex)
    H = h.H
    ang = np.radians(-16)
    dist = 3.15 * H / 1.4
    eye = np.array([np.sin(ang) * dist, H * 0.52, -np.cos(ang) * dist])
    target = np.array([0.0, H * 0.50, 0.0])
    img, alpha = render(pp, eye=eye, target=target, size=size, fov_deg=24, ss=2, bg=(0.85, 0.9, 0.97), return_mask=True)
    rgba = np.dstack([img, (alpha * 255).astype(np.uint8)])
    Image.fromarray(rgba, "RGBA").save(os.path.join(portdir, f"{kind}.png"), optimize=True)
    print(f"[{kind}] portrait saved", flush=True)


if __name__ == "__main__":
    main()
