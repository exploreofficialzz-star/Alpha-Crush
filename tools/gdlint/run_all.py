#!/usr/bin/env python3
"""gdlint - engine-free static checks for this project's GDScript (Godot 4.x).

    python3 tools/gdlint/run_all.py            # from the project root
    python3 tools/gdlint/run_all.py --verbose  # also list `:=` initializers it cannot prove

It cannot replace running the game, but it catches the compile/parse-time error classes that
previously slipped through: undefined functions, `:=` inferred from Variant, redeclared locals,
missing return paths, and wrong member names / argument counts / signal arity on project classes.
Exit code is non-zero if any check fails.
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
extra = [a for a in sys.argv[1:] if a.startswith('--')]
steps = [
    ('undefined functions / Variant utility inference', 'gdcheck.py'),
    ('`:=` initializer types', 'gdtypes.py'),
    ('member / arity / signal checks', 'gdcalls.py'),
    ('duplicate local declarations (scope)', 'gdscope.py'),
    ('missing return paths', 'gdreturns.py'),
]
failed = 0
for title, script in steps:
    print(f'== {title}')
    proc = subprocess.run([sys.executable, os.path.join(HERE, script), ROOT] + extra, capture_output=True, text=True)
    out = (proc.stdout + proc.stderr).strip()
    print(out if out else '(no output)')
    # gdcheck/gdcalls/gdscope/gdreturns end with "findings: N"; gdtypes exits 1 on definite errors
    bad = proc.returncode != 0
    for line in out.splitlines():
        if line.split(':')[0].strip() in ('findings', 'scope findings', 'return-path findings') and line.split(':')[-1].strip() != '0':
            bad = True
    if bad:
        failed += 1
print('\nGDLINT:', 'FAILED (%d check group(s))' % failed if failed else 'all checks passed')
sys.exit(1 if failed else 0)
