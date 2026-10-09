#!/usr/bin/env python3
"""Engine-free audit of the generated art: every model/texture/shader the game loads must exist and be well formed."""
import json, os, re, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors = []

# ---------------------------------------------------------------- models
models = {p.stem: p for p in (ROOT / 'assets' / 'models').glob('*.glb')}
if len(models) < 50:
    errors.append(f'assets/models: expected the full generated model set, found {len(models)} (run tools/assetgen/build_models.py)')

def read_glb_json(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw, 0)
    if magic != 0x46546C67 or version != 2 or length != len(raw):
        raise ValueError('bad GLB header')
    jl, jt = struct.unpack_from('<II', raw, 12)
    if jt != 0x4E4F534A:
        raise ValueError('first chunk is not JSON')
    return json.loads(raw[20:20 + jl])

MARKER = re.compile(r'^COL_(BOX|CYL|SPH)_\d+_\d+(_\d+)?(_\d+)?$')
for name, path in sorted(models.items()):
    try:
        doc = read_glb_json(path)
    except Exception as exc:
        errors.append(f'{path.name}: {exc}')
        continue
    tris = 0
    for mesh in doc.get('meshes', []):
        for prim in mesh['primitives']:
            tris += doc['accessors'][prim['indices']]['count'] // 3
    if tris > 30000:
        errors.append(f'{path.name}: {tris} triangles is over the 30k mobile budget')
    for node in doc['nodes']:
        n = node['name']
        if n.startswith('COL_') and not MARKER.match(n):
            errors.append(f'{path.name}: collision marker "{n}" must be COL_<BOX|CYL|SPH>_<cm>_<cm>_<cm> (Godot strips "." from node names)')
        if '.' in n:
            errors.append(f'{path.name}: node name "{n}" contains "." which Godot silently removes')
    if name.startswith('avatar_'):
        names = {n['name'] for n in doc['nodes']}
        for need in ('Hips', 'Spine', 'Head', 'UpperArm_R', 'Forearm_L', 'Thigh_R', 'Shin_L', 'Foot_R', 'Attach_Back', 'Attach_Hat'):
            if need not in names:
                errors.append(f'{path.name}: missing joint/attachment "{need}"')

# ids the scripts ask for must exist
referenced = set()
for gd in ROOT.rglob('*.gd'):
    if 'tests' in gd.parts or 'tools' in gd.parts:
        continue
    text = gd.read_text()
    referenced |= set(re.findall(r'(?:spawn|mesh_of|has_model)\(\s*"([a-z0-9_]+)"', text))
    referenced |= set(re.findall(r'\bplace\(\s*\w+,\s*"([a-z0-9_]+)"', text))
    referenced |= set(re.findall(r'"((?:tree|bush|rock|res)_[a-z0-9]+)"', text)) - {"tree_shadows"}
    if 'MODEL_FOR_ITEM' in text:
        referenced |= set(re.findall(r':\s*"((?:res|crop)_[a-z0-9_]+)"', text))
for sp in ('cow', 'goat', 'deer', 'chicken'):
    referenced.add('animal_' + sp)
for h in ('straw', 'hard', 'sun'):
    referenced.add('hat_' + h)
for i in range(3):
    referenced |= {f'tree_oak_{i}', f'tree_fruit_{i}'}
for missing in sorted(r for r in referenced if r not in models and not r.endswith('_')):   # 'animal_' + species style prefixes are checked above
    errors.append(f'scripts reference model "{missing}" but assets/models/{missing}.glb does not exist')

# ---------------------------------------------------------------- audio
for rel in ('ambience/day_wind_birds.wav', 'ambience/night_crickets.wav', 'ambience/river.wav', 'ambience/rain.wav',
            'sfx/footstep_grass_0.wav', 'sfx/footstep_grass_1.wav', 'sfx/footstep_grass_2.wav'):
    if not (ROOT / 'audio' / rel).exists():
        errors.append(f'audio/{rel} is missing (run tools/assetgen/build_audio.py)')

# ---------------------------------------------------------------- textures & shaders
tex = ROOT / 'assets' / 'textures'
mat_src = (ROOT / 'visuals' / 'material_library.gd').read_text()
textured = re.findall(r'"([a-z_]+)":\s*\["([a-z_]+)",\s*Color', mat_src)
if not textured:
    errors.append('visuals/material_library.gd: could not find the TEXTURED table')
for key, base in textured:
    for suffix in ('_albedo.jpg', '_normal.jpg', '_orm.png'):
        if not (tex / (base + suffix)).exists():
            errors.append(f'assets/textures/{base}{suffix} is missing (material "{key}")')
for extra in ('leaves.png', 'grass_tufts.png', 'flowers.png', 'water_normal.jpg', 'detail_normal.jpg'):
    if not (tex / extra).exists():
        errors.append(f'assets/textures/{extra} is missing')
for shader in ('sky', 'terrain', 'foliage', 'grass', 'water', 'avatar'):
    path = ROOT / 'visuals' / 'shaders' / f'{shader}.gdshader'
    if not path.exists():
        errors.append(f'{path.relative_to(ROOT)} is missing')
        continue
    code = re.sub(r'//.*', '', path.read_text())
    if code.count('{') != code.count('}') or code.count('(') != code.count(')'):
        errors.append(f'{path.relative_to(ROOT)}: unbalanced braces/parentheses')
    if not re.match(r'\s*shader_type\s+(spatial|sky)\s*;', code):
        errors.append(f'{path.relative_to(ROOT)}: must start with shader_type')

if errors:
    print('ASSET AUDIT FAILED')
    for e in errors:
        print(' -', e)
    sys.exit(1)
print(f'ASSET AUDIT PASSED  models={len(models)} textures={len(list(tex.iterdir()))} shaders=6')
