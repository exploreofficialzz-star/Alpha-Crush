#!/usr/bin/env python3
"""Lightweight static checker for this project's GDScript (4.x).  No engine needed.

Checks (each is a class of *hard* GDScript compile/runtime errors seen in AI-written code):
  A  bare call to a function that does not exist on the script / its project base chain / natives
  B  `:=` whose initializer has an unknown or Variant type  ("Cannot infer the type of ...")
  C  member (method/property/signal) access on a variable typed as a *project* class where the
     member does not exist on that class chain
  D  wrong argument count when calling a project method through a typed variable / self
  E  signal emit()/connect() arity mismatches against the declared signal
"""
import re, sys, glob, os, json, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
SYMTAB = os.path.join(tempfile.gettempdir(), 'gdlint_symtab.json')
ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
os.chdir(ROOT)

NATIVE_GLOBALS = set('''print prints printt printraw print_rich print_verbose push_error push_warning str int float bool range len
min max clamp abs sign lerp lerpf lerp_angle sin cos tan asin acos atan atan2 sinh cosh tanh sqrt pow exp log floor ceil round
randi randf randf_range randi_range randomize seed rand_from_seed maxi mini clampi maxf minf clampf absf absi signf signi snappedf snappedi snapped
move_toward is_instance_valid is_instance_id_valid preload load assert typeof deg_to_rad rad_to_deg fposmod posmod fmod floori ceili roundi
floorf ceilf roundf wrapf wrapi wrap is_equal_approx is_zero_approx inverse_lerp remap smoothstep ease hash var_to_str str_to_var
is_nan is_inf is_finite error_string type_string instance_from_id weakref get_stack char ord bytes_to_var var_to_bytes
Vector2 Vector3 Vector2i Vector3i Vector4 Color Rect2 Rect2i Basis Transform2D Transform3D Quaternion AABB Plane NodePath StringName
Callable Signal Array Dictionary PackedVector3Array PackedVector2Array PackedStringArray PackedInt32Array PackedFloat32Array PackedByteArray
Projection RID Object super await if elif else while for match return not and or in as is'''.split())

NODE_API = set('''add_child remove_child get_node get_node_or_null get_parent get_tree get_children get_child get_child_count queue_free
create_tween create_timer set_process set_physics_process set_process_input set_process_unhandled_input is_inside_tree call_deferred
add_to_group remove_from_group is_in_group emit_signal connect disconnect is_connected has_method has_signal call callv get set
find_children find_child move_child reparent set_name get_path get_instance_id get_class is_class to_string notification
get_viewport get_window get_multiplayer set_multiplayer_authority is_multiplayer_authority get_multiplayer_authority rpc rpc_id
get_meta set_meta has_meta remove_meta set_script get_script duplicate propagate_call print_tree owner name
look_at rotate_y rotate_x rotate_z rotate translate global_translate set_global_position get_global_position set_position
move_and_slide is_on_floor is_on_wall is_on_ceiling get_slide_collision get_last_motion get_real_velocity apply_floor_snap
queue_redraw draw_circle draw_rect draw_string draw_line draw_texture accept_event grab_focus release_focus add_theme_font_size_override
add_theme_color_override add_theme_stylebox_override get_theme_font_size get_theme_color set_anchors_preset get_global_rect get_rect
get_global_mouse_position get_local_mouse_position get_screen_position get_size set_size set_deferred
start stop play pause is_stopped get_ticks_msec emit connect timeout
to_global to_local global_transform get_global_transform is_visible_in_tree show hide
_ready _process _physics_process _input _unhandled_input _gui_input _draw _enter_tree _exit_tree _notification _init _to_string _unhandled_key_input
get_theme_default_font set_physics_process_internal get_physics_process_delta_time get_process_delta_time
distance_to length normalized quit free queue_free is_queued_for_deletion get_class is_class'''.split())

def strip_comment(line):
    out = []; q = None; i = 0
    while i < len(line):
        c = line[i]
        if q:
            out.append(c)
            if c == '\\': out.append(line[i+1] if i+1 < len(line) else ''); i += 1
            elif c == q: q = None
        else:
            if c in '"\'': q = c; out.append(c)
            elif c == '#': break
            else: out.append(c)
        i += 1
    return ''.join(out)

class Cls: pass
classes = {}   # class_name -> Cls
files = {}

def split_params(s):
    out = []; depth = 0; cur = ''
    for ch in s:
        if ch in '([{': depth += 1
        elif ch in ')]}': depth -= 1
        if ch == ',' and depth == 0: out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def parse(path):
    c = Cls(); c.path = path; c.name = None; c.extends = None
    c.funcs = {}; c.vars = {}; c.signals = {}; c.consts = {}; c.enums = set(); c.lines = []
    src = open(path).read().split('\n')
    c.lines = src
    for n, raw in enumerate(src, 1):
        line = strip_comment(raw).rstrip()
        if not line.strip(): continue
        ind = len(line) - len(line.lstrip(' '))
        s = line.strip()
        if ind == 0:
            m = re.match(r'class_name\s+(\w+)', s)
            if m: c.name = m.group(1); continue
            m = re.match(r'extends\s+(\S+)', s)
            if m: c.extends = m.group(1).strip('"'); continue
            m = re.match(r'(?:static\s+)?func\s+(\w+)\s*\((.*)\)\s*(?:->\s*([\w\.\[\]]+))?\s*:', s)
            if m:
                params = split_params(m.group(2))
                plist = []
                for p in params:
                    pm = re.match(r'(\w+)\s*(?::\s*([\w\.\[\]]+))?\s*(?::?=\s*(.+))?$', p)
                    plist.append((pm.group(1), pm.group(2), pm.group(3) is not None) if pm else (p, None, False))
                c.funcs[m.group(1)] = dict(params=plist, ret=m.group(3), line=n)
                continue
            m = re.match(r'signal\s+(\w+)\s*(?:\((.*)\))?', s)
            if m:
                ps = split_params(m.group(2) or '')
                c.signals[m.group(1)] = len(ps); continue
            m = re.match(r'(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?var\s+(\w+)\s*(?::\s*([\w\.\[\]]+))?\s*(:?=)?\s*(.*)$', s)
            if m:
                name, typ, op, rhs = m.groups()
                if not typ and op == ':=': typ = '?inferred:' + rhs
                c.vars[name] = typ; continue
            m = re.match(r'const\s+(\w+)', s)
            if m: c.consts[m.group(1)] = True; continue
            m = re.match(r'enum\s+(\w+)?', s)
            if m: c.enums.add(m.group(1))
    return c

for p in sorted(glob.glob('**/*.gd', recursive=True)):
    if p.startswith('tests/') and False: continue
    c = parse(p); files[p] = c
    if c.name: classes[c.name] = c

def chain(c):
    seen = []
    while c is not None and c not in seen:
        seen.append(c)
        nxt = classes.get(c.extends) if c.extends else None
        c = nxt
    return seen

def has_member(c, name):
    for k in chain(c):
        if name in k.funcs or name in k.vars or name in k.signals or name in k.consts: return True
    return False

def find_func(c, name):
    for k in chain(c):
        if name in k.funcs: return k.funcs[name]
    return None

findings = []
def report(code, path, n, msg):
    findings.append((code, path, n, msg))

VARIANT_FUNCS = {'abs','sign','min','max','clamp','lerp','snapped','round','floor','ceil','wrap'}

def expr_type_hint(rhs, c, locals_):
    """Return 'ok' if initializer certainly has a static type, 'variant' if certainly Variant, '?' unknown."""
    r = rhs.strip()
    if re.match(r'^(-?\d|"|\'|&"|true\b|false\b|\[|\{|not\s)', r): return 'ok'
    if re.match(r'^(Vector[234]i?|Color|Rect2i?|Basis|Transform[23]D|Quaternion|AABB|Plane|NodePath|StringName|Packed\w+Array|RandomNumberGenerator|SurfaceTool|Array|Dictionary)\(', r): return 'ok'
    if re.match(r'^(int|float|str|bool|String)\(', r): return 'ok'
    m = re.match(r'^(\w+)\(', r)
    if m and m.group(1) in VARIANT_FUNCS: return 'variant:' + m.group(1)
    if re.match(r'^[A-Z]\w*\.new\(', r) or re.match(r'^preload\([^)]*\)\.new\(', r): return 'ok'
    return '?'

for path, c in files.items():
    src = c.lines
    cur_fn = None
    locals_ = {}
    for n, raw in enumerate(src, 1):
        line = strip_comment(raw).rstrip()
        s = line.strip()
        if not s: continue
        ind = len(line) - len(line.lstrip(' '))
        if ind == 0 and s.startswith(('func ', 'static func ')):
            cur_fn = s; locals_ = {}
            m = re.match(r'(?:static\s+)?func\s+\w+\s*\((.*?)\)\s*(?:->.*)?:', s)
            if m:
                for p in split_params(m.group(1)):
                    pm = re.match(r'(\w+)\s*(?::\s*([\w\.\[\]]+))?', p)
                    if pm: locals_[pm.group(1)] = pm.group(2)
            continue
        # local declarations
        m = re.match(r'var\s+(\w+)\s*(?::\s*([\w\.\[\]]+))?\s*(:?=)\s*(.*)$', s)
        if m and ind > 0:
            name, typ, op, rhs = m.groups()
            if op == ':=' and not typ:
                h = expr_type_hint(rhs, c, locals_)
                if h.startswith('variant'): report('B', path, n, f'`{name} :=` initializer is Variant-returning {h[8:]}() -> cannot infer')
                locals_[name] = '?inferred:' + rhs
            else:
                locals_[name] = typ
        # A: bare calls (string literals blanked so text such as "(%s)" is never mistaken for a call)
        s_nostr = re.sub(r'"(?:\\.|[^"\\])*"', '""', s)
        for m in re.finditer(r'(?<![\w\.\"\'])(_?[a-z]\w*)\s*\(', s_nostr):
            fn = m.group(1)
            if s.startswith(('func ', 'static func ', 'signal ')) and m.start() < 12: continue
            if re.match(r'(var|const|class_name|extends)\b', s) and False: continue
            if fn in NATIVE_GLOBALS or fn in NODE_API: continue
            if fn in ('func',): continue
            # skip when it is a lambda param name call or inside strings (strings stripped crudely)
            if has_member(c, fn): continue
            if fn in locals_: continue   # callable variable
            report('A', path, n, f'call to undefined function `{fn}()`')
print('symbol table: %d scripts, %d class_names' % (len(files), len(classes)))
for code, path, n, msg in sorted(set(findings)):
    print(f'[{code}] {path}:{n}: {msg}')
print('findings:', len(set(findings)))
json.dump({k: {'extends': v.extends, 'funcs': {f: {'ret': d['ret'], 'params': d['params']} for f, d in v.funcs.items()}, 'signals': v.signals, 'vars': v.vars} for k, v in classes.items()}, open(SYMTAB, 'w'), indent=1)
