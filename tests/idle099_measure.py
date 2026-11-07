#!/usr/bin/env python3
"""Idle wakeups/s and CPU of the host build (sim): reader idle and library idle.
Counts voluntary+involuntary context switches of all threads over a quiet window."""
from pathlib import Path
import subprocess,tempfile,time,os,sys,json
R=Path(__file__).resolve().parent.parent;HOST=Path(sys.argv[1]) if len(sys.argv)>1 else R/'out/zreader-host'
BOOK=R.parent/'testbooks'/'digital-big.pdf';EPUB=R/'tests'/'fixture.epub'
def sample(pid):
 sw=0;cpu=0;n=0
 for t in os.listdir(f'/proc/{pid}/task'):
  try:
   st=open(f'/proc/{pid}/task/{t}/status').read()
   sw+=sum(int(l.split()[1]) for l in st.splitlines() if 'ctxt_switches' in l)
   f=open(f'/proc/{pid}/task/{t}/stat').read().rsplit(')',1)[1].split();cpu+=int(f[11])+int(f[12]);n+=1
  except FileNotFoundError:pass
 return sw,cpu,n
def measure(book,label,window=20):
 with tempfile.TemporaryDirectory(dir=R/'tests',prefix='idle099-') as t:
  d=Path(t);(d/'s.sim').write_text(f'wait {int((window+6)*1000)}\nquit\n')
  args=[str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(BOOK.parent),'--idle-min','0']+([str(book)] if book else [])
  p=subprocess.Popen(args,stderr=subprocess.DEVNULL);time.sleep(5)
  s0,c0,n=sample(p.pid);t0=time.time();time.sleep(window);s1,c1,_=sample(p.pid);dt=time.time()-t0
  p.wait(timeout=60)
  hz=os.sysconf('SC_CLK_TCK')
  return dict(case=label,threads=n,wakeups_per_s=round((s1-s0)/dt,1),cpu_pct=round((c1-c0)/hz/dt*100,3))
res=[measure(BOOK,'reader idle (PDF)'),measure(EPUB,'reader idle (EPUB)'),measure(None,'library idle')]
print(json.dumps(res))
