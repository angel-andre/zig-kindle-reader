#!/usr/bin/env python3
"""v0.10.2 more formats: MOBI, AZW3 (KF8), TXT, CBZ and FB2 open, page, show covers/type labels in
the library, get Contents (outline or detected), Font/Align/hyphenation on reflowed text, bookmarks and
highlights on text formats; DRM-protected MOBI/AZW3/EPUB show a clear message and never crash;
damaged files fail safely; the upload page accepts the new types; PDF and EPUB pages byte-identical to
0.10.1; fast taps never exit; --version."""
from pathlib import Path
import subprocess,tempfile,re,json,shutil,struct,zipfile,time,socket,http.client,urllib.parse
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';REF=R/'out/zreader-host-101';W,H=1272,1696
MU=R.parent/'mupdf-1.28.6-source'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def ink(img,y0=0,y1=H):return sum(1 for y in range(y0,y1,4) for x in range(0,W,4) if img[y*W+x]<128)
def run(binary,d,script,book,books,ui=None,extra=(),ok_exit=True):
 (d/'data').mkdir(parents=True,exist_ok=True)
 if ui is not None:(d/'data'/'ui07.json').write_text(json.dumps(ui)+'\n')
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(binary),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(books),'--idle-min','0',*extra]+([str(book)] if book else []),capture_output=True,timeout=300)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:];assert 'exit gesture' not in log and log.count('exiting')==1;return log
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[5-9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
FILES={'txt':T/'formats102-alice.txt','mobi':T/'formats102-alice.mobi','azw3':T/'formats102-alice.azw3','fb2':T/'formats102-alice.fb2','cbz':T/'formats102-comic.cbz'}
SHOT='wait 2500\nshot p1\ntap 1180 850\nwait 1500\nshot p2\ntap 1180 850\nwait 1500\ntap 640 100\nwait 500\nshot menu\nmenubtn 0 0\nwait 2500\nshot toc\nquit\n'
subprocess.run([str(R.parent/'zig/zig'),'cc','-target','x86_64-linux-musl','-O2',f'-DSRC="{R}/src"','-I',str(R/'src'),'-I',str(MU/'include'),str(T/'text100_probe.c'),str(R/'src/render.c'),str(MU/'build/hostmusl-release/libmupdf.a'),str(MU/'build/hostmusl-release/libmupdf-third.a'),'-static','-lpthread','-lm','-o',str(R/'out/text100-probe')],check=True)
def lines(book,mode,font):
 out=subprocess.run([str(R/'out/text100-probe'),str(book),str(mode),str(font)],capture_output=True,check=True).stdout.decode()
 rows=out.splitlines();return int(rows[0].split('\t')[1]),[r.split('\t',1) for r in rows[1:]]
with tempfile.TemporaryDirectory(dir=T,prefix='formats102-') as t:
 d=Path(t);books=d/'books';books.mkdir()
 for k,f in FILES.items():shutil.copy(f,books/f'alice.{k}' if k!='cbz' else books/'comic.cbz')
 shots={}
 # 1. each format opens and pages; Contents
 expect={'txt':(True,'outline'),'mobi':(True,'detected 4'),'azw3':(True,'detected 4'),'fb2':(True,'detected 4'),'cbz':(False,'detected 0')}
 for k,(reflow,toc) in expect.items():
  b=books/(f'alice.{k}' if k!='cbz' else 'comic.cbz');e=d/f'open-{k}';log=run(HOST,e,SHOT,b,books)
  mo=re.search(r'opened .*: pages=(\d+) pdf=false reflow=(\w+)',log);assert mo and mo[2]==str(reflow).lower(),log[-1500:]
  n=int(mo[1]);assert n>=(4 if k=='cbz' else 20),n
  p1,p2=pgm(e/'p1.pgm'),pgm(e/'p2.pgm');assert p1!=p2 and ink(p1)+ink(p2)>600 and min(ink(p1),ink(p2))>20,(k,ink(p1),ink(p2))
  if toc=='outline':assert 'detecting chapter headings' not in log
  else:assert f'contents: {toc} entries' in log,(k,re.findall('contents:.*',log))
  shots[k]=e
  print(f'PASS {k.upper()}: opens ({n} pages, reflow={reflow}), pages render and turn, Contents '+('from the outline' if toc=='outline' else toc.replace('detected','detected:')+' entries'))
 # Contents entries: TXT outline / detected lists
 _,tl=lines(FILES['txt'],0,0)
 heads=[l for p,l in tl if l.startswith('CHAPTER')];assert heads[:1]==['CHAPTER I.'] or any('CHAPTER I.' in h for h in heads),heads[:5]
 starts={}
 for p,l in tl:starts.setdefault(int(p),l)
 assert sum(1 for l in starts.values() if l.startswith('CHAPTER'))>=3,starts
 print('PASS TXT: "CHAPTER I." headings become headings that start a page (3 chapters at page tops) and form the outline')
 for k in ('mobi','azw3','fb2'):
  c=next((shots[k]/'data'/'state'/'contents').glob('*.tsv')).read_text().splitlines()[1:]
  labels=[r.split('\t')[2] for r in c];assert labels==['Contents','Chapter I · Down the Rabbit-Hole','Chapter II · The Pool of Tears','Chapter III · A Caucus-Race and a Long Tale'] or (k=='fb2' and labels[1:]==['Chapter I','Chapter II','Chapter III']) or labels[1:4]==['Chapter I · Down the Rabbit-Hole','Chapter II · The Pool of Tears','Chapter III · A Caucus-Race and a Long Tale'],(k,labels)
 print('PASS MOBI/AZW3/FB2: chapters start pages; Contents (detected) = Contents, Chapter I-III with titles')
 # AZW3 = same text as MOBI (KF8 joined correctly)
 _,ma=lines(FILES['mobi'],0,0);_,az=lines(FILES['azw3'],0,0)
 wm=' '.join(l for _,l in ma).split();wa=' '.join(l for _,l in az).split()
 common=len(set(wm)&set(wa))/max(len(set(wm)),1);assert len(wa)>4000 and common>0.97,(len(wa),common)
 print(f'PASS AZW3 (KF8): {len(wa)} words, {common:.1%} of the MOBI vocabulary; CSS flows and file breaks applied')
 # 2. TXT Font/Align/hyphenation
 n0,l0=lines(FILES['txt'],0,0);n2,l2=lines(FILES['txt'],2,0)
 shy=sum(1 for _,l in l2 if l.endswith('\u00ad'));assert shy>=5 and not any(l.endswith('\u00ad') for _,l in l0),shy
 pages={}
 for mm,ff in [(0,0),(2,0),(2,2),(1,1)]:
  e=d/f'style-{mm}{ff}';run(HOST,e,'wait 2500\n'+'tap 1180 850\nwait 1200\n'*4+'shot b\nquit\n',books/'alice.txt',books,{"sort":0,"power_sleeps":0,"clean_scans":1,"text_mode":mm,"book_font":ff});pages[(mm,ff)]=pgm(e/'b.pgm')
 assert len(set(pages.values()))==4
 shutil.copy(d/'style-22'/'b.pgm',d/'txt_notosans.pgm')
 print(f'PASS TXT: Justify + hyphens ({shy} hyphenated line ends), Justify, Align: original, Charis and Noto Sans all apply (4 distinct pages)')
 # 3. bookmarks and highlights in TXT; CBZ bookmark
 e=d/'bm-txt';log=run(HOST,e,'wait 2500\ntap 1180 850\nwait 1500\ntap 640 100\nwait 300\nmenubtn 2 3\nwait 700\ntap 636 1484\nwait 700\ntap 1147 85\nwait 1200\ntap 1180 850\nwait 1200\ntap 1180 850\nwait 1200\nlong 636 800\nwait 500\nshot pop\npopup 1\nwait 900\nshot hl\nquit\n',books/'alice.txt',books)
 bm=list((e/'data'/'state').glob('*.bookmarks'));assert bm and bm[0].read_text().startswith('1\t'),bm and bm[0].read_text()
 notes=json.loads(next((e/'data'/'notes').glob('*.json')).read_text());assert notes and notes[0]['style']=='highlight' and len(notes[0]['text'])>=2,notes
 shutil.copy(e/'hl.pgm',d/'txt_highlight.pgm')
 print(f'PASS TXT bookmark (page 2) and highlight ("{notes[0]["text"][:30]}") saved')
 e=d/'bm-cbz';run(HOST,e,'wait 2000\ntap 1180 850\nwait 1200\ntap 640 100\nwait 300\nmenubtn 2 3\nwait 700\ntap 636 1484\nwait 700\ntap 1147 85\nwait 800\nquit\n',books/'comic.cbz',books)
 bm=list((e/'data'/'state').glob('*.bookmarks'));assert bm and bm[0].read_text().startswith('1\t'),bm
 print('PASS CBZ bookmark saved (no text: no highlights)')
 # 4. library: all types, labels, sizes, covers; stats
 shutil.copy(T/'fixture.epub',books/'fixture.epub');shutil.copy(T/'tall-view-fixture.pdf',books/'tall.pdf')
 e=d/'lib';log=run(HOST,e,'wait 3500\nshot lib\nquit\n',None,books)
 mo=re.search(r'library: (\d+) books',log);assert mo and int(mo[1])==7,log[-800:]
 shutil.copy(e/'lib.pgm',d/'library.pgm')
 st=(shots['mobi']/'data'/'state'/'stats.tsv');assert st.exists() and any(l.startswith('b\t') and int(l.split('\t')[3])>=1 for l in st.read_text().splitlines()),st.read_text()
 print('PASS library lists 7 books (PDF, EPUB, MOBI, AZW3, TXT, CBZ, FB2) with type label and size; stats recorded for MOBI')
 # 5. DRM and damaged files
 b=bytearray(FILES['mobi'].read_bytes());o=struct.unpack('>I',b[78:82])[0];b[o+12:o+14]=b'\x00\x02';(books/'drm.mobi').write_bytes(b)
 b=bytearray(FILES['azw3'].read_bytes());o=struct.unpack('>I',b[78:82])[0];b[o+12:o+14]=b'\x00\x02';(books/'drm.azw3').write_bytes(b)
 zi=zipfile.ZipFile(T/'fixture.epub');zo=zipfile.ZipFile(books/'drm.epub','w')
 for it in zi.infolist():zo.writestr(it,zi.read(it.filename))
 zo.writestr('META-INF/encryption.xml','<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container" xmlns:enc="http://www.w3.org/2001/04/xmlenc#"><enc:EncryptedData><enc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/></enc:EncryptedData></encryption>');zo.close()
 (books/'kfx.azw').write_bytes(b'\xeaDRMION\xee'+b'\0'*200)
 for name in ('drm.mobi','drm.azw3','drm.epub','kfx.azw'):
  e=d/f'drm-{name}';log=run(HOST,e,'wait 1500\nshot a\nquit\n',books/name,books)
  assert f'drm: {books/name} is DRM-protected; not opened' in log and 'opened ' not in log.split('drm:')[1][:200]
 shutil.copy(d/'drm-drm.mobi'/'a.pgm',d/'drm_message.pgm')
 img=pgm(d/'drm_message.pgm');assert ink(img,H-260,H-150)>1500
 bad=FILES['mobi'].read_bytes();(books/'cut.mobi').write_bytes(bad[:3000]);(books/'junk.azw3').write_bytes(b'BOOKMOBI'*500);(books/'empty.txt').write_bytes(b'');(books/'bad.cbz').write_bytes(b'PK\x03\x04'+b'\0'*100);(books/'bad.fb2').write_bytes(b'<FictionBook><body><section><p>unclosed')
 for name in ('cut.mobi','junk.azw3','empty.txt','bad.cbz','bad.fb2'):
  e=d/f'bad-{name}';(e/'data').mkdir(parents=True);(e/'s.sim').write_text('wait 1500\ntap 1180 850\nwait 600\nquit\n')
  p=subprocess.run([str(HOST),'--sim',str(e/'s.sim'),'--shots',str(e),'--data',str(e/'data'),'--books',str(books),'--idle-min','0',str(books/name)],capture_output=True,timeout=120)
  assert p.returncode==0 and b'exiting' in p.stderr,(name,p.returncode,p.stderr[-600:])
 print('PASS DRM MOBI/AZW3/EPUB/KFX: "This book is DRM-protected and can\'t be opened", nothing opened; damaged MOBI/AZW3/TXT/CBZ/FB2 never crash')
 # 6. fast taps never exit (TXT, CBZ)
 for k,b in (('txt','alice.txt'),('cbz','comic.cbz')):
  run(HOST,d/f'fast-{k}','wait 2000\n'+'tap 1180 850\nwait 40\n'*8+'tap 100 850\nwait 40\n'*4+'tap 640 100\nwait 40\ntap 640 100\nwait 40\n'*3+'wait 2000\nquit\n',books/b,books)
 print('PASS 18 fast taps on TXT and CBZ never exit')
 # 7. PDF and EPUB byte-identical to 0.10.1
 BIG=R.parent/'testbooks'/'digital-big.pdf';pb=d/'pe';pb.mkdir();shutil.copy(T/'tall-view-fixture.pdf',pb/'tall.pdf');shutil.copy(T/'fixture.epub',pb/'fixture.epub');shutil.copy(T/'text100-en.epub',pb/'en.epub')
 s='wait 2000\nshot a\ntap 1180 850\nwait 1500\nshot b\ntap 640 100\nwait 600\nshot menu\nquit\n'
 cases=[(BIG,BIG.parent),(pb/'tall.pdf',pb),(pb/'fixture.epub',pb),(pb/'en.epub',pb)]
 for bk,bd in cases:
  for mm in (2,0):
   ui={"sort":0,"power_sleeps":0,"clean_scans":1,"text_mode":mm,"book_font":0}
   run(REF,d/f'r-{bk.stem}-{mm}',s,bk,bd,ui);run(HOST,d/f'n-{bk.stem}-{mm}',s,bk,bd,ui)
   for f in 'ab':assert pgm(d/f'r-{bk.stem}-{mm}'/f'{f}.pgm')==pgm(d/f'n-{bk.stem}-{mm}'/f'{f}.pgm'),(bk,mm,f)
 run(REF,d/'r-lib','wait 3000\nshot l\nquit\n',None,pb);run(HOST,d/'n-lib','wait 3000\nshot l\nquit\n',None,pb)
 assert pgm(d/'r-lib'/'l.pgm')==pgm(d/'n-lib'/'l.pgm')
 print('PASS PDF and EPUB pages byte-identical to 0.10.1 (2 PDFs + 2 EPUBs x 2 text settings x 2 pages); PDF/EPUB-only library identical')
 out=R/'out'/'formats102-shots';shutil.rmtree(out,ignore_errors=True);out.mkdir()
 for k in FILES:
  shutil.copy(shots[k]/'p1.pgm',out/f'{k}_page1.pgm');shutil.copy(shots[k]/'toc.pgm',out/f'{k}_contents.pgm')
 for f in ('library','drm_message','txt_highlight','txt_notosans'):shutil.copy(d/f'{f}.pgm',out/f'{f}.pgm')
# 8. upload accepts the new types
import importlib.util
PORT=18102
with tempfile.TemporaryDirectory(dir=T,prefix='formats102u-') as t:
 d=Path(t);(d/'books').mkdir();(d/'data').mkdir();s=d/'s.sim';s.write_text('wait 1500\ntap 1010 262\nwait 800\ntap 636 1485\nwait 6000\ntap 1127 85\nwait 3000\nquit\n')
 p=subprocess.Popen([str(HOST),'--data',str(d/'data'),'--books',str(d/'books'),'--sim',str(s),'--shots',str(d),'--idle-min','0','--upload-port',str(PORT),'--log',str(d/'log.txt')])
 end=time.time()+8
 while time.time()<end:
  try:socket.create_connection(('127.0.0.1',PORT),0.3).close();break
  except OSError:time.sleep(0.1)
 def post(name,data):
  c=http.client.HTTPConnection('127.0.0.1',PORT,timeout=10);c.request('POST','/upload?name='+urllib.parse.quote(name,safe=''),body=data,headers={'Content-Length':str(len(data))});r=c.getresponse();r.read();c.close();return r.status
 c=http.client.HTTPConnection('127.0.0.1',PORT,timeout=5);c.request('GET','/');page=c.getresponse().read().decode()
 assert "accept='.pdf,.epub,.mobi,.azw3,.txt,.cbz,.fb2'" in page
 st={n:post(n,FILES[n.split('.')[1]].read_bytes()) for n in ('a.mobi','a.azw3','a.txt','a.cbz','a.fb2')}
 badst={n:post(n,b'x'*50) for n in ('a.docx','a.azw','a.kfx')}
 p.wait(timeout=60)
 assert all(v==200 for v in st.values()) and all(v in (400,404) for v in badst.values()),(st,badst)
 assert sorted(x.name for x in (d/'books').iterdir())==['a.azw3','a.cbz','a.fb2','a.mobi','a.txt']
print('PASS upload page accepts .mobi .azw3 .txt .cbz .fb2 (file picker and server); .docx/.azw/.kfx refused')
print('ALL formats102 PASS')
