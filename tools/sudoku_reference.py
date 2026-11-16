import random, itertools
ROW=[i//9 for i in range(81)]; COL=[i%9 for i in range(81)]; BOX=[(i//27)*3+(i%9)//3 for i in range(81)]
HOUSES=[[r*9+c for c in range(9)] for r in range(9)]+[[r*9+c for r in range(9)] for c in range(9)]+[[(b//3)*27+(b%3)*3+(k//3)*9+k%3 for k in range(9)] for b in range(9)]
PEERS=[sorted(set(j for h in HOUSES if i in h for j in h)-{i}) for i in range(81)]
PEERSET=[set(p) for p in PEERS]
ALL=0x3FE
def bits(m): return [d for d in range(1,10) if m>>d&1]
def pc(m): return bin(m).count('1')

def solve_count(vals, limit=2):
    vals=list(vals); rows=[0]*9; cols=[0]*9; boxs=[0]*9
    for i,v in enumerate(vals):
        if v: b=1<<v; rows[ROW[i]]|=b; cols[COL[i]]|=b; boxs[BOX[i]]|=b
    count=[0]; sol=[None]
    def rec():
        best=-1; bm=0; bc=10
        for i in range(81):
            if not vals[i]:
                m=ALL & ~(rows[ROW[i]]|cols[COL[i]]|boxs[BOX[i]])
                c=pc(m)
                if c<bc: bc=c; best=i; bm=m
                if c==0: return
                if c==1: break
        if best<0:
            count[0]+=1
            if sol[0] is None: sol[0]=list(vals)
            return
        ds=bits(bm)
        for d in ds:
            b=1<<d; i=best
            vals[i]=d; rows[ROW[i]]|=b; cols[COL[i]]|=b; boxs[BOX[i]]|=b
            rec()
            vals[i]=0; rows[ROW[i]]&=~b; cols[COL[i]]&=~b; boxs[BOX[i]]&=~b
            if count[0]>=limit: return
    rec(); return count[0], sol[0]

def full_grid(rng):
    vals=[0]*81
    def rec(i):
        if i==81: return True
        used=set(vals[p] for p in PEERS[i])
        ds=[d for d in range(1,10) if d not in used]; rng.shuffle(ds)
        for d in ds:
            vals[i]=d
            if rec(i+1): return True
        vals[i]=0; return False
    rec(0); return vals

# ---- logic ----
TIER={'nakedSingle':0,'hiddenSingle':0,'pointing':1,'boxLine':1,'nakedPair':1,'hiddenPair':2,'nakedTriple':2,'xWing':3,'yWing':3,'xyzWing':3,'swordfish':3}
class State:
    def __init__(s, vals):
        s.v=list(vals); s.c=[0]*81
        for i in range(81):
            if not s.v[i]:
                m=ALL
                for p in PEERS[i]:
                    if s.v[p]: m&=~(1<<s.v[p])
                s.c[i]=m
    def place(s,i,d):
        s.v[i]=d; s.c[i]=0
        for p in PEERS[i]: s.c[p]&=~(1<<d)
    def apply(s,step):
        for i,d in step['place']: s.place(i,d)
        for i,d in step['elim']: s.c[i]&=~(1<<d)

def mk(t,place=(),elim=(),cells=()): return {'t':t,'place':list(place),'elim':list(elim),'cells':list(cells)}

def naked_single(s):
    for i in range(81):
        if not s.v[i] and pc(s.c[i])==1: return mk('nakedSingle',[(i,bits(s.c[i])[0])],cells=[i])
def hidden_single(s):
    for h in HOUSES[18:]+HOUSES[:18]:
        for d in range(1,10):
            cs=[i for i in h if s.c[i]>>d&1]
            if len(cs)==1: return mk('hiddenSingle',[(cs[0],d)],cells=cs)
def pointing(s):
    for h in HOUSES[18:]:
        for d in range(1,10):
            cs=[i for i in h if s.c[i]>>d&1]
            if len(cs)<2: continue
            for key,base in ((ROW,0),(COL,9)):
                if len(set(key[i] for i in cs))==1:
                    line=HOUSES[base+key[cs[0]]]
                    el=[(j,d) for j in line if j not in cs and s.c[j]>>d&1]
                    if el: return mk('pointing',elim=el,cells=cs)
def box_line(s):
    for h in HOUSES[:18]:
        for d in range(1,10):
            cs=[i for i in h if s.c[i]>>d&1]
            if len(cs)<2: continue
            if len(set(BOX[i] for i in cs))==1:
                el=[(j,d) for j in HOUSES[18+BOX[cs[0]]] if j not in cs and s.c[j]>>d&1]
                if el: return mk('boxLine',elim=el,cells=cs)
def naked_subset(s,n,name):
    for h in HOUSES:
        empt=[i for i in h if not s.v[i]]
        cand=[i for i in empt if 2<=pc(s.c[i])<=n]
        for combo in itertools.combinations(cand,n):
            m=0
            for i in combo: m|=s.c[i]
            if pc(m)==n:
                el=[(j,d) for j in empt if j not in combo for d in bits(s.c[j]&m)]
                if el: return mk(name,elim=el,cells=combo)
def hidden_pair(s):
    for h in HOUSES:
        pos={d:[i for i in h if s.c[i]>>d&1] for d in range(1,10)}
        ds=[d for d in pos if len(pos[d])==2]
        for a,b in itertools.combinations(ds,2):
            if pos[a]==pos[b]:
                keep=(1<<a)|(1<<b)
                el=[(i,d) for i in pos[a] for d in bits(s.c[i]&~keep)]
                if el: return mk('hiddenPair',elim=el,cells=pos[a])
def fish(s,n,name):
    for d in range(1,10):
        for base,other in ((0,9),(9,0)):
            lines=[]
            for li in range(9):
                cs=[i for i in HOUSES[base+li] if s.c[i]>>d&1]
                if 2<=len(cs)<=n: lines.append((li,cs))
            for combo in itertools.combinations(lines,n):
                key=COL if base==0 else ROW
                covers=set(key[i] for _,cs in combo for i in cs)
                if len(covers)!=n: continue
                used=set(li for li,_ in combo)
                keyl=ROW if base==0 else COL
                cells=[i for _,cs in combo for i in cs]
                el=[(j,d) for cv in covers for j in HOUSES[other+cv] if keyl[j] not in used and s.c[j]>>d&1]
                if el: return mk(name,elim=el,cells=cells)
def y_wing(s):
    bv=[i for i in range(81) if pc(s.c[i])==2]
    for p in bv:
        a,b=bits(s.c[p])
        for x in bv:
            if x==p or x not in PEERSET[p]: continue
            mx=s.c[x]
            if not (mx>>a&1) or mx>>b&1: continue
            c=[d for d in bits(mx) if d!=a][0]
            for y in bv:
                if y in (p,x) or y not in PEERSET[p]: continue
                if s.c[y]!=((1<<b)|(1<<c)): continue
                el=[(j,c) for j in PEERSET[x]&PEERSET[y] if j!=p and s.c[j]>>c&1]
                if el: return mk('yWing',elim=el,cells=[p,x,y])
def xyz_wing(s):
    for p in range(81):
        if pc(s.c[p])!=3: continue
        for x,y in itertools.combinations([i for i in PEERS[p] if pc(s.c[i])==2 and s.c[i]&s.c[p]==s.c[i]],2):
            if s.c[x]==s.c[y]: continue
            cm=s.c[x]&s.c[y]
            if pc(cm)!=1: continue
            c=bits(cm)[0]
            el=[(j,c) for j in PEERSET[p]&PEERSET[x]&PEERSET[y] if s.c[j]>>c&1]
            if el: return mk('xyzWing',elim=el,cells=[p,x,y])
TECHS=[('hiddenSingle',hidden_single),('nakedSingle',naked_single),('pointing',pointing),('boxLine',box_line),
 ('nakedPair',lambda s:naked_subset(s,2,'nakedPair')),('hiddenPair',hidden_pair),('nakedTriple',lambda s:naked_subset(s,3,'nakedTriple')),
 ('xWing',lambda s:fish(s,2,'xWing')),('yWing',y_wing),('xyzWing',xyz_wing),('swordfish',lambda s:fish(s,3,'swordfish'))]
FN=dict(TECHS)
def next_step(s):
    for n,f in TECHS:
        r=f(s)
        if r: return r
def grade(vals):
    s=State(vals); mx=0; used={}
    while 0 in s.v:
        st=next_step(s)
        if not st: return None,used
        mx=max(mx,TIER[st['t']]); used[st['t']]=used.get(st['t'],0)+1
        s.apply(st)
    return mx,used

def make_puzzle(rng, min_clues=17):
    sol=full_grid(rng); p=list(sol)
    order=list(range(41)); rng.shuffle(order)
    clues=81
    for i in order:
        j=80-i
        if clues-(1 if i==j else 2)<min_clues: continue
        a,b=p[i],p[j]; p[i]=0;p[j]=0
        if solve_count(p)[0]!=1: p[i]=a;p[j]=b
        else: clues-= 1 if i==j else 2
    return p,sol
