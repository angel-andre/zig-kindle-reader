#!/usr/bin/env python3
"""v0.9.7 reading stats: active-time counting (idle/menu excluded), pages, sessions, percent,
finished, day streak/week, Stats screen from Settings, Contents stats line, Reset with
confirmation, batched writes, fast taps, --version."""
from pathlib import Path
import subprocess,tempfile,re,datetime,time
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def run(d,book,script,extra=()):
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(Path(book).parent),'--idle-min','0',*extra,str(book)],capture_output=True,timeout=120)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:];assert 'exit gesture' not in log;return log
def stats(d):
 b={};days={}
 for l in (d/'data'/'state'/'stats.tsv').read_text().splitlines():
  f=l.split('\t')
  if f[0]=='b':b[f[1]]=dict(secs=int(f[2]),pages=int(f[3]),sessions=int(f[4]),first=int(f[5]),last=int(f[6]),pct=int(f[7]),finished=int(f[8]))
  if f[0]=='d':days[int(f[1])]=int(f[2])
 return b,days
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[7-9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
BOOK=R.parent/'testbooks'/'digital-big.pdf'
today=(datetime.date.today()-datetime.date(1970,1,1)).days
with tempfile.TemporaryDirectory(dir=T,prefix='st097-') as t:
 d=Path(t);(d/'data'/'state').mkdir(parents=True)
 # seed: yesterday and the day before have reading -> streak/week include them
 (d/'data'/'state'/'stats.tsv').write_text(f'zrstats\t1\nd\t{today-2}\t600\nd\t{today-1}\t900\nd\t{today-30}\t300\n')
 t0=time.time()
 log=run(d,BOOK,'wait 1500\nshot st_page1\n'+'tap 1180 850\nwait 1000\n'*8+'wait 5000\ntap 640 100\nwait 4000\ntap 640 850\nwait 600\ntap 640 100\nwait 300\nmenubtn 0 0\nwait 800\nshot st_contents\nquit\n',extra=('--stats-idle-sec','2'))
 b,days=stats(d);s=b[fnv(str(BOOK))]
 assert s['pages']==8 and s['sessions']==1 and s['pct']==2 and s['finished']==0,s
 assert 8<=s['secs']<=13,s   # ~10.5 s active of ~22 s open: idle and menu excluded
 assert days[today]==s['secs'] and days[today-1]==900 and days[today-2]==600,days
 print(f"PASS active time {s['secs']}s of {time.time()-t0:.0f}s run (idle >2s and menu not counted); 8 pages, 1 session, 2%; today's bucket matches")
 assert log.count('stats.tsv')==0
 # second session: Settings -> Reading stats, reset with confirmation
 log=run(d,BOOK,'''wait 1500
shot st_page_again
tap 640 100
wait 300
menubtn 2 2
wait 700
tap 770 85
wait 900
shot st_screen
tap 636 1581
wait 600
shot st_reset_confirm
tap 1147 85
wait 600
tap 770 85
wait 600
tap 636 1581
wait 200
tap 636 1581
wait 900
shot st_reset_done
quit
''')
 m=re.findall(r'stats: today=(\d+)s week=(\d+)s all=(\d+)s finished=(\d+) streak=(\d+) books=(\d+)',log)
 t1,w1,a1,f1,k1,n1=map(int,m[0]);assert w1==t1+1500 and a1==t1+1800 and k1==2+(t1>=60) and n1==1,m
 print(f'PASS Stats screen from Settings: today {t1}s, last 7 days {w1}s, all time {a1}s, streak {k1} (seeded days), 1 book')
 assert 'reading stats reset' in log and log.count('reading stats reset')==1
 b,days=stats(d);assert list(days)==[] or all(v<5 for v in days.values()),days
 assert len(b)==1 and list(b.values())[0]['secs']<5,b
 print('PASS Reset needs a second tap (first tap only asks); after reset only the open book remains, with no time')
 # finished: a 3-page PDF read to the end
 from PIL import Image,ImageDraw
 pages=[Image.new('L',(1272,1696),255) for _ in range(3)]
 for i,im in enumerate(pages):ImageDraw.Draw(im).text((100,100),f'page {i+1}',fill=0)
 small=d/'three.pdf';pages[0].save(small,save_all=True,append_images=pages[1:])
 log=run(d,small,'wait 1200\ntap 1180 850\nwait 500\ntap 1180 850\nwait 500\ntap 640 100\nwait 300\nmenubtn 2 2\nwait 600\ntap 770 85\nwait 800\nshot st_finished\nquit\n')
 b,_=stats(d);s=b[fnv(str(small))];assert s['finished']>0 and s['pct']==100 and s['pages']==2,s
 assert re.findall(r'finished=(\d+)',log)[-1]=='1'
 print('PASS reaching the last page marks the book finished (books finished = 1)')
 # fast taps never exit
 run(d,BOOK,'wait 1200\n'+'tap 1180 850\nwait 60\n'*5+'tap 640 100\nwait 60\nmenubtn 2 2\nwait 80\ntap 770 85\nwait 60\ntap 1147 85\nwait 60\ntap 770 85\nwait 60\ntap 1147 85\nwait 800\nshot st_fast_alive\nquit\n')
 assert (d/'st_fast_alive.pgm').exists()
 print('PASS fast taps (page turns, Settings, Stats open/close) never exit')
 from PIL import Image
 out=R.parent/'stage'/'zr097-shots';out.mkdir(parents=True,exist_ok=True)
 for f in sorted(d.glob('st_*.pgm')):Image.open(f).save(out/(f.stem+'.png'))
