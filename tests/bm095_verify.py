#!/usr/bin/env python3
"""v0.9.5 bookmarks: menu toggle, ribbon overlay, list screen (jump/delete), persistence,
EPUB path, byte-identical pages without bookmarks, --version matches the package."""
from pathlib import Path
import subprocess,tempfile,re
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host'
W,H=1272,1696
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def region(px,x0,y0,x1,y1):return [px[y*W+x] for y in range(y0,y1) for x in range(x0,x1)]
def run(d,book,script):
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(Path(book).parent),'--idle-min','0',str(book)],capture_output=True,timeout=90)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:]
 return log
# --version must match the package version
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
pkg=(T/'package095.py').read_text();m=re.search(r"VERSION\s*=\s*'([\d.]+)'",pkg)
assert m and v==f'zreader {m[1]}',(v,m and m[1]);print(f'PASS --version prints "{v}" = package version')
book=R.parent/'testbooks'/'digital-big.pdf'
with tempfile.TemporaryDirectory(dir=T,prefix='bm095-') as t:
 d=Path(t);(d/'data').mkdir()
 if not book.exists():
  from PIL import Image,ImageDraw
  pages=[]
  for i in range(4):
   im=Image.new('L',(1272,1696),255);ImageDraw.Draw(im).text((100,100+i*50),f'Page {i+1} sample text',fill=0);pages.append(im)
  book=d/'sample.pdf';pages[0].save(book,save_all=True,append_images=pages[1:])
 bmf=d/'data'/'state'/f'{fnv(str(book))}.bookmarks'
 # run 1: turn to page 2, bookmark via menu (PDF second row), open the list
 run(d,book,'''wait 1500
tap 1180 850
wait 900
tap 1180 850
wait 900
shot p2_plain
tap 640 100
wait 300
menubtn 1 2
wait 900
shot p2_ribbon
tap 640 100
wait 300
menubtn 2 3
wait 700
shot list1
tap 1147 85
wait 700
quit
''')
 lines=bmf.read_text().rstrip('\n').split('\n');f=lines[0].split('\t');print('  entry:',lines)
 assert len(lines)==1 and f[0]=='2' and (len(f[6])>=10 or book.name!='digital-big.pdf'),lines
 a=pgm(d/'p2_plain.pgm');b=pgm(d/'p2_ribbon.pgm')
 rib=region(b,W-90,4,W-58,60);assert sum(1 for p in rib if p<40)>=0.95*len(rib),'ribbon missing'
 notch=region(b,W-75,85,W-71,92);assert min(notch)>200,'ribbon notch not white'
 diff=[i for i in range(len(a)) if a[i]!=b[i]]
 assert diff and all(W-102<=i%W<W-49 and i//W<92 for i in diff),'ribbon changed pixels outside its box'
 print(f'PASS PDF menu "Bookmark" saved page 3 ({len(f[6])}-char snippet) and drew the ribbon in place ({len(diff)} px, top-right only)')
 lst=pgm(d/'list1.pgm');assert sum(1 for p in region(lst,70,240,700,330) if p<100)>200,'list row missing'
 # run 2: restart from page 1; bookmark survives; list tap jumps; long-press deletes; page is byte-identical again
 run(d,book,'''wait 1500
shot r_open
tap 100 850
wait 900
tap 640 100
wait 300
menubtn 2 3
wait 700
tap 636 295
wait 1200
shot r_jump
tap 640 100
wait 300
menubtn 2 3
wait 700
long 636 295
wait 900
shot r_empty
tap 1147 85
wait 1200
shot r_noribbon
quit
''')
 assert pgm(d/'r_open.pgm')==b,'restart did not reopen page 3 with ribbon'
 assert pgm(d/'r_jump.pgm')==b,'list tap did not jump to the bookmarked page'
 assert bmf.read_text().strip()=='','long-press did not delete'
 assert pgm(d/'r_noribbon.pgm')==a,'page not byte-identical after removing the bookmark'
 print('PASS bookmark survives restart; list tap jumps to it; long-press deletes; page is byte-identical again')
 # run 3: fast taps on the menu/list never exit; bookmark via the list toggle button
 run(d,book,'''wait 1500
tap 640 100
wait 80
menubtn 2 3
wait 80
tap 636 1484
wait 80
tap 636 1484
wait 80
tap 636 1484
wait 600
tap 1147 85
wait 80
tap 1180 850
wait 80
tap 1180 850
wait 900
shot fast_alive
quit
''')
 assert (d/'fast_alive.pgm').exists()
 assert [l.split('\t')[0] for l in bmf.read_text().strip().split('\n')]==['2'],bmf.read_text()
 print('PASS list "Bookmark page" button toggles (3 fast taps -> bookmarked); fast taps never exited')
ep=T/'anchor-fixture.epub'
if ep.exists():
 with tempfile.TemporaryDirectory(dir=T,prefix='bm095e-') as t:
  d=Path(t);(d/'data').mkdir();bmf=d/'data'/'state'/f'{fnv(str(ep))}.bookmarks'
  run(d,ep,'''wait 1500
tap 1180 850
wait 900
shot e_plain
tap 640 100
wait 300
menubtn 2 3
wait 700
shot e_list0
tap 636 1484
wait 700
shot e_list1
tap 1147 85
wait 1200
shot e_ribbon
quit
''')
  f=bmf.read_text().strip().split('\t');assert f[0]=='1' and int(f[2])>=0 and f[5]!='0',f
  a=pgm(d/'e_plain.pgm');b=pgm(d/'e_ribbon.pgm');diff=[i for i in range(len(a)) if a[i]!=b[i]]
  assert diff and all(W-102<=i%W<W-49 and i//W<92 for i in diff)
  run(d,ep,'wait 1800\nshot e_reopen\nquit\n');assert pgm(d/'e_reopen.pgm')==b
  print(f'PASS EPUB: bookmark from the Bookmarks screen, stored with anchor, snippet "{f[6][:40]}", ribbon only; survives reopen')
