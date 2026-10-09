#!/usr/bin/env python3
"""Generate every texture in assets/textures/.   usage: python3 tools/assetgen/build_textures.py [--scale 1.0]"""
import os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
from texlib import save_pbr, height_to_normal, to8
from texgen import RECIPES, water_normal, detail_fine
from texsprites import leaf_atlas, grass_atlas, flower_atlas

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'textures')

def main():
    scale = 1.0
    if '--scale' in sys.argv: scale = float(sys.argv[sys.argv.index('--scale') + 1])
    os.makedirs(OUT, exist_ok=True); t0 = time.time()
    for old in os.listdir(OUT): os.remove(os.path.join(OUT, old))
    for name, (fn, size, strength) in RECIPES.items():
        n = max(128, int(size * scale) // 64 * 64)
        d = fn(n)
        save_pbr(OUT, name, d['albedo'], d['height'], d['rough'], d.get('ao'), d.get('metal'), strength)
        print(f'  {name:12s} {n}px')
    n = int(512 * scale) // 64 * 64
    w = water_normal(n); Image.fromarray(to8(height_to_normal(w['height'], 3.0))).save(os.path.join(OUT, 'water_normal.jpg'), quality=92, subsampling=0)
    f = detail_fine(256); Image.fromarray(to8(height_to_normal(f['height'], 2.0))).save(os.path.join(OUT, 'detail_normal.jpg'), quality=92, subsampling=0)
    leaf_atlas(int(512 * scale) // 64 * 64).save(os.path.join(OUT, 'leaves.png'), optimize=True)
    grass_atlas(256).save(os.path.join(OUT, 'grass_tufts.png'), optimize=True)
    flower_atlas(256).save(os.path.join(OUT, 'flowers.png'), optimize=True)
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f'textures done in {time.time()-t0:.1f}s, {len(os.listdir(OUT))} files, {total/1e6:.1f} MB')

if __name__ == '__main__': main()
