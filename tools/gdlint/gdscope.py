#!/usr/bin/env python3
"""Detect GDScript 4 'already declared in this scope' errors: a `var`/`for` variable / lambda param that
redeclares a name still in scope (outer declared first, inner declared later)."""
import re, sys, glob, os
os.chdir(sys.argv[1] if len(sys.argv) > 1 else '.')
def strip(line):
    out=[]; q=None; i=0
    while i < len(line):
        c=line[i]
        if q:
            out.append(c)
            if c=='\\': out.append(line[i+1] if i+1<len(line) else ''); i+=1
            elif c==q: q=None
        else:
            if c in '"\'': q=c; out.append(c)
            elif c=='#': break
            else: out.append(c)
        i+=1
    return ''.join(out)
def depth_delta(s):
    s2=re.sub(r'"(?:\\.|[^"\\])*"','""',s); s2=re.sub(r"'(?:\\.|[^'\\])*'","''",s2)
    return sum(s2.count(c) for c in '([{') - sum(s2.count(c) for c in ')]}')
errs=0
for p in sorted(glob.glob('**/*.gd', recursive=True)):
    lines=open(p).read().split('\n')
    stack=[]   # list of [indent, {name: line}]
    pending={} # indent -> list of (name,line) to add to scope at that indent
    in_func=False; bracket=0
    for n,raw in enumerate(lines,1):
        line=strip(raw).rstrip()
        if not line.strip(): continue
        d=depth_delta(line)
        if bracket>0:
            bracket+=d
            continue
        ind=len(line)-len(line.lstrip(' '))
        s=line.strip()
        bracket=max(0,d)
        if ind==0:
            stack=[]; pending={}
            m=re.match(r'(?:static\s+)?func\s+\w+\s*\((.*)\)\s*(?:->.*)?:\s*$',s)
            if m:
                names=[re.match(r'(\w+)',x.strip()).group(1) for x in re.split(r',(?![^\[\(]*[\]\)])',m.group(1)) if x.strip()]
                pending[4]=[(nm,n) for nm in names]
            continue
        # drop scopes deeper than this statement
        while stack and stack[-1][0] > ind: stack.pop()
        if not stack or stack[-1][0] < ind:
            stack.append([ind,{}])
            for nm,ln in pending.pop(ind,[]):
                stack[-1][1][nm]=ln
        scope=stack[-1][1]
        # declarations on this line
        decls=[]
        m=re.match(r'var\s+(\w+)',s)
        if m: decls.append(m.group(1))
        m=re.match(r'for\s+(\w+)\s+in\b',s)
        if m: pending.setdefault(ind+4,[]).append((m.group(1),n))
        for nm in decls:
            for sc in stack:
                if nm in sc[1]:
                    print(f'{p}:{n}: `{nm}` already declared in an enclosing scope (line {sc[1][nm]})'); errs+=1
                    break
            scope[nm]=n
        # lambda params declared on this line, visible in deeper block
        for lm in re.finditer(r'func\s*\(([^)]*)\)\s*(?:->\s*\w+\s*)?:\s*$',s):
            names=[re.match(r'(\w+)',x.strip()).group(1) for x in lm.group(1).split(',') if x.strip()]
            pending.setdefault(ind+4,[]).extend((nm,n) for nm in names)
        # for-loop var vs existing outer scopes
        m=re.match(r'for\s+(\w+)\s+in\b',s)
        if m:
            nm=m.group(1)
            for sc in stack:
                if nm in sc[1]:
                    print(f'{p}:{n}: for-variable `{nm}` already declared in an enclosing scope (line {sc[1][nm]})'); errs+=1
                    break
print('scope findings:',errs)
