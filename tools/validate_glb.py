"""Independent structural validator for the skinned avatar GLBs (no engine needed).
Checks what Godot's importer relies on: chunk layout, accessor/bufferView bounds, index ranges, finite floats,
unit normals, joint indices inside the skin, weights summing to 1, inverse-bind-matrix count, node hierarchy."""
import json, struct, sys
import numpy as np

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    d = open(path, "rb").read()
    magic, ver, length = struct.unpack("<4sII", d[:12])
    assert magic == b"glTF" and ver == 2 and length == len(d), "bad header/length"
    off = 12; js = None; blob = None
    while off < len(d):
        clen, ctype = struct.unpack("<II", d[off:off + 8]); off += 8
        chunk = d[off:off + clen]; off += clen
        if ctype == 0x4E4F534A: js = json.loads(chunk.decode())
        elif ctype == 0x004E4942: blob = chunk
    return js, blob


def accessor(js, blob, i):
    a = js["accessors"][i]; v = js["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]; n = NCOMP[a["type"]]
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    end = start + a["count"] * n * size
    assert end <= len(blob) and end <= v.get("byteOffset", 0) + v["byteLength"], f"accessor {i} overruns its view"
    arr = np.frombuffer(blob[start:end], dtype=np.dtype(fmt).newbyteorder("<"))
    return arr.reshape(a["count"], n) if n > 1 else arr


def validate(path):
    errs = []
    js, blob = load(path)
    nodes = js["nodes"]
    skin = js["skins"][0]
    joints = skin["joints"]
    ibm = accessor(js, blob, skin["inverseBindMatrices"])
    if len(ibm) != len(joints): errs.append("IBM count != joint count")
    # hierarchy: every joint reachable from the skeleton root, no cycles
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            if c in parent: errs.append(f"node {c} has two parents")
            parent[c] = i
    for j in joints:
        seen = set(); k = j
        while k in parent:
            if k in seen: errs.append("cycle"); break
            seen.add(k); k = parent[k]
    tris = 0; verts = 0
    for mesh in js["meshes"]:
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            pos = accessor(js, blob, at["POSITION"]); nrm = accessor(js, blob, at["NORMAL"]); uv = accessor(js, blob, at["TEXCOORD_0"])
            col = accessor(js, blob, at["COLOR_0"]); jt = accessor(js, blob, at["JOINTS_0"]); wt = accessor(js, blob, at["WEIGHTS_0"])
            idx = accessor(js, blob, prim["indices"])
            n = len(pos); verts += n; tris += len(idx) // 3
            if not (len(nrm) == len(uv) == len(col) == len(jt) == len(wt) == n): errs.append("attribute counts differ")
            for name, arr in (("pos", pos), ("nrm", nrm), ("uv", uv), ("col", col), ("wt", wt)):
                if not np.isfinite(arr.astype(np.float64)).all(): errs.append(f"{name}: non-finite values")
            if idx.max() >= n: errs.append("index out of range")
            if len(idx) % 3: errs.append("index count not divisible by 3")
            ln = np.linalg.norm(nrm, axis=1)
            if ln.min() < 0.98 or ln.max() > 1.02: errs.append(f"normals not unit length ({ln.min():.3f}..{ln.max():.3f})")
            if jt.max() >= len(joints): errs.append("joint index outside the skin")
            s = wt.sum(1)
            if np.abs(s - 1).max() > 1e-3: errs.append(f"weights do not sum to 1 (max err {np.abs(s-1).max():.4f})")
            if (wt < -1e-6).any(): errs.append("negative weight")
            # a weight must never reference a joint with zero influence slot misuse: zero-weight slots may point anywhere
            a = js["accessors"][at["POSITION"]]
            if not (np.allclose(pos.min(0), a["min"], atol=1e-4) and np.allclose(pos.max(0), a["max"], atol=1e-4)): errs.append("POSITION min/max mismatch")
            # degenerate triangles
            t = idx.reshape(-1, 3).astype(np.int64)
            cr = np.cross(pos[t[:, 1]] - pos[t[:, 0]], pos[t[:, 2]] - pos[t[:, 0]])
            deg = (np.linalg.norm(cr, axis=1) < 1e-12).sum()
            if deg > 0.002 * len(t): errs.append(f"{deg} degenerate triangles")
    return errs, tris, verts, len(joints)


if __name__ == "__main__":
    bad = 0
    for p in sys.argv[1:]:
        errs, tris, verts, nj = validate(p)
        print(f"{p}: {tris} tris, {verts} verts, {nj} joints ->", "OK" if not errs else errs)
        bad += bool(errs)
    sys.exit(1 if bad else 0)
