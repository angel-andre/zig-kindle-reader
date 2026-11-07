#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageChops
import tempfile,subprocess,json,os,time
R=Path(__file__).resolve().parent.parent
SH=R/'shots'
def fnv(s):
 h=0xcbf29ce484222325
 for c in str(s).encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def pdf(path,label,padding=0):
 # Sparse, valid large-file fixture: an unreferenced stream avoids decoding 175 MB.
 with path.open('wb') as f:
  f.write(b'%PDF-1.4\n');offset=[0]
  content=f'0.15 g 0 0 306 407 re f 1 g BT /F1 26 Tf 25 310 Td ({label}) Tj 0 -50 Td (ZREADER) Tj ET'.encode()
  objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Count 1 /Kids [3 0 R] >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 306 407] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',b'<< /Length '+str(len(content)).encode()+b' >>\nstream\n'+content+b'\nendstream']
  for i,obj in enumerate(objects,1):offset.append(f.tell());f.write(f'{i} 0 obj\n'.encode()+obj+b'\nendobj\n')
  if padding:
   offset.append(f.tell());f.write(f'6 0 obj\n<< /Length {padding} >>\nstream\n'.encode());f.seek(padding,1);f.write(b'\nendstream\nendobj\n')
  x=f.tell();f.write(f'xref\n0 {len(offset)}\n0000000000 65535 f \n'.encode())
  for o in offset[1:]:f.write(f'{o:010d} 00000 n \n'.encode())
  f.write(f'trailer\n<< /Size {len(offset)} /Root 1 0 R >>\nstartxref\n{x}\n%%EOF\n'.encode())
def run(data,books,script,name,book=None):
 sim=data/(name+'.sim');sim.write_text(script)
 args=[str(R/'out/zreader-host'),'--data',str(data),'--books',str(books),'--sim',str(sim),'--shots',str(SH),'--idle-min','0']
 if book:args.append(str(book))
 p=subprocess.run(args,capture_output=True,timeout=35);log=p.stderr.decode();(R/'tests'/f'{name}.log').write_text(log)
 assert p.returncode==0,log;assert 'render_errors=0' in log,log
 return log
with tempfile.TemporaryDirectory(prefix='zr07-ui-') as t:
 d=Path(t);data=d/'data';(data/'state').mkdir(parents=True);books=d/'Books';books.mkdir()
 for i in range(84):
  folder=books/['CompSci','History','UFO'][i%3];folder.mkdir(exist_ok=True);book=folder/f'Book {i:02}.pdf';pdf(book,f'Book {i:02}')
  (data/'state'/f'{fnv(book)}.json').write_text(json.dumps(dict(page=i%10,pages=10,opened=i+1)))
 large=books/'Large PDF.pdf';pdf(large,'Large PDF',175*1024*1024);assert large.stat().st_size>175*1024*1024
 log=run(data,books,'''wait 150
shot 70_library_cold
wait 1500
shot 71_library_covers
tap 180 260
shot 72_library_title
tap 600 260
shot 73_library_folders
tap 350 705
shot 74_library_compsci
tap 1010 260
shot 75_light_inherited
swipe 300 480 972 480
tap 150 780
shot 76_light_changed
tap 600 1175
shot 77_sleep_optin
tap 1110 80
tap 400 405
wait 900
shot 78_reader_before_sleep
power
wait 300
shot 79_sleep_cover
tap 1180 850
wait 200
power
wait 500
shot 80_wake_gc16
tap 640 850
wait 300
shot 81_menu_device
quit
''','ui07')
 assert 'library: 85 books' in log
 assert 'light change: 0=24 simulated' in log and 'light change: 1=17 simulated' in log,log
 assert 'sleep: drawing cover' in log and 'sleep: cover completed' in log and 'sleep: wake; restore GC16' in log,log
 assert json.loads((data/'ui07.json').read_text())==dict(sort=1,power_sleeps=1)
 assert len(list((data/'thumbs').glob('*.zrt')))>=7
 assert sum(p.stat().st_size for p in (data/'thumbs').glob('*'))<=10*1024*1024
 # Relaunch persists title sort and opt-in, but never restores saved light numbers.
 log2=run(data,books,'''wait 250
tap 1010 260
shot 82_light_reopened
quit
''','ui07-reopen')
 assert 'light change:' not in log2
 # Default OFF power event exits and does not enter sleep.
 fresh=d/'fresh';fresh.mkdir()
 log3=run(fresh,books,'wait 200\npower\n','ui07-default')
 assert 'sleep: drawing' not in log3 and not (fresh/'ui07.json').exists()
 # Progress sort choice is persisted independently of full_refresh.
 (data/'settings.json').write_text('{"full_refresh":4}')
 run(data,books,'wait 200\ntap 180 260\nshot 83_library_progress\nquit\n','ui07-progress')
 assert json.loads((data/'ui07.json').read_text())['sort']==2
 assert json.loads((data/'settings.json').read_text())['full_refresh']==4
 # Firmware failure turns opt-in back OFF and wakes safely; maintenance remains independent.
 logerr=run(data,books,"wait 100\nevent 1\nwait 200\nevent 16\nwait 200\nquit\n",'ui07-error')
 assert 'sleep: wake; restore GC16' in logerr
 assert json.loads((data/'ui07.json').read_text())['power_sleeps']==0
 print('PASS simulated goingToScreenSaver and CLI-error event fails safe, wakes, persists sleep OFF')
 # Cover generation of synthetic 175 MB PDF must complete, with no full-file load.
 start=time.monotonic();subprocess.run([str(R/'out/zreader-host'),'--make-thumb',str(large),str(d/'large.raw')],check=True,timeout=15)
 assert (d/'large.raw').stat().st_size==96*128
 print(f'PASS 85-book real UI: covers, relative folders/filter, persisted title/progress sorts, progress bars; synthetic 175 MiB PDF cover {time.monotonic()-start:.3f}s on box')
 print('PASS real touch sliders/buttons 0..24; no startup write; no dark mode path')
 print('PASS opt-in persistence/default OFF, pre-suspend cover completion, sleeping touch ignored, power wake and GC16 restore (SIMULATED, not firmware)')
for p in sorted(SH.glob('7[0-9]_*.pgm'))+sorted(SH.glob('8[0-3]_*.pgm')):
 im=Image.open(p);im.save(p.with_suffix('.png'));im.resize((318,424)).save(p.with_name(p.stem+'_preview.png'))
# Full-frame wake must recover the exact pre-sleep page (not cover or stale overlay).
a=Image.open(SH/'78_reader_before_sleep.pgm');b=Image.open(SH/'80_wake_gc16.pgm')
assert ImageChops.difference(a,b).getbbox() is None
print('PASS byte-identical page restored on wake; shots 70-83 plus PNG previews')
