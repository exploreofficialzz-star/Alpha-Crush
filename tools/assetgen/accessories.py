"""Backpack and hats for the avatar (vertex colour = multiply tint baked for darker parts; main colour comes from the material)."""
import numpy as np
from meshkit import *
from gltf import Node

def backpack():
    """explorer rucksack, sits on the back (+Z side), origin at the attach point"""
    m = 'accessory_cloth'; g = []
    g.append(rbox((0.30, 0.40, 0.16), 0.045, m, center=(0, -0.02, 0.09), k=2))
    g.append(rbox((0.24, 0.20, 0.07), 0.03, m, center=(0, -0.10, 0.20), k=2).tint((0.9, 0.9, 0.9)))
    g.append(rbox((0.10, 0.12, 0.05), 0.02, m, center=(-0.19, -0.08, 0.11), k=2).tint((0.85, 0.85, 0.85)))
    g.append(rbox((0.10, 0.12, 0.05), 0.02, m, center=(0.19, -0.08, 0.11), k=2).tint((0.85, 0.85, 0.85)))
    g.append(rbox((0.31, 0.08, 0.17), 0.035, m, center=(0, 0.22, 0.09), k=2).tint((0.95, 0.95, 0.95)))
    # bedroll on top
    roll = cylinder(0.065, 0.065, 0.34, 'accessory_leather', seg=14, caps=(True, True)).xf(Rz(90) @ Tm(0, 0, 0)).xf(Tm(0, 0.29, 0.10))
    g.append(roll)
    for sgn in (-1, 1):  # shoulder straps (leather)
        g.append(rbox((0.045, 0.40, 0.025), 0.01, 'accessory_leather', center=(sgn * 0.095, 0.02, -0.005), k=2).xf(Rx(-6)))
        g.append(rbox((0.045, 0.045, 0.14), 0.01, 'accessory_leather', center=(sgn * 0.095, 0.21, 0.04), k=2))
    # buckle strap across the chest area (front) is skipped; metal buckles
    g.append(rbox((0.05, 0.03, 0.012), 0.004, 'accessory_metal', center=(0, 0.06, 0.18), k=2))
    return Node('Backpack', g)

def hat_straw():
    m = 'straw'
    brim = lathe([(0.0, 0.0), (0.30, 0.005), (0.34, 0.03), (0.33, 0.04), (0.17, 0.035)], m, seg=28, creases=(1, 2, 3))
    crown = lathe([(0.17, 0.02), (0.165, 0.04), (0.15, 0.12), (0.12, 0.155), (0.0, 0.16)], m, seg=24, creases=())
    band = lathe([(0.168, 0.04), (0.167, 0.06)], 'paint_red', seg=24)
    band = cylinder(0.168, 0.168, 0.026, 'paint_red', seg=24, caps=(False, False), y0=0.04)
    return Node('Hat', [brim, crown, band])

def hat_hard():
    m = 'paint_yellow'
    dome = ellipsoid((0.125, 0.092, 0.145), m, seg=24, rings=10).xf(Tm(0, 0.04, -0.01))
    dome = Geo(dome.P, dome.N, dome.UV, dome.C, dome.T[np.array([dome.P[t].mean(0)[1] > 0.035 for t in dome.T])], m)
    brim = lathe([(0.10, 0.012), (0.19, 0.008), (0.215, 0.022), (0.19, 0.03), (0.10, 0.04)], m, seg=26, creases=(1, 2)).xf(Sm(1, 1, 1.05))
    ridge = rbox((0.03, 0.026, 0.27), 0.01, m, center=(0, 0.134, -0.008), k=2)
    return Node('Hat', [dome, brim, ridge])

def hat_sun():
    m = 'cloth_light'
    brim = lathe([(0.0, 0.0), (0.26, 0.0), (0.30, 0.02), (0.29, 0.03), (0.15, 0.028)], m, seg=26, creases=(1, 2, 3))
    crown = lathe([(0.15, 0.02), (0.14, 0.09), (0.10, 0.12), (0.0, 0.125)], m, seg=22)
    band = cylinder(0.147, 0.147, 0.022, 'paint_green', seg=22, caps=(False, False), y0=0.035)
    return Node('Hat', [brim, crown, band])
