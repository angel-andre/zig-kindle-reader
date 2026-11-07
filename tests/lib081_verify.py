# v0.8.1: count screen updates per library page change (host simulator, real pump/ioctl path).
from pathlib import Path
import subprocess,tempfile,re,shutil
R=Path(__file__).resolve().parent.parent
PDF=R.parent/'testbooks/digital-small1.pdf';EPUB=R/'tests/fixture.epub'
NEXT='tap 1052 1606';PREV='tap 200 1606'
def run(data,books,script,name):
 s=Path(data).parent/'s.sim';s.write_text(script+'quit\n')
 p=subprocess.run([str(R/'out/zreader-host'),'--data',str(data),'--books',str(books),'--sim',str(s),'--idle-min','0'],capture_output=True,timeout=60,check=True)
 log=p.stderr.decode();(R/f'tests/{name}.log').write_text(log)
 pages=[];cur=None
 for line in log.splitlines():
  m=re.match(r'library page: (\d+)',line)
  if m:cur={'page':int(m[1]),'u':[]};pages.append(cur);continue
  m=re.match(r'refresh submit: wf=(\d+) full=(\w+) (\d+)x(\d+)',line)
  if m and cur is not None:cur['u'].append((int(m[1]),m[2]=='true',int(m[3]),int(m[4])))
 return pages
def check(pages,cached):
 for i,pg in enumerate(pages):
  u=pg['u'];first=u[0] if u else None
  assert first and first[2:]==(1272,1696),pg
  if i>0:assert first[0]==4,pg  # REAGL (non-flashing); never GC16 on a page change
  rest=u[1:]
  if cached:assert rest==[],pg
  assert len(rest)<=2,pg
  for wf,full,w,h in rest:assert wf==3 and not full and w<=104 and h<1696,pg  # GL16 partial, thumbnail column only
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='lib081-') as t:
 d=Path(t);books=d/'books';books.mkdir();data=d/'data';data.mkdir()
 for i in range(1,25):shutil.copy(PDF if i%2==0 else EPUB,books/f'book{i:02}.{"pdf" if i%2==0 else "epub"}')
 nav='wait 2500\n'+f'{NEXT}\nwait 2500\n{NEXT}\nwait 2500\n{PREV}\nwait 2500\n'
 cold=run(data,books,nav,'lib081-cold');check(cold,False)
 assert len(cold)==4 and all(len(p['u'])==1 for p in cold[1:]),cold
 cached=run(data,books,nav,'lib081-cached');check(cached,True)
 assert len(cached)==4,cached
 print('PASS cached library: every page change = exactly 1 update (REAGL, no GC16), no per-cover updates; first-ever page after cold start = 1 page update + 1 GL16 thumbnail batch')
 shutil.rmtree(data);data.mkdir()
 fast=run(data,books,f'wait 50\n{NEXT}\nwait 80\n{NEXT}\nwait 4000\n{NEXT}\nwait 4000\n',"lib081-uncached-fast");check(fast,False)
 assert len(fast)==4,fast
 print('PASS uncached rapid page changes: 1 page update + <=2 batched GL16 partial thumbnail-column updates per page; never full-screen per cover')
 print('counts per page change:',{'cold':[len(p['u']) for p in cold],'cached':[len(p['u']) for p in cached],'uncached_fast':[len(p['u']) for p in fast]})
