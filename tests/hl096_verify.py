#!/usr/bin/env python3
"""v0.9.6 highlights and notes: long-press + tap end word, popup (Highlight/Underline/Note/Look up/
Copy/Cancel), note keyboard, edit popup, Highlights & notes list, Markdown/text export served on the
Upload screen and written to DATA/export, page byte-identical once removed, fast taps, --version."""
from pathlib import Path
import subprocess,tempfile,json,re,time,socket,http.client,urllib.parse,shutil
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';W,H=1272,1696
BOOK=R.parent/'testbooks/digital-small1.pdf';PORT=18096
EXPECTED='could think to say at that exact moment was this: “If Edgar Allan Mitchell—the sixth man to walk on the'
def fnv(s):
 h=0xcbf29ce484222325
 for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
 return f'{h:016x}'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
KEYS=["1234567890","qwertyuiop","asdfghjkl","zxcvbnm'-_",".,?!;:()\"/"]
def key(ch):
 bw=(W-140)//10
 if ch==' ':return (390+246,600+5*118+52)
 for r,row in enumerate(KEYS):
  if ch.lower() in row:c=row.index(ch.lower());return (70+c*bw+(bw-10)//2,600+r*118+52)
 raise KeyError(ch)
def typed(s):return ''.join(f'tap {x} {y}\nwait 120\n' for x,y in map(key,s))
SAVE=(902+150,600+5*118+130+52)
def run(d,script,book=BOOK,extra=(),bg=False):
 (d/'s.sim').write_text(script);args=[str(HOST),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(BOOK.parent),'--idle-min','0',*extra]+([str(book)] if book else [])
 if bg:return subprocess.Popen(args,stderr=open(d/'bg.log','w'))
 p=subprocess.run(args,capture_output=True,timeout=120);log=p.stderr.decode()
 assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:];assert 'exit gesture' not in log;return log
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[6-9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
assert BOOK.exists(),'needs the local test PDF (not distributed)'
with tempfile.TemporaryDirectory(dir=T,prefix='hl096-') as t:
 d=Path(t);(d/'data'/'state').mkdir(parents=True)
 (d/'data'/'state'/f'{fnv(str(BOOK))}.json').write_text(json.dumps(dict(page=6,trim=1)))
 log=run(d,'''wait 1200
shot hl_plain
long 288 548
wait 400
shot hl_popup_word
tap 300 585
wait 400
shot hl_popup_extended
popup 5
wait 700
'''+typed('good point. see ch 3')+'''shot hl_editor
tap %d %d
wait 1200
shot hl_saved
tap 300 548
wait 500
shot hl_edit_popup
popup 3
wait 400
tap 640 100
wait 300
menubtn 0 1
wait 700
shot hl_list
quit
'''%SAVE)
 notes=json.loads(next((d/'data'/'notes').glob('*.json')).read_text())
 assert len(notes)==1 and notes[0]['text']==EXPECTED and notes[0]['style']=='highlight' and notes[0]['comment']=='Good point. See ch 3',notes
 print('PASS long-press word + tap end word selects the passage; "Note" saves a highlight with the typed note ("%s")'%notes[0]['comment'])
 a=pgm(d/'hl_plain.pgm');s=pgm(d/'hl_saved.pgm');diff=sum(1 for i in range(0,len(a),3) if a[i]!=s[i]);assert diff>500,diff
 assert pgm(d/'hl_edit_popup.pgm')!=s
 print(f'PASS highlight drawn with the page ({diff*3} px changed); tapping it opens Edit note / Remove')
 # export over the Upload screen (library, no book); also written to DATA/export
 d2=d/'up';shutil.copytree(d/'data',d2/'data');(d2/'data'/'last_book').unlink(missing_ok=True)
 p=run(d2,'wait 1500\ntap 1010 262\nwait 800\ntap 636 1485\nwait 6000\nshot hl_upload_screen\nwait 300\ntap 1127 85\nwait 2500\nquit\n',book=None,extra=('--upload-port',str(PORT)),bg=True)
 end=time.time()+10;page=None
 while time.time()<end:
  try:c=http.client.HTTPConnection('127.0.0.1',PORT,timeout=3);c.request('GET','/');r=c.getresponse();page=r.read().decode();break
  except OSError:time.sleep(0.2)
 assert page and 'Highlights and notes' in page and 'Send books' in page,page
 links=re.findall(r"href='(/export/[^']+)'",page);assert any('digital-small1' in l for l in links) and any('All%20books' in l for l in links),links
 def get(u):c=http.client.HTTPConnection('127.0.0.1',PORT,timeout=5);c.request('GET',u);r=c.getresponse();b=r.read();return r.status,dict(r.getheaders()),b
 st,hd,md=get([l for l in links if 'digital-small1' in l and '?txt' not in l][0]);md=md.decode()
 assert st==200 and 'attachment' in hd['Content-Disposition'] and hd['Content-Type'].startswith('text/markdown') and '**Note:** Good point. See ch 3' in md and 'could think to say' in md,(st,hd,md)
 st2,hd2,tx=get([l for l in links if 'digital-small1' in l and '?txt' in l][0]);assert st2==200 and hd2['Content-Type'].startswith('text/plain') and tx.decode()==md and '.txt' in hd2['Content-Disposition']
 st3,_,al=get([l for l in links if 'All%20books' in l and '?txt' not in l][0]);assert st3==200 and 'Good point' in al.decode()
 bad=[get(u)[0] for u in ['/export/..%2Fstate%2Fx.md','/export/../notes/digital-small1.json','/export/digital-small1.json','/export/.hidden.md','/export/']]
 assert all(b==404 for b in bad),bad
 p.wait(timeout=40);assert p.returncode==0
 ex=d2/'data'/'export';assert (ex/'digital-small1.md').read_text()==md and (ex/'All books - highlights and notes.md').exists()
 end=time.time()+5
 try:socket.create_connection(('127.0.0.1',PORT),0.5).close();up=True
 except OSError:up=False
 assert not up,'server must stop after leaving the Upload screen'
 print(f'PASS Upload screen offers per-book + all-books downloads (Markdown and text); files also in DATA/export; {len(bad)} bad paths refused; server stops on Close')
 # remove via the list (long-press) -> page byte-identical to before
 run(d,'''wait 1200
tap 640 100
wait 300
menubtn 0 1
wait 700
long 636 295
wait 700
tap 1147 85
wait 1200
shot hl_removed
quit
''')
 assert json.loads(next((d/'data'/'notes').glob('*.json')).read_text())==[]
 assert pgm(d/'hl_removed.pgm')==a,'page not byte-identical after removing the highlight'
 print('PASS long-press in the list deletes; page byte-identical to before the highlight')
 # fast taps: popup and keyboard, then page turns; never exits
 log=run(d,'''wait 1200
long 288 548
wait 300
tap 300 585
wait 60
popup 5
wait 80
'''+''.join('tap 120 650\nwait 60\n' for _ in range(6))+'''tap 1052 1372
wait 80
tap 1180 850
wait 60
tap 1180 850
wait 60
tap 100 850
wait 900
shot hl_fast_alive
quit
''')
 assert (d/'hl_fast_alive.pgm').exists() and 'quit_requested' not in log
 n=json.loads(next((d/'data'/'notes').glob('*.json')).read_text());assert len(n)==1 and n[0]['comment']=='111111',n
 print('PASS fast taps in popup, keyboard and page turns never exit (note "111111" saved)')
 from PIL import Image
 out=R.parent/'stage'/'zr096-shots';out.mkdir(parents=True,exist_ok=True)
 for f in sorted(d.glob('hl_*.pgm'))+sorted(d2.glob('*.pgm')):Image.open(f).save(out/(f.stem+'.png'))
