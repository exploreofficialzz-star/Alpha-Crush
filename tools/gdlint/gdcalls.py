#!/usr/bin/env python3
"""Phase 3: member existence, call arity and signal arity for typed project-class receivers."""
import re, sys, json, os, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
SYMTAB = os.path.join(tempfile.gettempdir(), 'gdlint_symtab.json')
ROOT_ARG = [a for a in sys.argv[1:] if not a.startswith('--')]
os.chdir(ROOT_ARG[0] if ROOT_ARG else '.')
src = open(os.path.join(HERE, 'gdtypes.py')).read().split("issues = []")[0]
src = src.replace("os.chdir(ROOT_ARG[0] if ROOT_ARG else '.')", "")
exec(src)

NODE_PROPS = set('''name position global_position rotation rotation_degrees global_rotation scale visible velocity collision_layer collision_mask
size custom_minimum_size text modulate mouse_filter layer owner multiplayer process_mode transform global_transform top_level
disabled value min_value max_value step button_pressed current fov billboard font_size outline_size mesh material_override
autostart wait_time one_shot emitting amount lifetime stream volume_db stream_paused playing environment light_energy shadow_enabled
position_x horizontal_alignment autowrap_mode size_flags_horizontal size_flags_vertical anchor_left anchor_right pivot_offset
horizontal_scroll_mode placeholder_text'''.split())

def args_of(call_text):
    """call_text starts at '(' ; returns list of top-level args"""
    end = matching_close(call_text, 0)
    inner = call_text[1:end]
    return split_params(inner) if inner.strip() else [], end

def ref_type(name, c, locals_):
    if name == 'self': return c.name
    if name in locals_:
        t = locals_[name]
        if t and t.startswith('?inferred:'): return resolve(t[10:], c, locals_)
        return t
    for k in chain(c):
        if name in k.vars:
            t = k.vars[name]
            if t and t.startswith('?inferred:'): return resolve(t[10:], k, {})
            return t
    return None

def func_arity(fd):
    ps = fd['params']; req = sum(1 for p in ps if not p[2]); return req, len(ps)

findings = []
for path, c in files.items():
    locals_ = {}
    for n, raw in enumerate(c.lines, 1):
        line = strip_comment(raw).rstrip(); s = line.strip()
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
        m = re.match(r'for\s+(\w+)\s+in\s+(.*):$', s)
        if m:
            it = ref_type(m.group(2).strip(), c, locals_) if re.match(r'^\w+$', m.group(2).strip()) else None
            em = re.match(r'Array\[(\w+)\]', it or '')
            locals_[m.group(1)] = em.group(1) if em else None
        m = re.match(r'var\s+(\w+)\s*(?::\s*([\w\.\[\]]+))?\s*(:?=)\s*(.*)$', s)
        if m and ind > 0:
            name, typ, op, rhs = m.groups()
            locals_[name] = typ if typ else ('?inferred:' + rhs if op == ':=' else None)
        # scan receiver.member occurrences
        sc = re.sub(r'"(?:\\.|[^"\\])*"', '""', s)
        for mm in re.finditer(r'(?<![\w\.])(self|[a-z_]\w*)\.([a-z_]\w*)(\s*\()?', sc):
            recv, member, paren = mm.group(1), mm.group(2), mm.group(3)
            t = ref_type(recv, c, locals_)
            rc = classes.get(t) if t else None
            if rc is None: continue
            if member in NODE_API or member in NODE_PROPS: 
                if not has_member(rc, member) and not paren: continue
            if not has_member(rc, member):
                if member in NODE_API or member in NODE_PROPS: continue
                # signals via connect/emit handled below, still must exist
                findings.append(('C', path, n, f'`{recv}`:{t} has no member `{member}`'))
                continue
            if paren:
                fd = find_func(rc, member)
                if fd:
                    start = mm.end() - 1
                    a, end = args_of(sc[start:])
                    req, tot = func_arity(fd)
                    if len(a) < req or len(a) > tot:
                        findings.append(('D', path, n, f'`{t}.{member}()` expects {req}..{tot} args, got {len(a)}'))
        # static / class-qualified calls: ClassName.func(args) and ClassName.CONST
        for mm in re.finditer(r'(?<![\w\.])([A-Z]\w*)\.([A-Za-z_]\w*)(\s*\()?', sc):
            cname, member, paren = mm.group(1), mm.group(2), mm.group(3)
            rc = classes.get(cname)
            if rc is None or cname == c.name: continue
            if member in ('new', 'free', 'get_script', 'duplicate'): continue
            if not has_member(rc, member):
                if member in NODE_API or member in NODE_PROPS: continue
                findings.append(('C', path, n, f'class `{cname}` has no member `{member}`'))
                continue
            if paren:
                fd = find_func(rc, member)
                if fd:
                    a, end = args_of(sc[mm.end() - 1:])
                    req, tot = func_arity(fd)
                    if len(a) < req or len(a) > tot:
                        findings.append(('D', path, n, f'`{cname}.{member}()` expects {req}..{tot} args, got {len(a)}'))
        # emit arity on own / typed signals
        for mm in re.finditer(r'(?<![\w\.])(?:(self|[a-z_]\w*)\.)?([a-z_]\w*)\.emit\s*\(', sc):
            recv, sig = mm.group(1), mm.group(2)
            rcls = c if (recv is None or recv == 'self') else classes.get(ref_type(recv, c, locals_) or '')
            if rcls is None: continue
            for k in chain(rcls):
                if sig in k.signals:
                    a, _ = args_of(sc[mm.end()-1:])
                    if len(a) != k.signals[sig]:
                        findings.append(('E', path, n, f'signal `{sig}` declares {k.signals[sig]} params, emit passes {len(a)}'))
                    break
        # connect arity
        for mm in re.finditer(r'(?<![\w\.])(?:(self|[a-z_]\w*)\.)?([a-z_]\w*)\.connect\s*\(', sc):
            recv, sig = mm.group(1), mm.group(2)
            rcls = c if (recv is None or recv == 'self') else classes.get(ref_type(recv, c, locals_) or '')
            if rcls is None: continue
            decl = None
            for k in chain(rcls):
                if sig in k.signals: decl = k.signals[sig]; break
            if decl is None: continue
            rest = sc[mm.end():]
            lm = re.match(r'\s*func\s*\((.*?)\)', rest)
            if lm:
                cnt = len(split_params(lm.group(1)))
                if cnt != decl: findings.append(('E', path, n, f'lambda for `{sig}` takes {cnt} params, signal has {decl}'))
                continue
            mref = re.match(r'\s*(?:(self|[a-z_]\w*)\.)?([a-z_]\w*)\s*[\),]', rest)
            if mref:
                trecv, tm = mref.group(1), mref.group(2)
                tcls = c if (trecv is None or trecv == 'self') else classes.get(ref_type(trecv, c, locals_) or '')
                if tcls:
                    fd = find_func(tcls, tm)
                    if fd:
                        req, tot = func_arity(fd)
                        if not (req <= decl <= tot): findings.append(('E', path, n, f'`{tm}` takes {req}..{tot} params, signal `{sig}` has {decl}'))
for f in sorted(set(findings)): print('[%s] %s:%d: %s' % f)
print('findings:', len(set(findings)))
