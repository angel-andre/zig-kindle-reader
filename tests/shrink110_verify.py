#!/usr/bin/env python3
"""v0.11.0 Shrink for Kindle: library menu -> shrink (progress, stray taps ignored) -> before/after ->
Use smaller copy (original moved to DATA/originals/, book replaced in place, state kept) ->
Delete originals with confirm; under-10% result keeps the original; --version."""
from pathlib import Path
import subprocess,tempfile,re,json,random
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
ROW=lambda i:330+i*150+75
def menu_btn(rows,i):h=140+rows*120;y=(H-h)//2;return y+110+i*120+50
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def run(d,script,book=None):
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(d/'books'),'--idle-min','0']+([str(book)] if book else []),capture_output=True,timeout=180)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'exit gesture' not in log;return log
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",sorted(T.glob('package1[0-9][0-9].py'))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
from PIL import Image
with tempfile.TemporaryDirectory(dir=T,prefix='shrink110-') as t:
 d=Path(t);b=d/'books';b.mkdir();(d/'data'/'state').mkdir(parents=True)
 random.seed(1);pages=[]
 for k in range(3):
  im=Image.effect_noise((2480,3508),40).convert('RGB');im=Image.merge('RGB',[im.split()[0],im.split()[1].point(lambda x:255-x),im.split()[2]]);pages.append(im)
 book=b/'Photo.pdf';pages[0].save(book,save_all=True,append_images=pages[1:],resolution=300,quality=95)
 before=book.stat().st_size;st=d/'data'/'state'/f'{fnv(str(book))}.json';st.write_text(json.dumps(dict(page=2)))
 log=run(d,f'''wait 1500
long 636 {ROW(0)}
wait 500
shot shr_menu
tap 636 {menu_btn(5,2)}
wait 150
tap 1200 200
wait 40
tap 1200 200
wait 40
tap 60 1600
wait 300
shot shr_running
wait 6000
shot shr_done
tap 636 {menu_btn(2,0)}
wait 1500
shot shr_used
long 636 {ROW(0)}
wait 500
shot shr_menu2
tap 636 {menu_btn(6,3)}
wait 400
shot shr_confirm
tap 636 {menu_btn(2,0)}
wait 800
quit
''')
 after=book.stat().st_size;orig=list((d/'data'/'originals').rglob('*')) if (d/'data'/'originals').exists() else []
 assert after<before*0.9,(before,after)
 assert not any(p.is_file() for p in orig),orig
 assert not list(b.glob('*.shrink-tmp'))
 assert json.loads(st.read_text()).get('page')==2
 print(f'PASS shrink in the library: {before/1e6:.1f} MB -> {after/1e6:.1f} MB, stray taps ignored, book replaced in place, no temp left, state kept (page 3), originals deleted after confirm')
 import shutil
 assert subprocess.run(['pdfinfo',str(book)],capture_output=True).returncode==0
 log=run(d,'wait 1500\nquit\n',book=book);assert 'pages=3' in log and 'start=3' in log,log[-800:]
 print('PASS replaced PDF opens with 3 pages at the saved page')
