#!/usr/bin/env python3
"""v0.9.8 collections, favourites and size sort: library long-press menu, star, collection create/
rename/delete (books kept), filter All/Favourites/collection with sort kept, Size largest/smallest
persisted, re-attach after a '(N)' rename, fast taps, --version."""
from pathlib import Path
import subprocess,tempfile,re,shutil,json
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
KEYS=["1234567890","qwertyuiop","asdfghjkl","zxcvbnm'-_",".,?!;:()\"/"]
def key(ch):
 bw=(W-140)//10
 for r,row in enumerate(KEYS):
  if ch in row:c=row.index(ch);return (70+c*bw+(bw-10)//2,600+r*118+52)
def typed(s):return ''.join('tap %d %d\nwait 120\n'%key(c) for c in s)
SAVE='tap 1052 1372\nwait 900\n';CLEAR='tap 220 1372\nwait 200\n'
ROW=lambda i:330+i*150+75
def menu_btn(rows,i):h=140+rows*120;y=(H-h)//2;return y+110+i*120+50
def run(d,script):
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(d/'books'),'--idle-min','0'],capture_output=True,timeout=120)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'exit gesture' not in log and 'exiting' in log;return log
def views(log):return re.findall(r'library view: sort=([^ ]+(?: [^ ]+ [^ ]+)?) shown=(\d+): (.*)',log)
def coll(d):return (d/'data'/'state'/'collections.tsv').read_text()
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[8-9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
from PIL import Image,ImageDraw
with tempfile.TemporaryDirectory(dir=T,prefix='col098-') as t:
 d=Path(t);b=d/'books';b.mkdir();(d/'data').mkdir()
 shutil.copy(T/'fixture.epub',b/'Alpha.epub');shutil.copy(T/'fixture.epub',b/'Alpha (2).epub');shutil.copy(T/'tall-view-fixture.pdf',b/'Beta.pdf')
 pages=[Image.new('L',(400,600),255) for _ in range(2)];ImageDraw.Draw(pages[0]).text((20,20),'gamma',fill=0);pages[0].save(b/'Gamma.pdf',save_all=True,append_images=pages[1:])
 sizes={p.stem:p.stat().st_size for p in b.iterdir()};before=sorted((p.name,p.stat().st_size) for p in b.iterdir())
 log=run(d,f'''wait 1500
shot col_library
long 636 {ROW(0)}
wait 500
shot col_book_menu
tap 636 {menu_btn(3,0)}
wait 600
long 636 {ROW(0)}
wait 500
tap 636 {menu_btn(3,1)}
wait 500
shot col_add_menu
tap 636 {menu_btn(2,0)}
wait 700
'''+typed('classics')+'shot col_name_editor\n'+SAVE+f'''long 636 {ROW(1)}
wait 500
tap 636 {menu_btn(3,1)}
wait 500
tap 636 {menu_btn(3,0)}
wait 800
shot col_starred
tap 630 262
wait 700
shot col_picker
tap 636 {ROW(2)}
wait 800
shot col_fav_filter
tap 630 262
wait 700
tap 636 {ROW(3)}
wait 800
tap 250 262
wait 500
tap 250 262
wait 500
tap 250 262
wait 800
shot col_coll_size_largest
tap 630 262
wait 700
tap 636 {ROW(0)}
wait 800
shot col_all_size_largest
tap 250 262
wait 800
shot col_all_size_smallest
tap 250 262
wait 500
tap 250 262
wait 500
tap 250 262
wait 500
tap 250 262
wait 800
quit
''')
 c=coll(d);assert 'c\tClassics\n' in c and f'm\t*\t{sizes["Alpha"]}\t{b}/Alpha.epub\n' in c and f'm\t0\t{sizes["Alpha"]}\t{b}/Alpha.epub\n' in c and f'm\t0\t{sizes["Alpha (2)"]}\t{b}/Alpha (2).epub\n' in c,c
 vs=views(log)
 assert any(s=='Recent' and n=='1' and o=='Alpha' for s,n,o in vs),vs
 assert any(n=='2' and o=='Alpha | Alpha (2)' for s,n,o in vs),vs
 big=sorted(sizes,key=lambda k:(-sizes[k],k.lower()));small=sorted(sizes,key=lambda k:(sizes[k],k.lower()))
 assert ('Size: largest first','4',' | '.join(big)) in vs and ('Size: smallest first','4',' | '.join(small)) in vs,(vs,big,small)
 assert ('Size: largest first','2','Alpha | Alpha (2)') in vs,vs
 assert json.loads((d/'data'/'ui07.json').read_text())['sort']==3
 print('PASS long-press book -> Favourite / Add to collection (new "Classics" via keyboard); star drawn; filter All/Favourites/collection')
 print(f'PASS Size: largest first {big} and smallest first {small}; sort kept inside the collection filter; choice saved (sort cycled back to largest)')
 # restart: sort persisted; a '(N)' rename re-attaches; rename + delete collection keeps books
 (b/'Alpha.epub').rename(b/'Alpha (3).epub')
 log=run(d,f'''wait 1500
shot col_restart
tap 630 262
wait 700
long 636 {ROW(3)}
wait 500
shot col_coll_menu
tap 636 {menu_btn(3,0)}
wait 700
'''+CLEAR+typed('keep')+SAVE+f'''tap 630 262
wait 700
shot col_picker_renamed
long 636 {ROW(3)}
wait 500
tap 636 {menu_btn(3,1)}
wait 500
shot col_delete_confirm
tap 636 {menu_btn(2,0)}
wait 800
shot col_after_delete
quit
''')
 vs=views(log);assert vs[0][0]=='Size: largest first',vs[0]
 assert 're-attached a moved book' in log
 c=coll(d);assert 'c\t' not in c and f'm\t*\t{sizes["Alpha"]}\t{b}/Alpha (3).epub\n' in c and 'm\t0' not in c,c
 assert sorted((p.name,p.stat().st_size) for p in b.iterdir())==sorted([('Alpha (3).epub',sizes['Alpha'])]+[x for x in before if x[0]!='Alpha.epub'])
 print('PASS restart keeps Size sort; renamed "Alpha (3).epub" keeps its star; collection renamed then deleted, all 4 books still on disk')
 # fast taps never exit
 log=run(d,f'wait 1500\n'+'tap 250 262\nwait 60\n'*3+f'tap 630 262\nwait 60\ntap 630 262\nwait 60\nlong 636 {ROW(0)}\nwait 80\ntap 636 {menu_btn(4,3)}\nwait 60\ntap 1180 1600\nwait 60\ntap 100 1600\nwait 800\nshot col_fast_alive\nquit\n')
 assert (d/'col_fast_alive.pgm').exists()
 m=re.search(r'library: (\d+) books',log);assert m and m[1]=='4'
 print('PASS fast taps (sort, filter, menu) never exit; library loads 4 books')
 out=R.parent/'stage'/'zr098-shots';out.mkdir(parents=True,exist_ok=True)
 for f in sorted(d.glob('col_*.pgm')):Image.open(f).save(out/(f.stem+'.png'))
