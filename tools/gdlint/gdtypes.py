#!/usr/bin/env python3
"""Phase 2: resolve the static type of every `:=` initializer and every typed-class member access."""
import re, sys, json, glob, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
SYMTAB = os.path.join(tempfile.gettempdir(), 'gdlint_symtab.json')
ROOT_ARG = [a for a in sys.argv[1:] if not a.startswith('--')]
os.chdir(ROOT_ARG[0] if ROOT_ARG else '.')
sym = json.load(open(SYMTAB))
exec(open(os.path.join(HERE, 'gdcheck.py')).read().split("for path, c in files.items():")[0].replace("ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'\nos.chdir(ROOT)", ""))

NUM = {'int','float'}
STR_RET = {'to_upper','to_lower','substr','strip_edges','capitalize','replace','join','format','left','right','lstrip','rstrip','pad_zeros','to_snake_case','c_unescape','get_basename','simplify_path','get_base_dir','trim_prefix','trim_suffix','repeat','indent','dedent','uri_encode','validate_node_name','get_file','get_extension'}
BOOL_RET = {'has','is_empty','begins_with','ends_with','contains','is_valid_int','is_valid_float','has_method','has_signal','is_inside_tree','is_on_floor','is_stopped','is_connected','has_meta','is_in_group','has_all','erase','is_action_pressed','is_action_just_pressed','is_class','is_null','is_equal_approx','is_zero_approx','is_finite','is_nan'}
INT_RET = {'size','find','count','rfind','length_i','get_instance_id','get_child_count','get_unique_id','get_remote_sender_id','hash','to_int','get_ticks_msec','get_ticks_usec','get_frames_per_second_i','get_children_count','max_axis_index','min_axis_index'}
FLOAT_RET = {'length','length_squared','distance_to','distance_squared_to','dot','angle','to_float','get_unix_time_from_system','randf','randf_range','get_frames_per_second','get_process_delta_time','get_monitor','angle_to'}
NATIVE_STATIC = {
 'FileAccess.open':'FileAccess','FileAccess.get_file_as_string':'String','DirAccess.remove_absolute':'int','DirAccess.rename_absolute':'int',
 'DirAccess.make_dir_recursive_absolute':'int','DirAccess.open':'DirAccess','ProjectSettings.globalize_path':'String','JSON.stringify':'String','JSON.parse_string':'Variant',
 'Time.get_unix_time_from_system':'float','Time.get_ticks_msec':'int','Time.get_datetime_dict_from_system':'Dictionary','Time.get_date_string_from_system':'String',
 'Input.get_vector':'Vector2','Input.get_axis':'float','Input.is_action_pressed':'bool','Input.is_action_just_pressed':'bool','Engine.get_frames_per_second':'float',
 'Performance.get_monitor':'float','OS.get_name':'String','InputMap.has_action':'bool','InputMap.action_get_events':'Array','ResourceLoader.exists':'bool','FileAccess.file_exists':'bool',
 'ThemeDB.fallback_font':'Font',
}
NODE_RET = {'get_node_or_null':'Node','get_node':'Node','get_parent':'Node','create_tween':'Tween','instantiate':'Node','get_tree':'SceneTree','get_viewport':'Viewport','create_timer':'SceneTreeTimer','find_children':'Array','get_children':'Array','get_child':'Node','duplicate':None,'commit':'ArrayMesh'}

def base_type(t):
    return t

def class_of(t):
    return classes.get(t) if t else None

def resolve(expr, c, locals_, depth=0):
    e = expr.strip()
    while e.startswith('(') and e.endswith(')') and balanced(e[1:-1]): e = e[1:-1].strip()
    # ternary at top level
    t = split_top(e, ' if ')
    if t and ' else ' in t[1]:
        a = t[0]; rest = t[1]; cond, b = rest.split(' else ', 1) if True else (None, None)
        ra, rb = resolve(a, c, locals_), resolve(b, c, locals_)
        if ra and ra == rb: return ra
        return 'Variant' if (ra == 'Variant' or rb == 'Variant' or (ra and rb and ra != rb and not (ra in NUM and rb in NUM))) else (ra if ra in NUM and rb in NUM else None)
    m = split_top_last(e, ' as ')
    if m: return m.strip()
    if re.match(r'^-?\d+$', e): return 'int'
    if re.match(r'^-?\d*\.\d+(e-?\d+)?$', e) or re.match(r'^-?\d+\.$', e) or e in ('INF','NAN','PI','TAU'): return 'float'
    if re.match(r'^("|\'|&")', e) and e[-1] in '"\'' and not re.search(r'"\s*[%+]', e[1:]): return 'String'
    if re.match(r'^("|\')', e) and ' % ' in e: return 'String'
    if e in ('true','false') or e.startswith('not '): return 'bool'
    if e == 'null': return 'Variant'
    if e.startswith('['): return 'Array'
    if e.startswith('{'): return 'Dictionary'
    m = re.match(r'^(Vector[234]i?|Color|Rect2i?|Basis|Transform[23]D|Quaternion|AABB|Plane|NodePath|StringName|Packed\w+Array|RandomNumberGenerator|SurfaceTool|Array|Dictionary|Callable)\(', e)
    if m and matching_close(e, len(m.group(1))) == len(e)-1: return m.group(1)
    m = re.match(r'^(int|float|str|bool|String)\(', e)
    if m and matching_close(e, len(m.group(1))) == len(e)-1: return {'str':'String'}.get(m.group(1), m.group(1))
    m = re.match(r'^(Vector[234]i?|Color)\.(ZERO|ONE|UP|DOWN|LEFT|RIGHT|FORWARD|BACK|WHITE|BLACK|RED|GREEN|BLUE|YELLOW)$', e)
    if m: return m.group(1)
    m = re.match(r'^([A-Z]\w*)\.new\(', e)
    if m and matching_close(e, e.index('(')) == len(e)-1: return m.group(1)
    m = re.match(r'^preload\("([^"]+)"\)\.new\(', e)
    if m:
        p = m.group(1)[6:]
        cc = files.get(p)
        return cc.name if cc and cc.name else 'Variant'
    # binary operators (top level, lowest precedence first)
    for ops in (['==','!=','<','>','<=','>=',' and ',' or ',' in '], ['+','-'], ['*','/','%']):
        for op in ops:
            parts = split_top_op(e, op)
            if parts:
                l, r = parts
                if op in ['==','!=','<','>','<=','>=',' and ',' or ',' in ']: return 'bool'
                tl, tr = resolve(l, c, locals_), resolve(r, c, locals_)
                if tl == 'Variant' or tr == 'Variant' or tl is None or tr is None: return 'Variant' if (tl == 'Variant' or tr == 'Variant') else None
                if tl in NUM and tr in NUM: return 'float' if 'float' in (tl, tr) or op == '/' and False else ('int' if tl == tr == 'int' else 'float')
                if tl == 'String' and op in ('+','%'): return 'String'
                if op == '%' and tl == 'String': return 'String'
                if tl.startswith('Vector') or tl in ('Color',): return tl
                if tr.startswith('Vector'): return tr
                return tl
    # function calls / member chains
    m = re.match(r'^(\w+)\((.*)\)$', e, re.S)
    if m and matching_close(e, e.index('(')) == len(e)-1:
        fn = m.group(1)
        if fn in VARIANT_FUNCS: return 'Variant'
        if fn in ('maxi','mini','clampi','absi','floori','ceili','roundi','posmod','snappedi','randi','randi_range','wrapi','signi','len'): return 'int'
        if fn in ('maxf','minf','clampf','absf','floorf','ceilf','roundf','snappedf','sqrt','sin','cos','tan','atan2','pow','randf','randf_range','lerpf','deg_to_rad','rad_to_deg','fposmod','fmod','move_toward','lerp_angle','signf','smoothstep','remap','inverse_lerp','exp','log','asin','acos','atan'): return 'float'
        if fn == 'is_instance_valid': return 'bool'
        f = find_func(c, fn)
        if f:
            return normalize_ret(f['ret'])
        return None
    # member chain: split on last top-level dot
    idx = last_top_dot(e)
    if idx is not None:
        recv, member = e[:idx], e[idx+1:]
        mm = re.match(r'^(\w+)\s*(\((.*)\))?$', member, re.S)
        if not mm: return None
        name, call = mm.group(1), mm.group(2)
        rt = resolve(recv, c, locals_) if not re.match(r'^[A-Z]\w*$', recv) else '#class:' + recv
        if rt and rt.startswith('#class:'):
            key = rt[7:] + '.' + name
            if key in NATIVE_STATIC: return NATIVE_STATIC[key]
            kc = classes.get(rt[7:])
            if kc and name in kc.consts: return None
            if rt[7:] in ('Mesh','BaseMaterial3D','Environment','Control','Node','Camera3D','TextServer') and re.match(r'^[A-Z_0-9]+$', name): return 'int'
            if rt[7:] == 'GameConfig': return None
            return None
        if rt is None: return None
        if rt == 'Variant': return 'Variant'
        rc = classes.get(rt)
        if rc:
            if call is not None:
                f = find_func(rc, name)
                if f: return normalize_ret(f['ret'])
                if name in NODE_RET: return NODE_RET[name]
                return None
            for k in chain(rc):
                if name in k.vars:
                    t = k.vars[name]
                    if t and t.startswith('?inferred:'): return resolve(t[10:], k, {})
                    return t if t else 'Variant'
            return None
        # native receiver
        if call is not None:
            if name in STR_RET and rt in ('String','StringName'): return 'String'
            if name in BOOL_RET: return 'bool'
            if name in ('keys','values'): return 'Array'
            if name == 'get' and rt == 'Dictionary': return 'Variant'
            if name in ('duplicate',) : return rt
            if name in ('normalized','abs','floor','ceil','round','lerp','clamp','limit_length','rotated','snapped','lightened','darkened','with_alpha') and (rt.startswith('Vector') or rt in ('Color',)): return rt
            if name in INT_RET: return 'int'
            if name in FLOAT_RET: return 'float'
            if name in NODE_RET and NODE_RET[name]: return NODE_RET[name]
            if name in ('capitalize',): return 'String'
            if name in ('pop_back','pop_front','back','front','pick_random','get','values') : return 'Variant'
            return None
        else:
            if rt in ('Vector2','Vector3','Vector2i','Vector3i') and name in 'xyz': return 'float' if not rt.endswith('i') else 'int'
            if rt == 'Color' and name in ('r','g','b','a'): return 'float'
            return None
    # plain identifier
    if re.match(r'^\w+$', e):
        if e in locals_:
            t = locals_[e]
            if t and t.startswith('?inferred:'): return resolve(t[10:], c, locals_)
            return t if t else 'Variant'
        for k in chain(c):
            if e in k.vars:
                t = k.vars[e]
                if t and t.startswith('?inferred:'): return resolve(t[10:], k, {})
                return t if t else 'Variant'
            if e in k.consts: return const_type(k, e)
        return None
    # index
    if e.endswith(']'):
        return 'Variant'
    return None

def const_type(k, name):
    for ln in k.lines:
        m = re.match(r'\s*const\s+%s\s*(?::\s*(\w+))?\s*:?=\s*(.*)' % re.escape(name), ln)
        if m:
            if m.group(1): return m.group(1)
            return resolve(strip_comment(m.group(2)), k, {})
    return None

def normalize_ret(r):
    if r is None: return 'void'
    return r

def balanced(s):
    d = 0
    for ch in s:
        if ch in '([{': d += 1
        elif ch in ')]}':
            d -= 1
            if d < 0: return False
    return d == 0

def matching_close(e, i):
    d = 0; q = None
    for k in range(i, len(e)):
        ch = e[k]
        if q:
            if ch == q and e[k-1] != '\\': q = None
            continue
        if ch in '"\'': q = ch; continue
        if ch in '([{': d += 1
        elif ch in ')]}':
            d -= 1
            if d == 0: return k
    return -1

def top_level_positions(e):
    """depth at each char index; chars inside string literals get depth 99 so they never match as top-level"""
    d = 0; q = None; out = []
    for k, ch in enumerate(e):
        if q:
            out.append(99)
            if ch == q and e[k-1] != '\\': q = None
            continue
        if ch in '"\'':
            q = ch; out.append(99); continue
        if ch in '([{': d += 1; out.append(d)
        elif ch in ')]}': d -= 1; out.append(d)
        else: out.append(d)
    return out

def split_top(e, sep):
    d = top_level_positions(e)
    i = 0
    while True:
        j = e.find(sep, i)
        if j < 0: return None
        if d[j] == 0: return (e[:j], e[j+len(sep):])
        i = j + 1

def split_top_last(e, sep):
    d = top_level_positions(e)
    j = e.rfind(sep)
    while j >= 0:
        if d[j] == 0 and not e[j+len(sep):].strip().startswith('('): return e[j+len(sep):]
        j = e.rfind(sep, 0, j)
    return None

def split_top_op(e, op):
    d = top_level_positions(e)
    for j in range(len(e)-1, 0, -1):
        if e.startswith(op, j) and d[j] == 0:
            prev = e[:j].rstrip()
            if op in '+-' and (not prev or prev[-1] in '+-*/%(,=<>' or prev.endswith((' and',' or',' not',' in'))): continue
            if op in ('<','>') and (e[j:j+2] in ('<=','>=') or e[j-1:j+1] in ('<=','>=','->','<<','>>')): continue
            if op in ('==',) and e[j-1:j] in ('!','<','>'): continue
            if op == '*' and e[j-1:j] == '*': continue
            return (e[:j], e[j+len(op):])
    return None

def last_top_dot(e):
    d = top_level_positions(e)
    q = None
    last = None
    for k, ch in enumerate(e):
        if ch == '.' and d[k] == 0 and k > 0 and not re.match(r'\d', e[k-1:k]) : last = k
    return last

issues = []
for path, c in files.items():
    locals_ = {}
    for n, raw in enumerate(c.lines, 1):
        line = strip_comment(raw).rstrip()
        s = line.strip()
        if not s: continue
        ind = len(line) - len(line.lstrip(' '))
        if ind == 0 and s.startswith(('func ', 'static func ')):
            locals_ = {}
            m = re.match(r'(?:static\s+)?func\s+\w+\s*\((.*?)\)\s*(?:->.*)?:', s)
            if m:
                for p in split_params(m.group(1)):
                    pm = re.match(r'(\w+)\s*(?::\s*([\w\.\[\]]+))?', p)
                    if pm: locals_[pm.group(1)] = pm.group(2)
            continue
        m = re.match(r'(?:for\s+(\w+)\s+in)', s)
        if m: locals_[m.group(1)] = None
        m = re.match(r'(?:@\w+(?:\([^)]*\))?\s+)*(var|const)\s+(\w+)\s*(?::\s*([\w\.\[\]]+))?\s*(:?=)\s*(.*)$', s)
        if m:
            kind, name, typ, op, rhs = m.groups()
            if ind > 0 or True:
                if op == ':=' and not typ:
                    r = resolve(rhs, c, locals_)
                    if r is None or r == 'Variant' or r == 'void':
                        issues.append((path, n, name, rhs, r))
                    locals_[name] = '?inferred:' + rhs if ind > 0 else locals_.get(name)
                else:
                    locals_[name] = typ
definite = [i for i in issues if i[4] in ('Variant', 'void')]
unknown = [i for i in issues if i[4] not in ('Variant', 'void')]
if '--quiet' not in sys.argv:
    print('`:=` initializers that are certainly Variant (compile error):', len(definite))
    for path, n, name, rhs, r in definite:
        print(f'  [B] {path}:{n}: {name} := {rhs[:110]}   => {r}')
    if '--verbose' in sys.argv:
        print('`:=` initializers whose type this tool cannot prove (engine property types):', len(unknown))
        for path, n, name, rhs, r in unknown:
            print(f'  [?] {path}:{n}: {name} := {rhs[:110]}')
if definite:
    sys.exit(1)
