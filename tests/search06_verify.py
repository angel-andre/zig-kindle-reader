#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,json
from PIL import Image,ImageChops
R=Path(__file__).resolve().parent.parent;T=R/'tests';S=R/'shots';B=T/'tall-view-fixture.pdf'
rows=['1234567890','qwertyuiop','asdfghjkl',"zxcvbnm'-_"]
def type_query(q):
 s=''
 for c in q:
  if c==' ':x,y=640,1075
  else:
   row=next(i for i,r in enumerate(rows) if c in r);col=rows[row].index(c);x,y=70+col*113+51,500+row*130+55
  s+=f'tap {x} {y}\nwait 50\n'
 return s
with tempfile.TemporaryDirectory(prefix='search06-',dir=T) as tmp:
 d=Path(tmp);sim=d/'input.sim';sim.write_text('''wait 1200
tap 640 100
wait 300
menubtn 1 0
wait 500
tap 640 100
wait 300
menubtn 2 0
wait 300
shot 61_search_keyboard
'''+type_query('row 085')+'''tap 640 1355
wait 1200
shot 62_search_results
tap 640 490
wait 300
shot 63_search_hit_width
wait 2200
shot 64_search_hit_cleared
quit
''')
 p=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(d),'--idle-min','0',str(B)],cwd=R,capture_output=True,timeout=35);log=p.stderr.decode();assert p.returncode==0,log
 assert 'search complete: pages=2/2 hits=2 errors=0' in log,log
 st=json.loads(next((d/'state').glob('*.json')).read_text());assert st['page']==0 and st['view']==1 and st['view_step']>0,st
 assert 'render_errors=0' in log and not list((d/'notes').glob('*.json')),log
 before=Image.open(S/'63_search_hit_width.pgm');after=Image.open(S/'64_search_hit_cleared.pgm');diff=ImageChops.difference(before,after);bbox=diff.getbbox();assert bbox and bbox[1]>=0 and bbox[3]<=1696,bbox
 assert sum(x!=0 for x in diff.tobytes())>100,'temporary hit must be visibly highlighted'
 (T/'search06-ui.log').write_text(log)
 print('PASS real big-key query entry, exact two-page results, tap-to-jump preserves fit-width and scrolls to the hit; temporary highlight clears without saving a note')
for p in S.glob('6[1-4]_*.pgm'):
 im=Image.open(p);assert im.size==(1272,1696);im.save(p.with_suffix('.png'));im.thumbnail((636,848));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS search keyboard/results/hit/cleared device-resolution screenshots and previews')
