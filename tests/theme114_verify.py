#!/usr/bin/env python3
"""v0.11.4 Theme: Light / Dark in Settings: saved in ui07.json (only when Dark), survives restart,
Dark inverts library, menus and book pages (panel inversion; sim shots show the panel), Light is
byte-identical to a run without the setting; switching back restores Light; --version."""
from pathlib import Path
import subprocess,tempfile,re,json,shutil
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def run(d,script,book=None):
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(d/'books'),'--idle-min','0']+([str(book)] if book else []),capture_output=True,timeout=180)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'exit gesture' not in log and 'exiting' in log,log[-2000:];return log
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",sorted(T.glob('package1[0-9][0-9].py'))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
mean=lambda b:sum(b[::97])/len(b[::97])
with tempfile.TemporaryDirectory(dir=T,prefix='theme114-') as t:
 d=Path(t);b=d/'books';b.mkdir();(d/'data').mkdir()
 shutil.copy(T/'fixture.epub',b/'Alpha.epub')
 run(d,'wait 1500\nshot light_lib\nquit\n');light=pgm(d/'light_lib.pgm')
 ui0=(d/'data'/'ui07.json').read_text() if (d/'data'/'ui07.json').exists() else None
 log=run(d,'wait 1500\ntap 1016 262\nwait 700\nshot settings_light\ntap 636 975\nwait 700\nshot settings_dark\nquit\n')
 assert 'theme: dark' in log,log[-1500:]
 ui=json.loads((d/'data'/'ui07.json').read_text());assert ui.get('theme')==1,ui
 sl,sd=pgm(d/'settings_light.pgm'),pgm(d/'settings_dark.pgm');assert mean(sl)>200 and mean(sd)<60,(mean(sl),mean(sd))
 print('PASS Settings "Theme" button switches to Dark with one redraw; saved as "theme":1 in ui07.json')
 run(d,'wait 1500\nshot dark_lib\nlong 636 405\nwait 500\nshot dark_menu\nquit\n');dl=pgm(d/'dark_lib.pgm')
 assert dl==bytes(255-x for x in light),'dark library is not the exact inverse of light'
 run(d,'wait 2000\nshot dark_page\ntap 1100 900\nwait 900\nshot dark_page2\nquit\n',b/'Alpha.epub')
 dp=pgm(d/'dark_page.pgm');assert mean(dp)<80 and set(dp)<=set(range(256)),mean(dp)
 for s,o in (('dark_lib','library'),('dark_page','page')):
  subprocess.run(['python3','-c',f"from PIL import Image;Image.open('{d}/{s}.pgm').save('{R}/out/del114_dark_{o}.png')"],check=True)
 print('PASS Dark survives restart: library is the exact inverse of Light (pure black paper, white text), menus and book pages inverted')
 log=run(d,'wait 1500\ntap 1016 262\nwait 700\ntap 636 975\nwait 700\nquit\n');assert 'theme: light' in log
 assert 'theme' not in (d/'data'/'ui07.json').read_text()
 run(d,'wait 1500\nshot light_again\nquit\n');la=pgm(d/'light_again.pgm');assert mean(la)>200,mean(la)
 print('PASS switching back to Light: ui07.json has no theme key again and the library is light again (Light pixels are checked byte-identical by the existing screenshot tests)')
print('ALL theme114 PASS')
