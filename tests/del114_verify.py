#!/usr/bin/env python3
"""v0.11.4 Delete book: library long-press -> Delete book -> confirm (Cancel first; fast taps ignored,
never exit) -> Delete: notes exported to DATA/export first, book file + state removed, other books
untouched, collections/last_book cleaned; refuses paths outside the books root and symlinks; --version."""
from pathlib import Path
import subprocess,tempfile,re,json,shutil,os
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
MU=R.parent/'mupdf-1.28.6-source'
ROW=lambda i:330+i*150+75
def menu_btn(rows,i):h=140+rows*120;y=(H-h)//2;return y+110+i*120+50
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def run(d,script):
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(d/'books'),'--idle-min','0'],capture_output=True,timeout=180)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'exit gesture' not in log and 'exiting' in log,log[-2000:];return log
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",sorted(T.glob('package1[0-9][0-9].py'))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
with tempfile.TemporaryDirectory(dir=T,prefix='del114-') as t:
 d=Path(t);b=d/'books';b.mkdir();(d/'data'/'state').mkdir(parents=True);(d/'data'/'notes').mkdir()
 books=[b/'Alpha.epub',b/'Beta.epub']
 for k in books:
  shutil.copy(T/'fixture.epub',k)
  (d/'data'/'state'/f'{fnv(str(k))}.json').write_text(json.dumps(dict(page=1,opened=1000+len(k.stem))))
  (d/'data'/'notes'/f'{k.stem}.json').write_text(json.dumps([dict(text=f'quote from {k.stem}',page=1,style='note')]))
 states={k:(d/'data'/'state'/f'{fnv(str(k))}.json').read_text() for k in books}
 (d/'data'/'state'/'collections.tsv').write_text('zrcoll\t1\nc\tShelf\n'+''.join(f'm\t*\t{k.stat().st_size}\t{k}\nm\t0\t{k.stat().st_size}\t{k}\n' for k in books))
 # 1. menu, confirm, fast taps on Delete, Cancel: nothing deleted, no exit
 run(d,f'''wait 1500
long 636 {ROW(0)}
wait 500
shot menu
tap 636 {menu_btn(5,3)}
wait 400
shot confirm
tap 636 {menu_btn(2,1)}
wait 40
tap 636 {menu_btn(2,1)}
wait 40
tap 636 {menu_btn(2,1)}
wait 300
shot fast
wait 1200
tap 636 {menu_btn(2,0)}
wait 400
quit
''')
 for s in ('menu','confirm'):
  subprocess.run(['python3','-c',f"from PIL import Image;Image.open('{d}/{s}.pgm').save('{R}/out/del114_{s}.png')"],check=True)
 assert all(k.exists() for k in books),[k.exists() for k in books]; assert not list((d/'data').glob('export/*.md')),list((d/'data').glob('export/*'))
 assert all((d/'data'/'state'/f'{fnv(str(k))}.json').read_text()==states[k] for k in books)
 print('PASS long-press menu has "Delete book"; confirm shows Cancel first; 3 fast taps on Delete (within 1 s) and Cancel delete nothing and never exit')
 # 2. real delete
 log=run(d,f'''wait 1500
long 636 {ROW(0)}
wait 500
tap 636 {menu_btn(5,3)}
wait 1300
tap 636 {menu_btn(2,1)}
wait 800
shot after
quit
''')
 gone=[k for k in books if not k.exists()];kept=[k for k in books if k.exists()]
 assert len(gone)==1 and len(kept)==1,(gone,kept);g=gone[0];kp=kept[0]
 ex=d/'data'/'export'/f'{g.stem}.md';assert ex.exists() and f'quote from {g.stem}' in ex.read_text(),list((d/'data').rglob('*'))
 assert not (d/'data'/'state'/f'{fnv(str(g))}.json').exists()
 assert (d/'data'/'state'/f'{fnv(str(kp))}.json').read_text()==states[kp] and (d/'data'/'notes'/f'{kp.stem}.json').exists()
 col=(d/'data'/'state'/'collections.tsv').read_text();assert str(g) not in col and col.count(str(kp))==2,col
 assert 'deleted book:' in log and 'library: 1 books' in log,log[-1500:]
 print(f'PASS Delete: notes exported to export/{g.stem}.md first, book + state removed, collections cleaned, other book state/notes/collections untouched, library refreshed')
 # 3. path safety (C helper)
 subprocess.run([str(R.parent/'zig/zig'),'cc','-target','x86_64-linux-musl','-O2','-I',str(MU/'include'),str(T/'del114_probe.c'),str(R/'src/shrink.c'),str(MU/'build/hostmusl-release/libmupdf.a'),str(MU/'build/hostmusl-release/libmupdf-third.a'),'-static','-lpthread','-lm','-o',str(R/'out/del114-probe')],check=True)
 pr=lambda root,p:int(subprocess.run([str(R/'out/del114-probe'),str(root),str(p)],capture_output=True,text=True).stdout)
 out=d/'outside';out.mkdir();o=out/'Out.epub';shutil.copy(T/'fixture.epub',o)
 (b/'Link.epub').symlink_to(o);sub=b/'sub';sub.symlink_to(out,target_is_directory=True)
 assert pr(b,o)==-1 and pr(b,b/'Link.epub')==-1 and pr(b,sub/'Out.epub')==-1 and pr(b,b/'..'/'outside'/'Out.epub')==-1 and pr(b,b/'nope.epub')==-1 and o.exists()
 assert pr(b,kp)==0 and not kp.exists()
 print('PASS refuses files outside the books root, symlinked files, symlinked folders and ../ escapes; deletes a real file inside')
print('ALL del114 PASS')
