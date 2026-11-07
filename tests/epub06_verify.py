#!/usr/bin/env python3
"""Real-input EPUB migration, typography, annotation and reopen integration."""
from pathlib import Path
import subprocess,json,tempfile
from PIL import Image
R=Path(__file__).resolve().parent.parent;T=R/'tests';S=R/'shots';B=T/'anchor-fixture.epub'
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def dump(font,space,margin,styled,page):
 p=subprocess.run([str(R/'out/epub-dump'),str(B),str(font),str(space),str(margin),str(int(styled)),str(page)],capture_output=True,check=True)
 rows=p.stdout.decode().splitlines();meta=rows.pop(0).split('\t');bounds=list(map(float,meta[2:]));words=[]
 for row in rows:
  c=row.split('\t',10);words.append(dict(i=int(c[0]),q=list(map(float,c[1:5])),line=int(c[5]),chapter=int(c[6]),start=int(c[7]),end=int(c[8]),hash=c[9],text=c[10]))
 return bounds,words
def anchor(w,last=None):
 return dict(anchor_version=1,anchor_chapter=w['chapter'],anchor_start=w['start'],anchor_end=(last or w)['end'],anchor_hash=w['hash'])
def center(bounds,w):
 x0,y0,x1,y1=bounds;s=min(1272/(x1-x0),1696/(y1-y0));ox=(1272-(x1-x0)*s)/2-x0*s;oy=(1696-(y1-y0)*s)/2-y0*s
 q=w['q'];return round((q[0]+q[2])/2*s+ox),round((q[1]+q[3])/2*s+oy)
def run(data,script):
 sim=data/'touch.sim';sim.write_text(script)
 p=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(data),'--books',str(T),'--idle-min','0',str(B)],cwd=R,capture_output=True,timeout=45)
 assert p.returncode==0,p.stderr.decode();log=p.stderr.decode();assert 'render_errors=0' in log,log
 return log
with tempfile.TemporaryDirectory(prefix='run-epub06-',dir=T) as tmp:
 d=Path(tmp);(d/'state').mkdir();(d/'notes').mkdir();state=d/'state'/f'{fnv(str(B))}.json';notes=d/'notes'/'anchor-fixture.json'
 bounds,words=dump(9,1.4,18,False,3);first,last=7,40;qs=[]
 for w in words[first:last+1]:
  q=w['q']
  if qs and w['line']==line:qs[-1]=[min(qs[-1][0],q[0]),min(qs[-1][1],q[1]),max(qs[-1][2],q[2]),max(qs[-1][3],q[3])]
  else:qs.append(q.copy())
  line=w['line']
 legacy=dict(page=4,style='highlight',quads=qs,text=' '.join(w['text'] for w in words[first:last+1]))
 state.write_text(json.dumps(dict(page=3,font=9,margin=18,trim=0)))
 notes.write_text(json.dumps([legacy]));original=anchor(words[first],words[last]);position=anchor(words[0])
 log=run(d,'''wait 1200
shot 49_epub_migrated
tap 640 100
wait 200
menubtn 1 1
wait 600
menubtn 1 1
wait 600
menubtn 1 3
wait 600
tap 640 1551
wait 600
shot 50_epub_typography
tap 640 850
wait 2600
shot 51_epub_highlight_reflow
quit
''')
 st=json.loads(state.read_text());ns=json.loads(notes.read_text());assert len(ns)==1
 assert all(ns[0][k]==v for k,v in original.items()),ns
 assert all(st[k]==v for k,v in position.items()),(st,position)
 assert st['font']==12 and st['spacing']==1.7 and st['margin']==24,st
 assert ns[0]['text']==legacy['text'] and ns[0]['style']=='highlight'
 print('PASS legacy EPUB note migrated before layout; exact Unicode quote and chapter/scalar anchors retained through two font steps, margin and line-spacing changes')
 bounds,now=dump(st['font'],st['spacing'],st['margin'],True,st['page'])
 hits=[w for w in now if w['chapter']==ns[0]['anchor_chapter'] and w['start']<ns[0]['anchor_end'] and w['end']>ns[0]['anchor_start']]
 assert hits,'restored reading page must contain original selection'
 x,y=center(bounds,hits[0]);outside=next(w for w in now if (w['start']>=ns[0]['anchor_end'] or w['end']<=ns[0]['anchor_start']) and w['text'].isalpha())
 wx,wy=center(bounds,outside)
 log+=run(d,f'''wait 1200
shot 52_epub_restored
tap {x} {y}
wait 200
shot 53_epub_annotation_popup
popup 1
wait 200
long {wx} {wy}
wait 200
shot 54_epub_select_word
popup 1
wait 300
quit
''')
 ns=json.loads(notes.read_text());st2=json.loads(state.read_text())
 assert ns[0]['style']=='underline',ns
 assert len(ns)==2 and ns[1]['text']==outside['text'] and ns[1]['style']=='highlight',ns
 assert all(ns[1][k]==v for k,v in anchor(outside).items()),ns[1]
 assert all(st2[k]==v for k,v in position.items()),(st2,position)
 assert Image.open(S/'51_epub_highlight_reflow.pgm').tobytes()==Image.open(S/'52_epub_restored.pgm').tobytes(),'font/margins/position/note raster must restore identically'
 (T/'epub06-ui.log').write_text(log)
 print('PASS fresh-context reopen restores identical page raster and exact reading target; relocated annotation remains tappable/editable; precise new-word highlight writes correct portable location')
 log+=run(d,"""wait 1200
tap 640 10
wait 200
menubtn 1 1
wait 500
menubtn 1 1
wait 500
menubtn 1 1
wait 500
menubtn 1 3
wait 500
tap 640 1551
wait 500
tap 640 850
wait 2600
shot 67_epub_quarterpoint
quit
""")
 quarter=json.loads(state.read_text());assert quarter['font']==17.25 and quarter['spacing']==1.15 and quarter['margin']==30,quarter
 assert all(quarter[k]==v for k,v in position.items()),quarter
 log+=run(d,"""wait 1200
shot 68_epub_quarterpoint_restored
quit
""")
 assert json.loads(state.read_text())['font']==17.25
 assert Image.open(S/'67_epub_quarterpoint.pgm').tobytes()==Image.open(S/'68_epub_quarterpoint_restored.pgm').tobytes()
 (T/'epub06-ui.log').write_text(log)
 print('PASS actual 23px-equivalent / 17.25pt size, compact line spacing and margins persist byte-identically, without accumulated reading-position drift')

for p in list(S.glob('5[0-4]_*.pgm'))+list(S.glob('49_*.pgm'))+list(S.glob('6[7-8]_*.pgm')):
 im=Image.open(p);im.save(p.with_suffix('.png'));im.thumbnail((636,848));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS EPUB migration/typography/highlights/reopen screenshots at 1272x1696 and previews')
