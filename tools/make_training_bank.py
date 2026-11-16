import random,json
from sudoku_reference import *
rng=random.Random(11)
targets=['pointing','boxLine','nakedPair','hiddenPair','nakedTriple','xWing','yWing','xyzWing','swordfish']
bank={t:[] for t in targets}
n=0
while any(len(v)<4 for v in bank.values()) and n<6000:
    p,sol=make_puzzle(rng); n+=1
    s=State(p); seen=set()
    while 0 in s.v:
        st=next_step(s)
        if not st: break
        t=st['t']
        if t in bank and t not in seen and len(bank[t])<4:
            seen.add(t); bank[t].append(''.join(map(str,p)))
        s.apply(st)
print(n)
print(json.dumps(bank,indent=1))
