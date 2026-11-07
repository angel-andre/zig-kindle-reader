#!/usr/bin/env python3
"""v0.9.9 battery saving: idle wakeups (UI loop and device worker) before/after, page turns not
slower and byte-identical to the legacy 100 ms poll, stats still counted (overlap accounting),
low-battery notice at 15%/5% in the library only (reader pixels untouched), fast taps, --version."""
from pathlib import Path
import subprocess,tempfile,re,json,shutil
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
BOOK=R.parent/'testbooks'/'digital-big.pdf'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def run(d,script,extra=(),book=BOOK,books=None):
 (d/'s.sim').write_text(script)
 a=[str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(books or Path(book).parent),'--idle-min','0',*extra]+([str(book)] if book else [])
 p=subprocess.run(a,capture_output=True,timeout=180)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:];assert 'exit gesture' not in log and 'exiting' in log;return log
def lat(log,k):
 m=re.search(k+r'\s+n=\s*(\d+)\s+min=\s*(\d+) p50=\s*(\d+) avg=\s*(\d+) p90=\s*(\d+)',log);return int(m[1]),int(m[3]),int(m[5])
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
# 1. idle wakeups: device worker (host build of platform07.c, no LIPC) and UI loop (sim)
dv=json.loads(subprocess.run([str(T/'dev099_measure.sh')],capture_output=True,text=True,check=True).stdout.strip().splitlines()[-1])
assert dv['device_worker_wakeups_per_s']<1,dv
print(f"PASS device worker idle: {dv['device_worker_wakeups_per_s']}/s (0.9.8: ~50/s from a 20 ms nap)")
ui=json.loads(subprocess.run(['python3',str(T/'idle099_measure.py')],capture_output=True,text=True,check=True).stdout.strip().splitlines()[-1])
for c in ui:assert c['wakeups_per_s']<1 and c['cpu_pct']<1,c
print('PASS UI loop idle: '+', '.join(f"{c['case']} {c['wakeups_per_s']}/s cpu {c['cpu_pct']}%" for c in ui)+' (0.9.8: ~10/s)')
with tempfile.TemporaryDirectory(dir=T,prefix='bat099-') as t:
 d=Path(t)
 # 2. page turns: same pixels and no slower than the legacy fixed 100 ms poll
 turns='wait 1500\n'+'tap 1180 850\nwait 350\n'*10+'wait 800\nshot bat_page11\ntap 100 850\nwait 600\nshot bat_page10\nquit\n'
 res={}
 for name,ex in [('legacy',('--legacy-poll',)),('new',())]:
  e=d/name;(e/'data').mkdir(parents=True);log=run(e,turns,ex);res[name]=(lat(log,'touch-up -> submit'),pgm(e/'bat_page11.pgm'),pgm(e/'bat_page10.pgm'),re.search(r'turns=(\d+)',log)[1])
 assert res['legacy'][1:]==res['new'][1:],'page pixels/turn count differ'
 (n,p50,p90),(nl,l50,l90)=res['new'][0],res['legacy'][0]
 assert n==nl==11 and p90<=l90+20000,(res['new'][0],res['legacy'][0])
 print(f'PASS 11 page turns byte-identical to the legacy poll; touch-up->submit p50 {p50/1000:.1f} ms p90 {p90/1000:.1f} ms (legacy {l50/1000:.1f}/{l90/1000:.1f} ms)')
 shutil.copy(d/'new'/'bat_page11.pgm',d/'bat_reader.pgm')
 # 3. stats still counted with a long-sleeping loop: idle window 3 s, 12 s untouched -> ~3 s + active taps
 e=d/'stats';(e/'data').mkdir(parents=True)
 run(e,'wait 1500\ntap 1180 850\nwait 12000\ntap 1180 850\nwait 1500\nquit\n',('--stats-idle-sec','3'))
 secs=[int(l.split('\t')[2]) for l in (e/'data'/'state'/'stats.tsv').read_text().splitlines() if l.startswith('b\t')]
 assert secs and 4<=secs[0]<=8,secs
 print(f'PASS stats counted across long sleeps: {secs[0]}s active of ~15 s open with a 3 s idle window (idle excluded)')
 # 4. low-battery notice: library only, 15% / 5%; reader pixels identical at 4% and 76%
 books=d/'books';books.mkdir();shutil.copy(T/'fixture.epub',books/'Alpha.epub');shutil.copy(T/'tall-view-fixture.pdf',books/'Beta.pdf')
 def region(img,x0,y0,x1,y1):return sum(1 for y in range(y0,y1) for x in range(x0,x1) if img[y*W+x]<128)
 ink={};subs={}
 for lv in (76,16,15,6,5,4):
  e=d/f'lib{lv}';(e/'data').mkdir(parents=True)
  log=run(e,'wait 1500\nshot lib\nquit\n',('--sim-battery',str(lv)),book=None,books=books)
  ink[lv]=region(pgm(e/'lib.pgm'),420,150,W-70,194);subs[lv]=log.count('refresh submit')-log.count('library covers: batch')
 assert len(set(subs.values()))==1,subs
 assert ink[76]==0 and ink[16]==0 and ink[15]>0 and ink[6]>0 and ink[5]>ink[15] and ink[4]>ink[15],ink
 shutil.copy(d/'lib15'/'lib.pgm',d/'bat_lib15.pgm');shutil.copy(d/'lib4'/'lib.pgm',d/'bat_lib4.pgm');shutil.copy(d/'lib76'/'lib.pgm',d/'bat_lib76.pgm')
 print(f'PASS library notice: none at 76%/16%, "Battery low" at 15%/6%, inverted "Battery very low" at 5%/4%; no extra refresh')
 shots={}
 for lv in (4,76):
  e=d/f'rd{lv}';(e/'data').mkdir(parents=True)
  run(e,'wait 1500\nshot r\ntap 1180 850\nwait 800\nshot r2\nquit\n',('--sim-battery',str(lv)));shots[lv]=(pgm(e/'r.pgm'),pgm(e/'r2.pgm'))
 assert shots[4]==shots[76]
 print('PASS reader pages byte-identical at 4% and 76% (notice never drawn over book text)')
 # 5. fast taps never exit
 e=d/'fast';(e/'data').mkdir(parents=True)
 log=run(e,'wait 1500\n'+''.join(f'tap {x} {y}\nwait 40\n' for x,y in [(1180,850),(100,850),(640,100),(640,850),(1180,1600),(100,1600),(1180,100),(100,100)]*3)+'wait 1200\nshot bat_fast_alive\nquit\n',('--sim-battery','4'))
 assert (e/'bat_fast_alive.pgm').exists() and log.count('exiting')==1
 print('PASS 24 fast taps (corners, centre, menu) never exit')
 out=R/'out'/'bat099-shots';shutil.rmtree(out,ignore_errors=True);out.mkdir()
 for f in ['bat_reader','bat_lib15','bat_lib4','bat_lib76']:shutil.copy(d/f'{f}.pgm',out/f'{f}.pgm')
 shutil.copy(e/'bat_fast_alive.pgm',out/'bat_fast_alive.pgm')
print('ALL bat099 PASS')
