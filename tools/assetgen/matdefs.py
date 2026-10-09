"""Material registry shared by the generators, the previews and (by name) the game's MaterialLibrary."""
import os
TEX_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'textures')

# id -> (albedo texture name or None, metres per texture tile, fallback colour)
TEXTURED = {'grass': ('grass', 2.0, (0.25, 0.40, 0.10)), 'dirt': ('dirt', 2.0, (0.36, 0.27, 0.18)), 'rock': ('rock', 2.0, (0.45, 0.43, 0.40)),
            'sand': ('sand', 2.0, (0.80, 0.72, 0.52)), 'cobble': ('cobble', 1.6, (0.52, 0.49, 0.43)), 'wood_planks': ('wood_planks', 1.2, (0.45, 0.32, 0.20)),
            'bark': ('bark', 1.0, (0.25, 0.18, 0.12)), 'plaster': ('plaster', 2.0, (0.86, 0.80, 0.68)), 'brick': ('brick', 0.6, (0.55, 0.25, 0.17)),
            'roof_tiles': ('roof_tiles', 1.0, (0.65, 0.28, 0.17)), 'awning': ('awning', 1.0, (0.85, 0.5, 0.45)), 'cloth': ('cloth', 0.5, (0.72, 0.66, 0.52)),
            'iron': ('iron', 0.5, (0.2, 0.2, 0.22))}
FLAT = {'foliage_core': (0.035, 0.085, 0.03), 'paint_white': (0.93, 0.92, 0.88), 'paint_red': (0.70, 0.15, 0.12), 'paint_blue': (0.18, 0.36, 0.62),
        'paint_yellow': (0.95, 0.75, 0.10), 'paint_green': (0.20, 0.50, 0.25), 'straw': (0.85, 0.72, 0.42), 'glass': (0.6, 0.8, 0.9), 'lantern_glow': (1.0, 0.8, 0.45),
        'rope': (0.62, 0.52, 0.34), 'soil': (0.22, 0.15, 0.10), 'leather': (0.34, 0.20, 0.11), 'accessory_cloth': (0.55, 0.42, 0.22), 'accessory_leather': (0.35, 0.22, 0.12),
        'accessory_metal': (0.7, 0.7, 0.72), 'cloth_light': (0.85, 0.82, 0.70), 'mountain': (0.5, 0.5, 0.5), 'avatar_body': (0.8, 0.6, 0.5), 'avatar_hair': (0.13, 0.08, 0.05),
        'avatar_eye': (1, 1, 1), 'fruit_red': (0.75, 0.1, 0.08), 'fruit_orange': (0.95, 0.5, 0.08), 'fruit_mango': (0.95, 0.65, 0.12), 'gem': (0.3, 0.5, 0.95), 'glass_window': (0.50, 0.66, 0.74), 'hay': (0.82, 0.68, 0.30), 'canvas': (0.86, 0.82, 0.70), 'wheat': (0.85, 0.70, 0.28), 'water_dark': (0.1, 0.25, 0.3), 'beacon_glow': (1.0, 0.85, 0.5), 'hide': (0.7, 0.6, 0.5)}
ALPHA = {'foliage_broad': (0, 0), 'foliage_fruit': (1, 0), 'foliage_pine': (0, 1), 'foliage_bush': (1, 1)}   # id -> (col,row) cell in leaves.png (2x2)
DOUBLE = {'foliage_broad', 'foliage_fruit', 'foliage_pine', 'foliage_bush'}

def U(m):
    """uv scale (tiles per metre) for a textured material"""
    return 1.0 / TEXTURED[m][1] if m in TEXTURED else 1.0

def gltf_materials():
    out = {}
    for k, (t, s, c) in TEXTURED.items(): out[k] = {'color': (*c, 1.0)}
    for k, c in FLAT.items(): out[k] = {'color': (*c, 1.0)}
    for k in ALPHA: out[k] = {'color': (0.3, 0.5, 0.15, 1.0), 'double': True}
    return out

def cell_rect(mat):
    c, r = ALPHA[mat]; return (c * 0.5, r * 0.5, c * 0.5 + 0.5, r * 0.5 + 0.5)

def preview_assets():
    """mat colours + textures for preview.render"""
    import numpy as np
    from PIL import Image
    cols = {}; tex = {}
    for k, (t, s, c) in TEXTURED.items():
        p = os.path.join(TEX_DIR, f'{t}_albedo.jpg')
        if os.path.exists(p):
            im = Image.open(p).convert('RGBA').resize((256, 256)); tex[k] = np.asarray(im, np.float32) / 255.0; cols[k] = (1, 1, 1)
        else: cols[k] = c
    lp = os.path.join(TEX_DIR, 'leaves.png')
    if os.path.exists(lp):
        L = np.asarray(Image.open(lp).convert('RGBA'), np.float32) / 255.0
        for k in ALPHA: tex[k] = L; cols[k] = (1, 1, 1)
    for k, c in FLAT.items(): cols[k] = c
    return cols, tex
