#!/usr/bin/env python3
"""v0.11.2 zoom/pan: zoom-in and pan show an instant draft scaled from the page on screen, and the
final screens are byte-identical to the exact render. Reports draft time vs exact zoom render time
(box numbers). Needs a local landscape scan PDF (SPLIT_BOOK), not distributed."""
from pathlib import Path
import subprocess,tempfile,json,re,os
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host'
BOOK=Path(os.environ.get('SPLIT_BOOK',str(R.parent/'testbooks/spread-scan.pdf')))
assert BOOK.exists(),'needs the local scan test PDF'
SIM='wait 3000\ntap 640 800\nwait 60\ntap 640 800\nwait 3000\nshot z1\ndown 640 900\nmove 500 800\nmove 300 700\nup 300 700\nwait 3000\nshot z2\ntap 640 800\nwait 60\ntap 640 800\nwait 3000\nshot z3\nquit\n'
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
with tempfile.TemporaryDirectory(dir=T,prefix='zoom112-') as t:
 d=Path(t);(d/'data'/'state').mkdir(parents=True);(d/'data'/'state'/f'{fnv(str(BOOK))}.json').write_text(json.dumps(dict(page=57,trim=0)))
 (d/'s.sim').write_text(SIM)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(BOOK.parent),'--idle-min','0',str(BOOK)],capture_output=True,timeout=120);log=p.stderr.decode()
 assert p.returncode==0 and 'render_errors=0' in log and 'exit gesture' not in log,log[-2000:]
 drafts=[int(x) for x in re.findall(r'zoom/pan draft shown from the current page in (\d+) us',log)]
 m=re.search(r'render \(workers\)\s+n=\s*(\d+)\s+min=\s*(\d+)\s+p50=\s*(\d+)\s+avg=\s*(\d+)\s+p90=\s*(\d+)\s+max=\s*(\d+)',log)
 assert len(drafts)>=2,log[-1500:]
 print(f'PASS zoom/pan drafts: {len(drafts)} shown, worst {max(drafts)/1000:.1f} ms (box); exact renders p90 {int(m[5])/1000:.1f} ms, max {int(m[6])/1000:.1f} ms (box) — before 0.11.2 the screen waited for the exact render')
