#!/usr/bin/env python3
"""Offline composition check: lays the generated models out exactly like world/village_art.gd and renders overview images
(software renderer - NOT engine screenshots).  usage: python3 tools/assetgen/preview_scene.py out_dir"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
from meshkit import *
import buildings as Bd, props_veg as V, props_small as S, accessories as A, animals as An, avatar as Av
from gltf import Node
from preview import render, flatten
from matdefs import preview_assets

def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def height(x, z):
    h = 0.0
    ins = np.minimum(np.minimum(x + 48, -6 - x), np.minimum(z + 23, -13 - z))
    h = h - 0.55 * smooth(0, 3.5, np.maximum(ins, 0)) * (ins > 0)
    insr = np.minimum(np.minimum(x + 52, -22 - x), np.minimum(z + 33, -27 - z))
    h = h - 2.0 * smooth(0, 3.2, np.maximum(insr, 0)) * (insr > 0)
    return h

def place(node, pos, yaw=0.0, scale=1.0):
    return [g.xf(Tm(*pos) @ Ry(yaw) @ Sm(scale)) for g in flatten(node)]

def build():
    geos = []
    ground = grid_surface(height, 40, 40, -60, 60, -60, 60, 'grass', uvs=0.5); ground.C[:] = 1; geos.append(ground)
    water = grid_surface(lambda x, z: np.full_like(x, -0.12), 2, 2, -48, -6, -23, -13, 'water'); geos.append(water)
    L = [('house_cottage', Bd.house_cottage(), (0, 0, 7), 180), ('market_hall', Bd.market_hall(), (-10, 0, -5), -90), ('garden_bed', Bd.garden_bed(), (11, 0, -10), 0),
         ('workshop_shed', Bd.workshop_shed(), (18, 0, 8), 90), ('community_hall', Bd.community_hall(), (0, 0, -14), 180), ('storage_hut', Bd.storage_hut(), (-14, 0, 10), -90),
         ('bridge_broken', Bd.bridge_wood(True), (-22, 0, -18), 0), ('bridge_broken2', Bd.bridge_wood(True), (-36, 0, -30), 0), ('boat', Bd.boat(True), (-31, -0.2, -16), 25),
         ('dock', Bd.dock_pier(), (-9, -0.36, -25), 0), ('gate', Bd.gate_old(), (32, 0, 18), 90), ('beacon', Bd.beacon_tower(), (32, 0, -36), 0), ('cave', Bd.cave_mouth(), (22, 0, -27), 0),
         ('scarecrow', Bd.scarecrow(), (-24.4, 0, 8.8), 20), ('well', S.well(), (6.5, 0, 3.5), 0), ('bench', S.bench(), (-4.6, 0, 3), 90), ('bench2', S.bench(), (4.6, 0, -8), -90),
         ('stall', S.stall_small(), (-6, 0, 11), 90), ('hay', S.haystack(1), (-26.5, 0, 17.5), 30), ('hay2', S.haystack(2), (-12.5, 0, 17), -20), ('ladder', Bd.ladder(), (9, 0, -6), 0)]
    for name, node, pos, yaw in L: geos += place(node, pos, yaw)
    for p in [(2.7, 12.5), (-2.7, 12.5), (2.7, 2.5), (-2.7, 2.5), (2.7, -6.5), (-2.7, -6.5)]: geos += place(S.lamp_post(), (p[0], 0, p[1]))
    for p, yaw in [((16, 5), -40), ((-16, -15.5), 35), ((-19, 6.5), 60)]: geos += place(S.signpost(), (p[0], 0, p[1]), yaw)
    # fruit trees on the garden platform
    spots = [(-3.6, -1.8), (-1.8, -1.8), (1.8, -1.8), (3.6, -1.8), (-3.6, 0.3), (-1.8, 0.3), (1.8, 0.3), (3.6, 0.3), (-2.7, 2.3), (2.7, 2.3)]
    for i, (sx, sz) in enumerate(spots): geos += place(V.tree_fruit(51 + (i % 3) * 4), (11 + sx, 0.5, -10 + sz), i * 70)
    # scattered scenery
    r = np.random.default_rng(3); placed = 0
    avoid = [(0, 7, 6), (-10, -5, 6), (11, -10, 7), (18, 8, 6), (0, -14, 7), (-14, 10, 5), (-27, -18, 24), (-9, -25, 5), (32, -36, 6), (22, -27, 8), (-20, 12, 8), (0, 0, 3.5), (-36, -30, 14), (32, 18, 5)]
    while placed < 22:
        a = r.uniform(0, 6.28); rad = r.uniform(26, 46); x, z = np.cos(a) * rad, np.sin(a) * rad
        if any(abs(x - ax) < w and abs(z - az) < w for ax, az, w in avoid): continue
        node = [V.tree_broad(11), V.tree_broad(18, H=7.2, crown=3.1), V.tree_pine(31)][r.integers(0, 3)]
        geos += place(node, (x, 0, z), r.uniform(0, 360)); placed += 1
    for i in range(10):
        a = r.uniform(0, 6.28); rad = r.uniform(8, 40); x, z = np.cos(a) * rad, np.sin(a) * rad
        if any(abs(x - ax) < w and abs(z - az) < w for ax, az, w in avoid): continue
        geos += place(V.bush(70 + i), (x, 0, z), r.uniform(0, 360))
    # characters: the player at the spawn point and a farmer NPC
    for gender, pos, yaw, style in (('male', (0, 0, 10), 0, 'explorer'), ('female', (-4, 0, -2), 90, 'gardener')):
        root, gg, hair, eyes, J = Av.build(gender, lod=1.6)
        pal = dict(Av.PALETTE)
        if style == 'gardener': pal.update(shirt=(0.30, 0.52, 0.30), pants=(0.52, 0.45, 0.32), hair=(0.30, 0.17, 0.08))
        for g in flatten(root):
            g2 = Av.bake_preview(g, pal); geos.append(g2.xf(Tm(*pos) @ Ry(yaw)))
        if style == 'explorer':
            for g in flatten(Node('pack', [], t=(0, 1.30, 0.115), children=[A.backpack()])): geos.append(g.xf(Tm(*pos) @ Ry(yaw)))
    # animals
    for node, pos, yaw in ((An.build_quad('cow', 1), (-18, 0, 20), 40), (An.build_quad('goat', 2), (-8, 0, 16), -30), (An.build_quad('deer', 3), (24, 0, 28), 100), (An.build_chicken(4), (-3, 0, 15), 60)):
        geos += place(node, pos, yaw)
    # path ribbons
    p = box((3.2, 0.03, 34), 'dirt', uvs=0.5, center=(0, 0.02, -3)); geos.append(p)
    return geos

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else '.'; os.makedirs(out, exist_ok=True)
    cols, tex = preview_assets(); cols.update({'water': (0.10, 0.42, 0.50), 'preview': (1, 1, 1), 'animal_hide': (1, 1, 1), 'ore_crystal': (0.35, 0.6, 0.95), 'avatar_hair': (0.2, 0.12, 0.07), 'avatar_eye': (1, 1, 1)})
    geos = build(); print('tris', sum(len(g.T) for g in geos))
    views = {'spawn_view': dict(eye_pos=(0.0, 2.9, 17.5), target=(0.0, 1.8, 0.0), fov=62), 'market_view': dict(eye_pos=(-1.5, 2.6, 0.5), target=(-10.0, 1.8, -5.0), fov=62),
             'river_view': dict(eye_pos=(-12.0, 3.0, -4.0), target=(-26.0, 0.5, -18.0), fov=70), 'overview': dict(eye_pos=(0.0, 70.0, 62.0), target=(0.0, 0.0, -8.0), fov=44)}
    for name, v in views.items():
        im = render(geos, cols, tex, size=(760, 460), az=0, el=0, fov=v['fov'], eye_pos=v['eye_pos'], target=v['target'], bg=(0.60, 0.76, 0.93))
        im.save(os.path.join(out, name + '.png')); print('saved', name)

if __name__ == '__main__': main()
