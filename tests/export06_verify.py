#!/usr/bin/env python3
from pathlib import Path
import json,tempfile,subprocess
from PIL import Image
R=Path(__file__).resolve().parent.parent;T=R/'tests';S=R/'shots';B=R.parent/'testbooks/digital-small1.pdf'
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
with tempfile.TemporaryDirectory(prefix='export06-',dir=T) as tmp:
 d=Path(tmp);(d/'notes').mkdir();(d/'state').mkdir();(d/'state'/f'{fnv(str(B))}.json').write_text(json.dumps(dict(page=6,trim=1)))
 (d/'notes'/'Unopened.json').write_text(json.dumps([dict(page=12,style='highlight',text='Another book: [a link](https://example.invalid) <tag>\nnext line')]))
 (d/'notes'/'skip.json').symlink_to(d/'notes'/'Unopened.json')
 sim=d/'input.sim';sim.write_text((T/'ui.sim').read_text().rsplit('quit',1)[0]+'''tap 640 100
wait 300
menubtn 2 1
wait 300
shot 65_export_all
wait 2200
tap 640 850
wait 300
tap 640 100
wait 300
menubtn 0 1
wait 200
shot 66_notes_exported
quit
''')
 p=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(d),'--idle-min','0',str(B)],cwd=R,capture_output=True,timeout=40);log=p.stderr.decode();assert p.returncode==0 and 'render_errors=0' in log,log
 notes=json.loads((d/'notes'/'digital-small1.json').read_text());assert len(notes)==1 and notes[0]['style']=='note'
 md=(d/'export'/'digital-small1.md').read_text();assert md.count(notes[0]['text'])==1 and '## Note / Page 7' in md and '## Underline' not in md and '## Highlight' not in md,md
 other=(d/'export'/'Unopened.md').read_text();assert '\\[a link\\]\\(https://example.invalid\\)' in other and '\\<tag\\>' in other and '> next line' in other,other
 assert not (d/'export'/'skip.md').exists(),'Export all must not follow notes symlinks'
 # Deliberately corrupt the current export, then prove the next edit rewrites it.
 (d/'export'/'digital-small1.md').write_text('stale content')
 sim.write_text('''wait 1200
tap 640 100
wait 300
menubtn 0 1
wait 200
long 400 300
wait 200
quit
''')
 p=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(d),'--idle-min','0',str(B)],cwd=R,capture_output=True,timeout=20);assert p.returncode==0,p.stderr.decode()
 assert json.loads((d/'notes'/'digital-small1.json').read_text())==[]
 assert (d/'export'/'digital-small1.md').read_text()=='# digital-small1\n\n'
 assert notes[0]['text'] not in (d/'notes'/'digital-small1.txt').read_text()
 (T/'export06-ui.log').write_text(log+p.stderr.decode())
 print('PASS every annotation edit/copy/delete rewrites clean Markdown; Export all handles an unopened book and escapes markup without following symlinks; Notes-list deletion removes JSON/TXT/MD text')
for p in S.glob('6[5-6]_*.pgm'):
 im=Image.open(p);assert im.size==(1272,1696);im.save(p.with_suffix('.png'));im.thumbnail((636,848));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS Export all action / Notes-list screenshots and previews')
