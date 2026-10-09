"""Buildings & large landmarks. Local origin = ground centre, front faces -Z. COL_* child nodes describe collision."""
import numpy as np
from meshkit import *
from gltf import Node
from kit import *
from matdefs import U

def _col_box(sx, sy, sz, x=0, y=0, z=0): return Node(f'COL_BOX_{round(sx*100)}_{round(sy*100)}_{round(sz*100)}', t=(x, y, z))

def house_cottage():
    W, D, Hh = 5.2, 4.2, 2.6; y0 = 0.4; g = []
    g.append(B((W + 0.16, 0.42, D + 0.16), 'cobble', center=(0, 0.21, 0), r=0.04))
    g.append(B((W, Hh, D), 'plaster', center=(0, y0 + Hh / 2, 0)))
    ytop = y0 + Hh
    for sx in (-1, 1):
        for sz in (-1, 1): g.append(beam((sx * W / 2, y0, sz * D / 2), (sx * W / 2, ytop, sz * D / 2), 0.2, 0.2, 'wood_planks', r=0.02))
    for yy in (y0 + 0.08, ytop - 0.22, y0 + Hh * 0.52):
        g.append(beam((-W / 2, yy, -D / 2 - 0.03), (W / 2, yy, -D / 2 - 0.03), 0.14, 0.12, 'wood_planks')); g.append(beam((-W / 2, yy, D / 2 + 0.03), (W / 2, yy, D / 2 + 0.03), 0.14, 0.12, 'wood_planks'))
        g.append(beam((-W / 2 - 0.03, yy, -D / 2), (-W / 2 - 0.03, yy, D / 2), 0.12, 0.14, 'wood_planks')); g.append(beam((W / 2 + 0.03, yy, -D / 2), (W / 2 + 0.03, yy, D / 2), 0.12, 0.14, 'wood_planks'))
    for x in (-1.9, 0.0, 1.9):  # vertical studs on the front, between the beams
        g.append(beam((x, y0, -D / 2 - 0.03), (x, ytop, -D / 2 - 0.03), 0.12, 0.1, 'wood_planks'))
    roof = gable_roof(W, D, 1.7, 0.4, 0.55, 0.13, y0=ytop)
    g += roof
    for sx in (-1, 1): g += gable_end(D, 1.7, 'plaster', sx * W / 2, y0=ytop)
    g.append(B((0.78, 2.9, 0.78), 'brick', center=(1.55, y0 + 1.9, 0.5), r=0.02)); g.append(B((0.95, 0.2, 0.95), 'brick', center=(1.55, y0 + 3.35, 0.5), r=0.03))
    g += door(1.0, 2.0, (-1.05, y0 + 1.05, -D / 2 - 0.02), facing=-1)
    g.append(B((1.7, 0.2, 0.9), 'cobble', center=(-1.05, 0.08, -D / 2 - 0.5), r=0.04))
    g += lantern((-1.95, y0 + 1.95, -D / 2 - 0.14))
    g += window(1.0, 1.05, (1.1, y0 + 1.35, -D / 2 - 0.02), facing=-1)
    g += window(0.9, 1.0, (-W / 2 - 0.02, y0 + 1.35, -0.4), facing=-1, axis='x')
    g += window(0.9, 1.0, (W / 2 + 0.02, y0 + 1.35, -0.9), facing=1, axis='x')
    g += window(1.0, 1.0, (-1.2, y0 + 1.35, D / 2 + 0.02), facing=1)
    return Node('House', g, children=[_col_box(W + 0.2, 4.0, D + 0.2, 0, 2.0, 0)])

def market_hall():
    W, D = 6.0, 4.0; g = []
    g.append(B((W + 0.2, 0.3, D + 0.2), 'cobble', center=(0, 0.15, 0), r=0.03))
    # back & side walls (open front)
    g.append(B((W, 2.7, 0.22), 'plaster', center=(0, 0.3 + 1.35, D / 2 - 0.11)))
    for sx in (-1, 1): g.append(B((0.22, 2.7, D), 'plaster', center=(sx * (W / 2 - 0.11), 0.3 + 1.35, 0)))
    for sx in (-1, 1):
        g.append(beam((sx * (W / 2 - 0.1), 0.3, -D / 2 + 0.1), (sx * (W / 2 - 0.1), 3.1, -D / 2 + 0.1), 0.24, 0.24, 'wood_planks', r=0.02))
    g.append(beam((-W / 2, 2.78, -D / 2 + 0.1), (W / 2, 2.78, -D / 2 + 0.1), 0.26, 0.22, 'wood_planks'))
    # shed roof (single slope), front low
    roof = gable_roof(W, D, 1.3, 0.35, 0.6, 0.12, y0=3.0)
    g += roof; g.append(B((W, 1.3, 0.2), 'plaster', center=(0, 3.0 + 0.4, 0.0), r=0.0)) if False else None
    for sx in (-1, 1): g += gable_end(D, 1.3, 'plaster', sx * (W / 2 - 0.0), y0=3.0)
    # counter + awning
    g.append(B((W - 0.6, 1.0, 0.7), 'wood_planks', center=(0, 0.3 + 0.5, -D / 2 + 0.9), r=0.02)); g.append(B((W - 0.4, 0.08, 0.9), 'wood_planks', center=(0, 1.34, -D / 2 + 0.9), r=0.02))
    P = [(-W / 2 + 0.1, 3.0, -D / 2 + 0.1), (W / 2 - 0.1, 3.0, -D / 2 + 0.1), (W / 2 - 0.1, 2.35, -D / 2 - 1.5), (-W / 2 + 0.1, 2.35, -D / 2 - 1.5)]
    g += slab(P[::-1][::1], 0.04, 'awning', 'awning', lambda p: ((p[0] + 3) * U('awning'), np.linalg.norm(p - np.array((p[0], 3.0, -D / 2 + 0.1))) * U('awning'))) if False else []
    aw = slab([P[3], P[2], P[1], P[0]], 0.04, 'awning', 'awning', lambda p: ((p[0] + W / 2) * U('awning'), (p[2] + D / 2 - 0.1) * -U('awning')))
    g += aw
    for sx in (-1, 1): g.append(beam((sx * (W / 2 - 0.2), 0.3, -D / 2 - 1.4), (sx * (W / 2 - 0.2), 2.4, -D / 2 - 1.4), 0.1, 0.1, 'wood_planks', r=0.02))
    # goods
    g += barrel(0.32, 0.8, (-W / 2 + 0.7, 0.3, -D / 2 - 0.6)) + crate(0.7, (W / 2 - 0.8, 0.3, -D / 2 - 0.6), 15) + crate(0.55, (W / 2 - 0.9, 1.0, -D / 2 - 0.6), -10)
    g += basket(0.3, 0.26, (-1.2, 1.38, -D / 2 + 0.9)) + basket(0.28, 0.24, (0.6, 1.38, -D / 2 + 0.9)) + sack(0.28, (1.6, 1.38, -D / 2 + 0.9))
    g += lantern((-W / 2 + 0.6, 2.0, -D / 2 - 1.3)); g += lantern((W / 2 - 0.6, 2.0, -D / 2 - 1.3))
    g.append(B((2.2, 0.55, 0.08), 'wood_planks', center=(0, 2.7, -D / 2 - 0.02), r=0.015))
    return Node('Market', g, children=[_col_box(W + 0.2, 3.0, D + 0.2, 0, 1.5, 0)])

def workshop_shed():
    W, D = 5.0, 4.0; g = []
    g.append(B((W + 0.2, 0.3, D + 0.2), 'cobble', center=(0, 0.15, 0), r=0.03))
    g.append(B((W, 2.6, 0.2), 'wood_planks', center=(0, 0.3 + 1.3, D / 2 - 0.1)))
    for sx in (-1, 1): g.append(swap_uv(B((0.2, 2.6, D), 'wood_planks', center=(sx * (W / 2 - 0.1), 0.3 + 1.3, 0))))
    for sx in (-1, 1): g.append(beam((sx * (W / 2 - 0.1), 0.3, -D / 2 + 0.1), (sx * (W / 2 - 0.1), 2.95, -D / 2 + 0.1), 0.26, 0.26, 'wood_planks', r=0.02))
    g.append(beam((-W / 2, 2.72, -D / 2 + 0.1), (W / 2, 2.72, -D / 2 + 0.1), 0.28, 0.24, 'wood_planks'))
    g += gable_roof(W, D, 1.5, 0.35, 0.5, 0.12, y0=2.95)
    for sx in (-1, 1): g += gable_end(D, 1.5, 'wood_planks', sx * W / 2, y0=2.95)
    g.append(B((1.0, 3.4, 1.0), 'rock', center=(W / 2 - 0.9, 1.7, D / 2 - 0.9), r=0.05)); g.append(B((1.2, 0.2, 1.2), 'rock', center=(W / 2 - 0.9, 3.45, D / 2 - 0.9), r=0.04))
    g.append(B((2.4, 0.9, 0.8), 'wood_planks', center=(-0.9, 0.3 + 0.45, D / 2 - 0.7), r=0.03)); g.append(B((2.5, 0.08, 0.9), 'wood_planks', center=(-0.9, 1.26, D / 2 - 0.7), r=0.02))
    for dx in (-1.0, 1.0): g.append(beam((-0.9 + dx * 1.1, 0.3, D / 2 - 0.7), (-0.9 + dx * 1.1, 1.22, D / 2 - 0.7), 0.1, 0.1, 'wood_planks'))
    # anvil + tools
    g.append(B((0.5, 0.35, 0.28), 'iron', center=(1.2, 0.3 + 0.62, 0.2), r=0.03)); g.append(cylinder(0.18, 0.18, 0.45, 'wood_planks', seg=10, y0=0.3).xf(Tm(1.2, 0, 0.2)))
    for i in range(4): g.append(beam((-2.0 + i * 0.35, 1.6 + 0.12 * (i % 2), D / 2 - 0.22), (-2.0 + i * 0.35 + 0.05, 2.4, D / 2 - 0.22), 0.05, 0.05, 'iron'))
    g.append(B((1.6, 0.14, 0.3), 'wood_planks', center=(-0.7, 2.5, D / 2 - 0.25), r=0.02))
    g += barrel(0.3, 0.75, (-W / 2 + 0.6, 0.3, 0.2)) + crate(0.6, (-W / 2 + 0.6, 0.3, -0.7), 20) + lantern((0, 2.55, -D / 2 + 0.2))
    return Node('Workshop', g, children=[_col_box(W + 0.2, 3.0, D + 0.2, 0, 1.5, 0)])

def community_hall():
    W, D = 7.0, 5.0; g = []; y0 = 0.5
    g.append(B((W + 0.3, y0, D + 0.3), 'rock', center=(0, y0 / 2, 0), r=0.05))
    g.append(B((W, 2.6, D), 'plaster', center=(0, y0 + 1.3, 0)))
    g.append(B((W + 0.08, 0.9, D + 0.08), 'brick', center=(0, y0 + 0.45, 0), r=0.02))
    ytop = y0 + 2.6
    for sx in (-1, 1):
        for sz in (-1, 1): g.append(beam((sx * W / 2, y0, sz * D / 2), (sx * W / 2, ytop, sz * D / 2), 0.26, 0.26, 'wood_planks', r=0.02))
    for x in (-2.2, 2.2): g.append(beam((x, y0 + 0.9, -D / 2 - 0.03), (x, ytop, -D / 2 - 0.03), 0.18, 0.12, 'wood_planks'))
    g.append(beam((-W / 2, ytop - 0.24, -D / 2 - 0.04), (W / 2, ytop - 0.24, -D / 2 - 0.04), 0.2, 0.16, 'wood_planks'))
    g += gable_roof(W, D, 2.0, 0.45, 0.6, 0.14, y0=ytop)
    for sx in (-1, 1): g += gable_end(D, 2.0, 'plaster', sx * W / 2, y0=ytop)
    # belfry
    g.append(B((1.1, 0.9, 1.1), 'wood_planks', center=(0, ytop + 2.0 + 0.4, 0), r=0.03))
    g += gable_roof(1.1, 1.1, 0.8, 0.2, 0.2, 0.08, y0=ytop + 3.0)
    g.append(cylinder(0.18, 0.12, 0.3, 'iron', seg=10, y0=ytop + 2.25))
    # doors, steps, windows
    g += door(1.9, 2.1, (0, y0 + 1.1, -D / 2 - 0.02), facing=-1)
    g.append(B((2.8, 0.18, 0.9), 'rock', center=(0, 0.09 + 0.0, -D / 2 - 0.75), r=0.04)); g.append(B((2.4, 0.18, 0.55), 'rock', center=(0, 0.27, -D / 2 - 0.55), r=0.04))
    for x in (-2.4, 2.4): g += window(1.0, 1.3, (x, y0 + 1.5, -D / 2 - 0.02), facing=-1)
    for z in (-1.0, 1.0): g += window(0.9, 1.2, (-W / 2 - 0.02, y0 + 1.5, z), facing=-1, axis='x'); g += window(0.9, 1.2, (W / 2 + 0.02, y0 + 1.5, z), facing=1, axis='x')
    for x in (-1.5, 1.5): g += lantern((x, y0 + 2.0, -D / 2 - 0.12), 1.2)
    for x, c in ((-3.1, 'paint_blue'), (3.1, 'paint_red')):
        g.append(B((0.55, 1.5, 0.03), c, center=(x, y0 + 1.7, -D / 2 - 0.12)))
    return Node('CommunityHall', g, children=[_col_box(W + 0.3, 4.0, D + 0.3, 0, 2.0, 0)])

def storage_hut():
    W, D = 3.2, 3.2; g = []
    g.append(B((W + 0.14, 0.3, D + 0.14), 'rock', center=(0, 0.15, 0), r=0.03))
    g.append(B((W, 2.3, D), 'wood_planks', center=(0, 0.3 + 1.15, 0), r=0.01))
    for sx in (-1, 1):
        for sz in (-1, 1): g.append(beam((sx * W / 2, 0.3, sz * D / 2), (sx * W / 2, 2.6, sz * D / 2), 0.16, 0.16, 'wood_planks', r=0.015))
    g += gable_roof(W, D, 1.2, 0.3, 0.45, 0.1, y0=2.6)
    for sx in (-1, 1): g += gable_end(D, 1.2, 'wood_planks', sx * W / 2, y0=2.6)
    g += door(1.2, 1.9, (0, 0.3 + 0.97, -D / 2 - 0.02), facing=-1)
    g.append(B((0.22, 0.26, 0.1), 'iron', center=(0.4, 1.3, -D / 2 - 0.1), r=0.03))
    g += window(0.6, 0.6, (W / 2 + 0.02, 1.7, 0.2), facing=1, axis='x', shutters=False)
    g += crate(0.6, (1.5, 0.0, -D / 2 - 0.5), 12) + barrel(0.28, 0.7, (-1.5, 0, -D / 2 - 0.45))
    return Node('Storage', g, children=[_col_box(W + 0.2, 3.0, D + 0.2, 0, 1.5, 0)])

def beacon_tower():
    g = []; R0, R1, Hh = 1.9, 1.2, 8.0
    g.append(cylinder(R0 + 0.35, R0 + 0.15, 0.6, 'rock', seg=24, y0=0))
    g.append(cylinder(R0, R1, Hh, 'brick', seg=24, y0=0.6, uvs=U('brick')))
    for y in (2.8, 5.0): g.append(cylinder(R0 - (R0 - R1) * (y - 0.6) / Hh + 0.04, R0 - (R0 - R1) * (y - 0.6) / Hh + 0.04, 0.5, 'paint_white', seg=24, y0=y, caps=(False, False)))
    g.append(cylinder(R1 + 0.7, R1 + 0.7, 0.18, 'iron', seg=24, y0=Hh + 0.6))
    for k in range(12):
        a = k / 12 * 6.283; g.append(beam((np.cos(a) * (R1 + 0.66), Hh + 0.78, np.sin(a) * (R1 + 0.66)), (np.cos(a) * (R1 + 0.66), Hh + 1.7, np.sin(a) * (R1 + 0.66)), 0.05, 0.05, 'iron'))
    g.append(cylinder(R1 + 0.68, R1 + 0.68, 0.05, 'iron', seg=24, y0=Hh + 1.68, caps=(False, False)))
    g.append(cylinder(0.78, 0.78, 1.5, 'glass_window', seg=16, y0=Hh + 0.78, caps=(False, False)))
    lamp = cylinder(0.32, 0.32, 0.8, 'beacon_glow', seg=12, y0=Hh + 1.1)
    g.append(lamp)
    for k in range(6):
        a = k / 6 * 6.283; g.append(beam((np.cos(a) * 0.78, Hh + 0.78, np.sin(a) * 0.78), (np.cos(a) * 0.78, Hh + 2.28, np.sin(a) * 0.78), 0.06, 0.06, 'iron'))
    g.append(cone := cylinder(1.05, 0.05, 0.9, 'roof_tiles', seg=16, y0=Hh + 2.28, uvs=U('roof_tiles')))
    g.append(B((0.9, 1.9, 0.12), 'wood_planks', center=(0, 1.55, -R0 + 0.05)))
    return Node('Beacon', g, children=[Node('COL_CYL_220_950_0')])

def garden_bed():
    W, D, H = 9.0, 7.0, 0.5; g = []; cols = [_col_box(W, H, D, 0, H / 2, 0)]
    t = 0.35
    g.append(B((W, H, t), 'rock', center=(0, H / 2, -D / 2 + t / 2), r=0.05)); g.append(B((W, H, t), 'rock', center=(0, H / 2, D / 2 - t / 2), r=0.05))
    g.append(B((t, H, D - 2 * t), 'rock', center=(-W / 2 + t / 2, H / 2, 0), r=0.05)); g.append(B((t, H, D - 2 * t), 'rock', center=(W / 2 - t / 2, H / 2, 0), r=0.05))
    g.append(B((W - 2 * t, 0.06, D - 2 * t), 'grass', center=(0, H - 0.1, 0)))
    for k, (x, z, w, d) in enumerate(((0.0, -2.7, 2.4, 0.9), (-3.9, 0.8, 0.9, 2.2), (3.9, 0.8, 0.9, 2.2))):   # flower beds out of the tree rows
        g.append(B((w, 0.14, d), 'dirt', center=(x, H - 0.03, z), r=0.05)); g.append(B((w + 0.1, 0.1, d + 0.1), 'wood_planks', center=(x, H - 0.1, z), r=0.0))
    for z in (-D / 2 + 0.1, D / 2 - 0.1):
        for x in (-1.2, 1.2): g.append(beam((x, H, z), (x, H + 2.1, z), 0.1, 0.1, 'wood_planks', r=0.015))
        g.append(tube(np.array([(-1.2, H + 2.1, z), (-0.6, H + 2.5, z), (0.0, H + 2.65, z), (0.6, H + 2.5, z), (1.2, H + 2.1, z)]), [0.045] * 5, 'wood_planks', seg=6, uvs=2.0))
    # entrance steps on the south (+Z) side, in front of the locked gate; every riser <= 10 cm so the player can walk up
    for k in range(4):
        top = 0.4 - 0.1 * k; z = D / 2 + 0.2 + 0.4 * k
        g.append(B((2.6, top, 0.4), 'rock', center=(0, top / 2, z), r=0.0))
        cols.append(Node(f'COL_BOX_260_{round(top*100)}_40_{k}', t=(0, top / 2, z)))
    return Node('GardenBed', g, children=cols)

def ladder(h=1.7):
    g = []
    for x in (-0.28, 0.28): g.append(beam((x, 0, 0.1), (x, h + 0.35, -0.08), 0.07, 0.07, 'wood_planks', r=0.01))
    for i in range(7): y = 0.2 + i * (h - 0.05) / 6; g.append(beam((-0.28, y, 0.1 - 0.17 * y / h), (0.28, y, 0.1 - 0.17 * y / h), 0.05, 0.05, 'wood_planks', r=0.008))
    return Node('Ladder', g)

def dock_pier():
    g = []; L = 7.0; Wd = 2.2
    for i in range(int(L / 0.25)):
        z = -L / 2 + 0.125 + i * 0.25; g.append(B((Wd, 0.09, 0.23), 'wood_planks', center=(0, 0.42 + (i % 3) * 0.003, z)))
    for sx in (-1, 1): g.append(beam((sx * (Wd / 2 - 0.1), 0.28, -L / 2), (sx * (Wd / 2 - 0.1), 0.28, L / 2), 0.16, 0.2, 'wood_planks'))
    for z in np.linspace(-L / 2 + 0.3, L / 2 - 0.3, 4):
        for sx in (-1, 1): g.append(beam((sx * (Wd / 2 + 0.02), -0.8, z), (sx * (Wd / 2 + 0.02), 1.05, z), 0.2, 0.2, 'wood_planks', r=0.03))
    g.append(tube(np.array([(-Wd / 2 - 0.02, 1.0, -L / 2 + 0.3), (-Wd / 2 - 0.02, 0.8, 0), (-Wd / 2 - 0.02, 1.0, L / 2 - 0.3)]), [0.03] * 3, 'rope', seg=6))
    g += barrel(0.3, 0.7, (0.6, 0.46, L / 2 - 0.7)) + crate(0.55, (-0.6, 0.46, L / 2 - 0.8), 20) + lantern((Wd / 2 + 0.02, 1.05, -L / 2 + 0.3), 1.1)
    return Node('Dock', g, children=[_col_box(Wd, 0.5, L, 0, 0.25, 0)])

def bridge_wood(broken=False, L=10.5):
    """footbridge across the 10 m river; gently arched, deck ends are ~10 cm above the banks so the player can walk on.
    Stepped COL_BOX markers follow the arch (the physics engine cannot use rotated boxes here)."""
    g = []; Wd = 2.6; base = 0.10; rise = 0.20
    arch = lambda z: base + rise * (1 - (z / (L / 2)) ** 2)
    n = int(L / 0.3)
    for i in range(n):
        z = -L / 2 + 0.15 + i * (L / n)
        if broken and int(n * 0.30) <= i <= int(n * 0.62) and i % 2 == 1: continue
        g.append(B((Wd, 0.1, L / n * 0.9), 'wood_planks', center=(0, arch(z), z)))
    for sx in (-1, 1):
        zs = np.linspace(-L / 2, L / 2, 11)
        g.append(tube(np.array([(sx * Wd / 2, arch(z) - 0.12, z) for z in zs]), [0.11] * 11, 'wood_planks', seg=8, uvs=U('wood_planks')))
        for z in np.linspace(-L / 2 + 0.25, L / 2 - 0.25, 7):
            g.append(beam((sx * Wd / 2, arch(z) - 0.05, z), (sx * Wd / 2, arch(z) + 0.95, z), 0.1, 0.1, 'wood_planks', r=0.01))
        top = np.array([(sx * Wd / 2, arch(z) + 0.92, z) for z in zs])
        if broken: top = top[:6]
        g.append(tube(top, [0.05] * len(top), 'wood_planks', seg=6, uvs=U('wood_planks')))
        g.append(tube(top - (0, 0.4, 0), [0.04] * len(top), 'wood_planks', seg=6, uvs=U('wood_planks')))
    for z in (-L / 2 + 0.2, L / 2 - 0.2):
        for sx in (-1, 1): g.append(B((0.55, 0.9, 0.55), 'rock', center=(sx * (Wd / 2 + 0.3), -0.2, z), r=0.1))
    cols = []
    if not broken:
        segs = 7
        for k in range(segs):
            zc = -L / 2 + (k + 0.5) * L / segs; top_y = arch(zc) + 0.05; h = top_y + 0.3
            cols.append(Node(f'COL_BOX_{round(Wd*100)}_{round(h*100)}_{round(L/segs*100+8)}_{k}', t=(0, (top_y - 0.3) / 2, zc)))
    return Node('Bridge', g, children=cols)

def boat(damaged=False):
    g = []; L = 3.6; Wd = 1.35
    def hull_fn(t):   # t in [-1,1] along length -> (half width, keel height, gunwale height)
        w = Wd / 2 * (1 - abs(t) ** 2.2) ** 0.7; return w
    stations = np.linspace(-1, 1, 15)
    ring_pts = []; planks = 7
    for t in stations:
        w = hull_fn(t); yb = 0.1 + 0.18 * abs(t) ** 2 ; yt = 0.62 + 0.32 * abs(t) ** 2.4
        ring = []
        for a in np.linspace(0, np.pi, planks + 1):   # keel-left-over-gunwale-right (half-ellipse U-shape)
            ring.append((np.cos(a) * w, yb + (yt - yb) * (1 - np.sin(a) ** 0.8) + (0 if True else 0), t * L / 2))
        ring_pts.append(ring)
    R = np.array(ring_pts)   # stations x ring x 3
    P = R.reshape(-1, 3); n_r = R.shape[1]; T = []
    for i in range(len(stations) - 1):
        for j in range(n_r - 1):
            a = i * n_r + j; T += [(a, a + 1, a + n_r + 1), (a, a + n_r + 1, a + n_r)]
    N = smooth_normals(P, np.array(T)); UVs = np.stack([P[:, 2] * U('wood_planks') , -P[:, 1] * U('wood_planks') - np.abs(P[:, 0]) * 0.8], 1)
    if damaged:
        keep = [k for k, tri in enumerate(T) if not (7 <= (tri[0] // n_r) <= 9 and 1 <= (tri[0] % n_r) <= 2)]
        T = [T[k] for k in keep]
    hull = Geo(P, N, UVs, None, T, 'wood_planks', True); hull.N = -hull.N if False else hull.N
    g.append(hull)
    for z in (-0.9, 0.0, 0.9): g.append(B((Wd * 0.88, 0.07, 0.24), 'wood_planks', center=(0, 0.42, z), r=0.01))
    g.append(tube(np.array([(-Wd / 2 * 0.95, 0.66, -L / 2 * 0.75), (-Wd / 2 * 0.95, 0.68, 0), (-Wd / 2 * 0.95, 0.66, L / 2 * 0.75)]), [0.035] * 3, 'wood_planks', seg=6))
    g.append(tube(np.array([(Wd / 2 * 0.95, 0.66, -L / 2 * 0.75), (Wd / 2 * 0.95, 0.68, 0), (Wd / 2 * 0.95, 0.66, L / 2 * 0.75)]), [0.035] * 3, 'wood_planks', seg=6))
    if not damaged:
        for sx in (-1, 1):
            g.append(beam((sx * 0.45, 0.8, -0.1), (sx * 1.35, 0.55, 0.35), 0.05, 0.05, 'wood_planks'))
            g.append(B((0.07, 0.04, 0.5), 'wood_planks', center=(sx * 1.4, 0.54, 0.4)))
    else:
        g.append(beam((-0.7, 0.3, -0.4), (0.3, 0.6, 0.5), 0.07, 0.04, 'wood_planks'))
    return Node('Boat', g, children=[_col_box(Wd, 0.9, L, 0, 0.45, 0)])

def gate_old():
    g = []
    for sx in (-1, 1):
        g.append(B((0.7, 2.6, 0.7), 'rock', center=(sx * 1.6, 1.3, 0), r=0.08)); g.append(B((0.9, 0.22, 0.9), 'rock', center=(sx * 1.6, 2.7, 0), r=0.06))
    for sx in (-1, 1):
        g.append(beam((sx * 0.1, 0.25, 0), (sx * 1.15, 0.25, 0), 0.1, 0.08, 'wood_planks')) if False else None
    for y in (0.35, 0.95, 1.55, 2.0): g.append(beam((-1.2, y, 0), (1.2, y, 0), 0.12, 0.08, 'wood_planks'))
    for x in np.linspace(-1.1, 1.1, 8): g.append(beam((x, 0.25, 0.04), (x, 2.1, 0.04), 0.14, 0.05, 'wood_planks', r=0.004))
    g.append(beam((-1.2, 0.3, 0.08), (1.2, 2.0, 0.08), 0.09, 0.04, 'wood_planks'))
    g.append(tube(np.array([(-1.2, 1.2, 0.12), (-0.4, 1.0, 0.14), (0.4, 1.1, 0.14), (1.2, 1.3, 0.12)]), [0.025] * 4, 'iron', seg=6))
    return Node('OldGate', g, children=[_col_box(3.9, 2.8, 0.8, 0, 1.4, 0)])

def cave_mouth():
    g = []; r = np.random.default_rng(12)
    for k, (x, z, s, sq) in enumerate(((-3.6, 0.2, 1.9, 0.9), (3.6, 0.3, 2.1, 0.95), (-2.8, 1.8, 1.4, 0.8), (2.9, 1.9, 1.5, 0.8), (-1.8, -0.4, 1.7, 1.2), (1.9, -0.3, 1.8, 1.25))):
        g.append(rock(s, 'rock', seed=20 + k, squash=sq, rough=0.28, facets=5, sub=2, center=(x, s * sq * 0.5, z)))
    g.append(rock(2.4, 'rock', seed=31, squash=1.0, rough=0.3, facets=3, sub=2, center=(0, 3.1, 0.4)))
    g.append(B((3.0, 3.0, 2.0), 'soil', center=(0, 1.5, 1.8)))
    for gg in g:
        gg.UV = np.where(True, np.stack([gg.P[:, 0] + gg.P[:, 2], gg.P[:, 1]], 1) * U('rock'), gg.UV) if gg.mat == 'rock' else gg.UV
    return Node('CaveMouth', g)

def scarecrow():
    g = [beam((0, 0, 0), (0, 2.1, 0), 0.07, 0.07, 'wood_planks'), beam((-0.8, 1.55, 0), (0.8, 1.55, 0), 0.06, 0.06, 'wood_planks'),
         ellipsoid((0.2, 0.22, 0.2), 'canvas', seg=12, rings=8, center=(0, 1.88, 0)), cylinder(0.34, 0.34, 0.02, 'straw', seg=14, y0=2.04),
         cylinder(0.17, 0.14, 0.2, 'straw', seg=12, y0=2.05), cylinder(0.2, 0.28, 0.75, 'cloth_light', seg=12, y0=0.85),
         cylinder(0.075, 0.075, 1.5, 'paint_blue', seg=10, y0=-0.75).xf(Tm(0, 1.55, 0) @ Rz(90))]
    for sx in (-1, 1):
        for i in range(5): g.append(beam((sx * 0.78, 1.5, 0), (sx * (0.85 + 0.03 * i), 1.35 - 0.04 * i, 0.03 * i), 0.012, 0.012, 'straw'))
    return Node('Scarecrow', g, children=[Node('COL_CYL_40_210_0')])
