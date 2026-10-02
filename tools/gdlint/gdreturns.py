#!/usr/bin/env python3
"""Flag functions with a declared non-void return type whose body can fall off the end
("Not all code paths return a value." is a compile error in GDScript 4)."""
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

def logical_lines(path):
    """merge multi-line bracketed statements into single logical lines with their indent"""
    res=[]; buf=''; depth=0; start_ind=0
    for raw in open(path).read().split('\n'):
        line=strip(raw).rstrip()
        if not line.strip() and depth==0: continue
        s2=re.sub(r'"(?:\\.|[^"\\])*"','""',line); s2=re.sub(r"'(?:\\.|[^'\\])*'","''",s2)
        if depth==0:
            start_ind=len(line)-len(line.lstrip(' ')); buf=line.strip()
        else:
            buf+=' '+line.strip()
        depth+=sum(s2.count(c) for c in '([{')-sum(s2.count(c) for c in ')]}')
        if depth<=0:
            res.append((start_ind,buf)); depth=0; buf=''
    return res

def block_returns(stmts):
    """stmts: list of (indent, text) at one block level (children included, deeper-indented). True if block always returns."""
    i=0
    base=stmts[0][0] if stmts else 0
    # split into top-level statements of this block
    tops=[]
    for ind,txt in stmts:
        if ind==base: tops.append([(ind,txt)])
        else: tops[-1].append((ind,txt))
    idx=0
    while idx < len(tops):
        head=tops[idx][0][1]
        body=tops[idx][1:]
        if re.match(r'return\b',head) or head=='return': return True
        if re.match(r'(assert\(false|push_error)',head) and False: pass
        if re.match(r'if\b',head):
            # collect chain
            branches=[(head,body)]
            j=idx+1
            while j < len(tops) and re.match(r'(elif\b|else\s*:)',tops[j][0][1]):
                branches.append((tops[j][0][1],tops[j][1:])); j+=1
            has_else=any(re.match(r'else\s*:',h) for h,_ in branches)
            if has_else and all(block_returns(b) if b else False for _,b in branches): return True
            idx=j; continue
        if re.match(r'match\b',head):
            arms=[]
            for k in tops[idx][1:]:
                pass
            # arms are direct children at deeper indent
            if body:
                bi=body[0][0]
                arm_list=[]; 
                for ind,txt in body:
                    if ind==bi: arm_list.append([(ind,txt)])
                    else: arm_list[-1].append((ind,txt))
                has_wild=any(re.match(r'_\s*:',a[0][1]) for a in arm_list)
                def arm_returns(a):
                    first=a[0][1]
                    inline=first.split(':',1)[1].strip() if ':' in first and not first.endswith(':') else ''
                    if inline: return inline.startswith('return')
                    return block_returns(a[1:]) if len(a)>1 else False
                if has_wild and all(arm_returns(a) for a in arm_list): return True
            idx+=1; continue
        if re.match(r'while\s+true\s*:',head) and not any(re.search(r'\bbreak\b',t) for _,t in body): return True
        idx+=1
    return False

problems=0
for p in sorted(glob.glob('**/*.gd', recursive=True)):
    ll=logical_lines(p)
    i=0
    while i < len(ll):
        ind,txt=ll[i]
        m=re.match(r'(?:static\s+)?func\s+(\w+)\s*\(.*\)\s*->\s*([\w\.\[\]]+)\s*:\s*(.*)$',txt)
        if m and ind==0:
            name,ret,inline=m.groups()
            j=i+1; body=[]
            while j < len(ll) and ll[j][0] > 0:
                body.append(ll[j]); j+=1
            if ret!='void':
                ok = (inline.startswith('return')) if inline else (block_returns(body) if body else False)
                if not ok:
                    problems+=1
                    print(f'{p}: func {name}() -> {ret}: not all code paths return a value')
            i=j; continue
        # lambdas / nested not handled
        i+=1
print('return-path findings:', problems)
