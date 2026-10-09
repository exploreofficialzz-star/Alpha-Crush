"""Minimal glTF 2.0 binary (.glb) writer + validator for static, node-hierarchy models."""
import json, struct, numpy as np
from meshkit import Geo, merge

class Node:
    def __init__(self, name, geos=None, t=(0, 0, 0), euler=(0, 0, 0), s=(1, 1, 1), children=None):
        self.name = name; self.geos = [] if geos is None else ([geos] if isinstance(geos, Geo) else list(geos))
        self.t = t; self.euler = euler; self.s = s; self.children = children or []
    def add(self, *nodes):
        self.children += list(nodes); return self

def _quat(euler_deg):
    """XYZ euler (degrees) -> quaternion xyzw"""
    rx, ry, rz = np.radians(euler_deg) / 2
    cx, sx, cy, sy, cz, sz = np.cos(rx), np.sin(rx), np.cos(ry), np.sin(ry), np.cos(rz), np.sin(rz)
    # q = qz * qy * qx
    w = cx * cy * cz + sx * sy * sz
    x = sx * cy * cz - cx * sy * sz
    y = cx * sy * cz + sx * cy * sz
    z = cx * cy * sz - sx * sy * cz
    return [float(x), float(y), float(z), float(w)]

def write_glb(path, root, materials, generator="alpha-crush-assetgen"):
    """root: Node. materials: {name: dict(color=(r,g,b,a), double=bool)} (unknown names get grey)."""
    bin_data = bytearray(); buffer_views = []; accessors = []; meshes = []; nodes = []; mat_list = []; mat_idx = {}

    def add_view(arr, target=None):
        raw = arr.tobytes(); pad = (-len(bin_data)) % 4; bin_data.extend(b'\0' * pad)
        buffer_views.append({"buffer": 0, "byteOffset": len(bin_data), "byteLength": len(raw), **({"target": target} if target else {})})
        bin_data.extend(raw); return len(buffer_views) - 1

    def add_acc(arr, ctype, atype, target=None, minmax=False, normalized=False):
        bv = add_view(arr, target)
        acc = {"bufferView": bv, "componentType": ctype, "count": int(len(arr)), "type": atype}
        if minmax: acc["min"] = [float(x) for x in arr.min(0)]; acc["max"] = [float(x) for x in arr.max(0)]
        if normalized: acc["normalized"] = True
        accessors.append(acc); return len(accessors) - 1

    def material(name, double):
        key = (name, bool(double))
        if key not in mat_idx:
            spec = materials.get(name, {}); col = list(spec.get("color", (0.6, 0.6, 0.6, 1.0)))
            if len(col) == 3: col.append(1.0)
            m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": col, "metallicFactor": 0.0, "roughnessFactor": 0.9}}
            if double or spec.get("double"): m["doubleSided"] = True
            mat_list.append(m); mat_idx[key] = len(mat_list) - 1
        return mat_idx[key]

    def build_mesh(name, geos):
        groups = {}
        for g in geos:
            groups.setdefault((g.mat, g.double), []).append(g)
        prims = []
        for (mname, dbl), gl in groups.items():
            g = merge(gl)
            if g is None: continue
            attrs = {"POSITION": add_acc(g.P.astype('<f4'), 5126, "VEC3", 34962, True),
                     "NORMAL": add_acc(g.N.astype('<f4'), 5126, "VEC3", 34962),
                     "TEXCOORD_0": add_acc(g.UV.astype('<f4'), 5126, "VEC2", 34962),
                     "COLOR_0": add_acc(g.C.astype('<f4'), 5126, "VEC4", 34962)}
            if len(g.P) < 65535: idx = add_acc(g.T.reshape(-1).astype('<u2'), 5123, "SCALAR", 34963)
            else: idx = add_acc(g.T.reshape(-1).astype('<u4'), 5125, "SCALAR", 34963)
            prims.append({"attributes": attrs, "indices": idx, "material": material(mname, dbl), "mode": 4})
        meshes.append({"name": name, "primitives": prims}); return len(meshes) - 1

    def emit(n):
        d = {"name": n.name}
        if any(abs(x) > 1e-9 for x in n.t): d["translation"] = [float(x) for x in n.t]
        if any(abs(x) > 1e-9 for x in n.euler): d["rotation"] = _quat(n.euler)
        if any(abs(x - 1) > 1e-9 for x in n.s): d["scale"] = [float(x) for x in n.s]
        if n.geos: d["mesh"] = build_mesh(n.name + "_mesh", n.geos)
        idx = len(nodes); nodes.append(d)
        kids = [emit(c) for c in n.children]
        if kids: d["children"] = kids
        return idx

    emit(root)
    doc = {"asset": {"version": "2.0", "generator": generator}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes,
           "meshes": meshes, "materials": mat_list, "accessors": accessors, "bufferViews": buffer_views,
           "buffers": [{"byteLength": len(bin_data)}]}
    if not meshes: del doc["meshes"]
    if not mat_list: del doc["materials"]
    js = json.dumps(doc, separators=(',', ':')).encode(); js += b' ' * ((-len(js)) % 4)
    bin_data.extend(b'\0' * ((-len(bin_data)) % 4))
    total = 12 + 8 + len(js) + 8 + len(bin_data)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(bin_data), 0x004E4942)); f.write(bytes(bin_data))
    return total

def read_glb(path):
    """parse back; returns (json, list of per-primitive dicts with numpy arrays)"""
    raw = open(path, 'rb').read()
    magic, ver, length = struct.unpack_from('<III', raw, 0)
    assert magic == 0x46546C67 and ver == 2 and length == len(raw), "bad GLB header"
    jl, jt = struct.unpack_from('<II', raw, 12); assert jt == 0x4E4F534A
    doc = json.loads(raw[20:20 + jl]); off = 20 + jl
    bl, bt = struct.unpack_from('<II', raw, off); assert bt == 0x004E4942
    blob = raw[off + 8: off + 8 + bl]
    ct = {5126: ('<f4', 4), 5123: ('<u2', 2), 5125: ('<u4', 4)}; nc = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    def acc(i):
        a = doc["accessors"][i]; bv = doc["bufferViews"][a["bufferView"]]; dt, _ = ct[a["componentType"]]
        arr = np.frombuffer(blob, dtype=dt, count=a["count"] * nc[a["type"]], offset=bv["byteOffset"] + a.get("byteOffset", 0))
        return arr.reshape(a["count"], nc[a["type"]]) if nc[a["type"]] > 1 else arr
    prims = []
    for m in doc.get("meshes", []):
        for p in m["primitives"]:
            prims.append({"mesh": m["name"], "material": doc["materials"][p["material"]]["name"],
                          **{k: acc(v) for k, v in p["attributes"].items()}, "indices": acc(p["indices"])})
    return doc, prims

def validate_glb(path):
    doc, prims = read_glb(path); problems = []; tris = 0; verts = 0
    for p in prims:
        P, N, I = p["POSITION"], p["NORMAL"], p["indices"]; tris += len(I) // 3; verts += len(P)
        if not np.isfinite(P).all() or not np.isfinite(N).all(): problems.append(f"{p['mesh']}: non-finite data")
        if I.max() >= len(P): problems.append(f"{p['mesh']}: index out of range")
        if len(I) % 3: problems.append(f"{p['mesh']}: index count not multiple of 3")
        L = np.linalg.norm(N, axis=1)
        if (np.abs(L - 1) > 0.02).any(): problems.append(f"{p['mesh']}: {int((np.abs(L-1)>0.02).sum())} non-unit normals")
        tri = I.reshape(-1, 3).astype(np.int64); a, b, c = P[tri[:, 0]], P[tri[:, 1]], P[tri[:, 2]]
        area = np.linalg.norm(np.cross(b - a, c - a), axis=1) * 0.5
        if (area < 1e-12).mean() > 0.2: problems.append(f"{p['mesh']}: >20% degenerate triangles")
    allp = np.vstack([p["POSITION"] for p in prims]) if prims else np.zeros((1, 3))
    return {"tris": tris, "verts": verts, "bbox": (allp.min(0).round(3).tolist(), allp.max(0).round(3).tolist()),
            "materials": sorted({p["material"] for p in prims}), "nodes": len(doc["nodes"]), "problems": problems}
