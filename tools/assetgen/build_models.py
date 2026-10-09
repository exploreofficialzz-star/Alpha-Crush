#!/usr/bin/env python3
"""Generate every model in assets/models/*.glb.   usage: python3 tools/assetgen/build_models.py [only_name ...]"""
import os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
from gltf import write_glb, validate_glb, Node
from matdefs import gltf_materials
import props_veg as V, buildings as Bd, props_small as S, accessories as A, animals as An, avatar as Av

ROOT = os.path.abspath(os.path.join(HERE, '..', '..')); OUT = os.path.join(ROOT, 'assets', 'models')

def avatar_node(gender):
    root, geos, hair, eyes, J = Av.build(gender, lod=1.0)
    return root

def models():
    m = {}
    for i in range(3): m[f'tree_oak_{i}'] = (lambda i=i: V.tree_broad(11 + i * 7, H=6.4 + i * 0.8, crown=2.8 + i * 0.3, clumps=5 + i, density=1.35))
    for i in range(2): m[f'tree_pine_{i}'] = (lambda i=i: V.tree_pine(31 + i * 5, H=8.5 + i * 2.0))
    for i in range(3): m[f'tree_fruit_{i}'] = (lambda i=i: V.tree_fruit(51 + i * 4))
    for i in range(2): m[f'bush_{i}'] = (lambda i=i: V.bush(71 + i * 3, size=1.0 + 0.3 * i))
    for i, (sd, r, sq) in enumerate(((3, 0.9, 0.7), (7, 1.5, 0.6), (11, 0.55, 0.75), (13, 2.4, 0.8))): m[f'rock_{i}'] = (lambda sd=sd, r=r, sq=sq: V.rock_prop(sd, r, sq))
    m['mountains'] = lambda: V.mountains()
    m.update({'house_cottage': Bd.house_cottage, 'market_hall': Bd.market_hall, 'workshop_shed': Bd.workshop_shed, 'community_hall': Bd.community_hall,
              'storage_hut': Bd.storage_hut, 'beacon_tower': Bd.beacon_tower, 'garden_bed': Bd.garden_bed, 'ladder': Bd.ladder, 'dock_pier': Bd.dock_pier,
              'bridge_wood': lambda: Bd.bridge_wood(False), 'bridge_broken': lambda: Bd.bridge_wood(True), 'boat_sound': lambda: Bd.boat(False), 'boat_damaged': lambda: Bd.boat(True),
              'gate_old': Bd.gate_old, 'cave_mouth': Bd.cave_mouth, 'scarecrow': Bd.scarecrow})
    m.update({'lamp_post': S.lamp_post, 'signpost': S.signpost, 'fence_segment': S.fence_segment, 'bench': S.bench, 'well': S.well, 'haystack': S.haystack, 'crop_wheat': S.crop_wheat,
              'res_apple': S.res_apple, 'res_orange': S.res_orange, 'res_mango': S.res_mango, 'res_wood': S.res_wood, 'res_stone': S.res_stone, 'res_ore': S.res_ore,
              'letter_gem': S.letter_gem, 'stall_small': S.stall_small})
    m.update({'hat_straw': A.hat_straw, 'hat_hard': A.hat_hard, 'hat_sun': A.hat_sun, 'backpack': A.backpack})
    m.update({'animal_cow': lambda: An.build_quad('cow', 1), 'animal_goat': lambda: An.build_quad('goat', 2), 'animal_deer': lambda: An.build_quad('deer', 3), 'animal_chicken': lambda: An.build_chicken(4)})
    m.update({'avatar_male': lambda: avatar_node('male'), 'avatar_female': lambda: avatar_node('female')})
    return m

def main():
    only = [a for a in sys.argv[1:] if not a.startswith('--')]
    os.makedirs(OUT, exist_ok=True); mats = gltf_materials()
    mats.update({'animal_hide': {'color': (1, 1, 1, 1)}, 'ore_crystal': {'color': (0.35, 0.6, 0.95, 1)}, 'avatar_body': {'color': (1, 1, 1, 1)}})
    t0 = time.time(); total = 0; rows = []
    for name, fn in models().items():
        if only and name not in only: continue
        t = time.time(); node = fn(); path = os.path.join(OUT, name + '.glb'); write_glb(path, node, mats)
        info = validate_glb(path); total += os.path.getsize(path)
        rows.append((name, info['tris'], os.path.getsize(path) // 1024, info['problems']))
        print(f"  {name:18s} {info['tris']:6d} tris {os.path.getsize(path)//1024:5d} KB  {'OK' if not info['problems'] else info['problems']}  ({time.time()-t:.1f}s)")
    bad = [r for r in rows if r[3]]
    print(f'{len(rows)} models, {total/1e6:.1f} MB, {time.time()-t0:.0f}s, problems: {len(bad)}')
    sys.exit(1 if bad else 0)

if __name__ == '__main__': main()
