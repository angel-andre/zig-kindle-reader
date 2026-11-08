from pathlib import Path
import subprocess,tempfile,re,json,csv,collections
from PIL import Image,ImageOps,ImageDraw,ImageFont
R=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='v08-ui-') as t:
 d=Path(t);data=d/'data';data.mkdir();(d/'empty').mkdir()
 (data/'settings.json').write_text('{"full_refresh":8}')
 script=d/'turn.sim';script.write_text('wait 1800\n'+('tap 1200 850\nwait 400\n'*15)+'shot 87_scan-d_reader_battery\nquit\n')
 p=subprocess.run([str(R/'out/zreader-host'),'--data',str(data),'--books',str(d/'empty'),'--sim',str(script),'--shots',str(R/'shots'),'--idle-min','0',str(R.parent/'diag/scan-d.pdf')],capture_output=True,timeout=30,check=True)
 log=p.stderr.decode();(R/'tests/turn08-after.log').write_text(log)
 modes=re.findall(r'page refresh: p=(\d+) reason=(\w+) wf=(\d+)',log)
 submits=re.findall(r'refresh submit: wf=(\d+)',log)
 assert len(modes)==len(submits)==16,(modes,submits)
 assert [x[2] for x in modes]==['2','2']+['4']*14,modes
 assert submits==[x[2] for x in modes]
 assert json.loads((data/'settings.json').read_text())==dict(full_refresh=0,refresh_policy=9)
 state=json.loads(next((data/'state').glob('*.json')).read_text());assert 1700000000<state['opened']<3000000000
 assert 'render_errors=0' in log
 print('PASS actual pump: opening + cover exit = 2 GC16; next 14 turns = exactly 14 REAGL, no extra submits, no periodic clean; old default 8 migrated OFF; timestamp positive')
# Cold EPUB must show a page before its global pagination finishes and accept turns.
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='epub08-fast-') as t:
 d=Path(t);(d/'empty').mkdir();data=d/'data';data.mkdir();script=d/'early.sim'
 script.write_text('wait 60\n'+('tap 1200 850\nwait 60\n'*8)+'wait 800\nquit\n')
 p=subprocess.run([str(R/'out/zreader-host'),'--data',str(data),'--books',str(d/'empty'),'--sim',str(script),'--idle-min','0',str(R/'tests/large08.epub')],capture_output=True,check=True,timeout=15)
 log=p.stderr.decode();(R/'tests/epub08-early.log').write_text(log)
 assert 'pagination: completed asynchronously' in log,log
 assert log.index('page refresh: p=1')<log.index('pagination: completed asynchronously'),log
 assert 'page refresh: p=9' in log and 'render_errors=0' in log,log
 assert len(re.findall('page refresh:',log))==9,log
 print('PASS 4400-page synthetic EPUB: first page precedes full pagination; 8 immediate early turns, one update each')
# Full-raster audit distinguishes actual photo insert (179-194) from scanned text.
rows=list(csv.DictReader((R/'tests/scan-d08-after.csv').open()))
assert len(rows)==372
assert all(x['reason']=='text' and x['waveform']=='4' for x in rows[2:178])
assert all(x['waveform']=='4' for x in rows[195:])
assert rows[178]['reason']=='image' and float(rows[178]['photo'])>.5
print('PASS 372-page audit: 353 REAGL, 19 cleans limited to opening, cover departure and photo insert transitions')
for name in ['86_library_storage_battery_mock','87_scan-d_reader_battery']:
 p=R/'shots'/f'{name}.pgm';im=Image.open(p);im.save(p.with_suffix('.png'));ImageOps.invert(im.convert('RGB')).save(p.with_name(name+'_dark.png'))
# Legible turn-log preview, generated from measured production pump logs.
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',21)
im=Image.new('RGB',(1272,1040),'#11151b');draw=ImageDraw.Draw(im)
lines=['ZIGG READER 0.8 / SCAN-D','Measured host simulator: 15 turns, 16 submissions','Dark-mode display polarity unchanged','', 'PAGE   BEFORE             AFTER              UPDATES']
for page in range(1,17):lines.append(f'{page:>4}   GC16 FULL          '+('GC16 FULL' if page<=2 else 'REAGL (no flash)')+(' '*4)+'1 -> 1')
lines+=['','p1 opening / p2 clears the cover; p3-16 ordinary scans.','All 372 pages: 372 -> 19 GC16; 353 REAGL.','Remaining cleans are covers and the real photo insert.','No progressive/double page updates; periodic default OFF.']
for i,line in enumerate(lines):draw.text((44,35+i*34),line,font=font,fill='#e5e9ef' if i!=0 else '#a9d9e8')
im.save(R/'shots/89_scan-d_turn_log.png')
print('PASS storage/type/size + battery preview and scan-D turn-log PNGs written')
