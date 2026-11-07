#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,tempfile
from PIL import Image
R=Path(__file__).resolve().parent.parent;T=R/'tests';S=R/'shots';B=R.parent/'testbooks/digital-small1.pdf'
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
with tempfile.TemporaryDirectory(prefix='dictionary06-',dir=T) as tmp:
 d=Path(tmp);(d/'state').mkdir();state=d/'state'/f'{fnv(str(B))}.json';state.write_text(json.dumps(dict(page=6,trim=1)))
 p=subprocess.run([str(R/'out/render-probe'),str(B),'7',str(d/'reference.pgm')],check=True,capture_output=True)
 rows=[s.split('\t') for s in p.stdout.decode().splitlines() if '\t' in s];word=next(w for w in rows if w[-1]=='walk');x,y=map(int,word[6:8])
 def run(script,path):
  sim=d/'input.sim';sim.write_text(script)
  p=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(d),'--dictionary',str(path),'--idle-min','0',str(B)],cwd=R,capture_output=True,timeout=30)
  assert p.returncode==0,p.stderr.decode();assert 'render_errors=0' in p.stderr.decode(),p.stderr.decode();return p.stderr.decode()
 log=run(f'''wait 1200
long {x} {y}
wait 200
shot 55_dictionary_selection
popup 4
wait 500
shot 56_dictionary_definition
tap 1092 1586
wait 200
shot 57_dictionary_more
swipe 1100 900 300 900
wait 200
shot 58_dictionary_still
tap 1092 240
wait 200
shot 59_dictionary_closed
quit
''',R/'dictionary/wordnet.zdict')
 assert 'dictionary: walk, result=' in log and 'result=-1' not in log and 'result=0' not in log,log
 assert 'turns=0' in log and json.loads(state.read_text())['page']==6,log
 assert not list((d/'notes').glob('*.json')),'Define must not create an annotation'
 a=Image.open(S/'56_dictionary_definition.pgm');b=Image.open(S/'57_dictionary_more.pgm');c=Image.open(S/'58_dictionary_still.pgm')
 assert a.tobytes()!=b.tobytes(),'Next must show additional senses'
 assert b.tobytes()==c.tobytes(),'A swipe over modal must not pan/turn the book underneath'
 restored=Image.open(S/'59_dictionary_closed.pgm');reference=Image.open(d/'reference.pgm')
 # v0.8 deliberately overlays the read-only battery HUD; all book pixels outside it must remain exact.
 reference.paste(restored.crop((1059,0,1264,38)),(1059,0))
 assert restored.tobytes()==reference.tobytes(),'Closing restores clean book raster outside battery HUD'
 log+=run(f'''wait 1000
long {x} {y}
wait 150
popup 4
wait 300
shot 60_dictionary_missing
tap 1092 240
wait 200
quit
''',d/'not-installed.zdict')
 assert 'result=-1' in log
 (T/'dictionary06-ui.log').write_text(log)
 print('PASS physical single-word long press -> Define; English definition, Next senses, isolated modal swipes, exact page restoration and no notes/page-turn side effects')
 print('PASS absent dictionary shows actionable offline error and closes safely')
for p in list(S.glob('5[5-9]_*.pgm'))+list(S.glob('60_*.pgm')):
 im=Image.open(p);assert im.size==(1272,1696);im.save(p.with_suffix('.png'));im.thumbnail((636,848));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS dictionary selection/panel/pagination/closed/missing screenshots and small previews')
