#!/usr/bin/env python3
"""v0.11.1 two-page scans: p58 of a landscape scan shows left half, then right half; back goes
right->left->previous page's right half; state keeps the half; normal portrait PDF unchanged; --version."""
from pathlib import Path
import subprocess,tempfile,json,re,os
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host'
BOOK=Path(os.environ.get('SPLIT_BOOK',str(R.parent/'testbooks/spread-scan.pdf')))
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",sorted(T.glob('package1[0-9][0-9].py'))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
assert BOOK.exists(),'needs the local landscape scan test PDF (not distributed)'
with tempfile.TemporaryDirectory(dir=T,prefix='split111-') as t:
 d=Path(t);(d/'data'/'state').mkdir(parents=True);st=d/'data'/'state'/f'{fnv(str(BOOK))}.json';st.write_text(json.dumps(dict(page=57,trim=0)))
 (d/'s.sim').write_text('wait 2500\nshot L\ntap 1100 900\nwait 2500\nshot R\ntap 150 900\nwait 1500\nshot L2\ntap 150 900\nwait 2500\nshot P\nquit\n')
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(BOOK.parent),'--idle-min','0',str(BOOK)],capture_output=True,timeout=120);log=p.stderr.decode()
 assert p.returncode==0 and 'render_errors=0' in log and 'exit gesture' not in log,log[-2000:]
 L,Rr,L2,P=(pgm(d/f'{n}.pgm') for n in 'L R L2 P'.split())
 assert L!=Rr and L==L2 and P!=L and P!=Rr
 s=json.loads(st.read_text());assert s['page']==56 and s['view_step']==1 and s['split']==1,s
 print('PASS spread p58: left half, right half, back to left, back to p57 right half; state page 57 + right half saved')
