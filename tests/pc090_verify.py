# v0.9.0: instant reopen (saved page image) + no battery while a book is open. Host simulator.
from pathlib import Path
import subprocess,tempfile,re,shutil,os,json,zipfile,random
R=Path(__file__).resolve().parent.parent
EPUB=R/'tests/fixture.epub';PDF=R.parent/'testbooks/digital-small1.pdf'
W,H=1272,1696
def big_epub(path,chapters=80,paras=60):
 rnd=random.Random(9);words='the a of and to in reader page light paper quiet river stone glass winter morning library letter window garden'.split()
 with zipfile.ZipFile(path,'w') as z:
  z.writestr('mimetype','application/epub+zip',compress_type=zipfile.ZIP_STORED)
  z.writestr('META-INF/container.xml','<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/c.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
  items=''.join(f'<item id="c{i}" href="c{i}.xhtml" media-type="application/xhtml+xml"/>' for i in range(chapters));spine=''.join(f'<itemref idref="c{i}"/>' for i in range(chapters))
  z.writestr('OEBPS/c.opf',f'<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Synthetic</dc:title><dc:identifier id="id">syn</dc:identifier><dc:language>en</dc:language></metadata><manifest>{items}</manifest><spine>{spine}</spine></package>')
  for i in range(chapters):
   body=''.join('<p>'+' '.join(rnd.choice(words) for _ in range(90))+'.</p>' for _ in range(paras))
   z.writestr(f'OEBPS/c{i}.xhtml',f'<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>{i}</title></head><body><h1>Chapter {i+1}</h1>{body}</body></html>')
def run(d,script,name,book=None,extra=()):
 s=d/'s.sim';s.write_text(script+'wait 300\nquit\n')
 args=[str(R/'out/zreader-host'),'--data',str(d/'data'),'--books',str(d/'books'),'--sim',str(s),'--shots',str(d/'shots'),'--idle-min','0',*extra]
 if book:args.append(str(d/'books'/book))
 p=subprocess.run(args,capture_output=True,timeout=180,check=True)
 log=p.stderr.decode();(R/f'tests/{name}.log').write_text(log.replace(str(d),'TMP'));return log
def after_open(log):return log.split('open profile: close_previous_us',1)[1]
def submits(log):return re.findall(r'refresh submit: wf=(\d+) full=(\w+)',after_open(log))
def pgm(p):
 b=p.read_bytes();head,px=b.split(b'\n',1);_,w,h,_=head.split();return int(w),int(h),px
def battery(shot):
 w,h,px=pgm(shot);x=w-205
 return all(px[y*w+x]==0x33 for y in range(10,31))
def state(d):
 f=next((d/'data/state').glob('*.json'));return json.loads(f.read_text())
def cache_files(d):return sorted((d/'data/cache/pages').glob('*.pg'),key=lambda p:p.stat().st_mtime)
TURN='tap 1100 850\nwait 500\n'
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='pc090-') as t:
 d=Path(t);(d/'books').mkdir();(d/'data').mkdir();shutil.copy(EPUB,d/'books/a.epub')
 # 1. first open: no saved page yet; turn twice; quit saves the page; battery absent while reading, also with the menu
 log=run(d,'wait 1500\n'+TURN*2+'shot r1\ntap 636 850\nwait 600\nshot r1menu\n','pc090-first','a.epub')
 assert 'page cache: miss' in log and 'saved p=3 (final)' in log,log[-1500:]
 assert not battery(d/'shots/r1.pgm') and not battery(d/'shots/r1menu.pgm')
 pg=cache_files(d);assert len(pg)==1 and pg[0].stat().st_size<600_000,pg
 raw=pg[0].read_bytes();import struct,zlib;v,w,h,key,zl=struct.unpack('<IIIQI',raw[4:28]);assert raw[:4]==b'ZRPG' and (w,h)==(W,H) and len(raw)==28+zl and len(zlib.decompress(raw[28:]))==W*H//2 and b'epub' not in raw and b'books' not in raw
 print(f'PASS first open: saved page written at exit ({pg[0].stat().st_size} bytes, pixels + key only); reading frames incl. menu have no battery')
 # 2. valid reuse: preview at once, real page identical -> no second update; one opening update only (no extra flash)
 log=run(d,'wait 1500\nshot r2\n','pc090-reuse','a.epub')
 assert 'preview shown p=3' in log and 'matches saved image; no update' in log,log[-1500:]
 sb=submits(log);assert sb==[('2','true')],sb
 assert not battery(d/'shots/r2.pgm')
 ff=int(re.search(r'first_frame_us=(\d+) \(saved page\)',log)[1])
 print(f'PASS reuse: saved page shown first ({ff} us host), real page identical so no extra update; total updates on reopen = {sb}')
 # 3. library still shows the battery
 run(d,'wait 1500\nshot lib\n','pc090-library')
 assert battery(d/'shots/lib.pgm');print('PASS library shows battery; reading view never does')
 # 4. invalidation: book file changed (mtime) -> dropped, normal open
 st=os.stat(d/'books/a.epub');os.utime(d/'books/a.epub',(st.st_atime,st.st_mtime+100))
 log=run(d,'wait 1500\n','pc090-filechange','a.epub')
 assert 'stale saved page dropped' in log and 'preview shown' not in log and submits(log)==[('2','true')],log[-1500:]
 print('PASS invalidation on book file change (no preview, single normal opening update)')
 # 5. invalidation: layout setting changed (font in state) and image option changed
 run(d,'wait 1500\n','pc090-resave','a.epub')
 sf=next((d/'data/state').glob('*.json'));j=sf.read_text();sf.write_text(re.sub(r'"font":[0-9.]+','"font":15.00',j))
 log=run(d,'wait 1500\n','pc090-fontchange','a.epub')
 assert 'stale saved page dropped' in log and 'preview shown' not in log,log[-1500:]
 log=run(d,'wait 1500\n','pc090-dither','a.epub',('--no-image-dither',))
 assert 'stale saved page dropped' in log and 'preview shown' not in log,log[-1500:]
 log=run(d,'wait 1500\n','pc090-reuse2','a.epub',('--no-image-dither',))
 assert 'preview shown' in log,log[-1500:]
 print('PASS invalidation on font change and on image-option change; next open reuses the new page')
 # 6. queued turn before the document is ready (big EPUB opened from the library; taps sent during the open)
 d2=d/'big';(d2/'books').mkdir(parents=True);(d2/'data').mkdir();big=d2/'books/b.epub';big_epub(big)
 run(d2,'wait 1500\ntap 600 405\nwait 8000\n'+TURN*3,'pc090-big-first')
 s0=state(d2)['page']
 log=run(d2,'wait 1500\ntap 600 405\nwait 30\ntap 1100 850\nwait 30\ntap 1100 850\nwait 8000\n','pc090-queued')
 assert 'preview shown p=%d'%(s0+1) in log,log[-2500:]
 s1=state(d2)['page'];assert s1==s0+2,(s0,s1)
 print(f'PASS queued turns: 2 taps sent while the big EPUB was still opening both applied once it was ready (page {s0+1} -> {s1+1})')
 # 7. cap / LRU eviction: 1 MiB cap, 16 books
 shutil.rmtree(d/'data');(d/'data').mkdir()
 for i in range(16):shutil.copy(EPUB,d/f'books/e{i:02}.epub')
 for i in range(16):
  run(d,'wait 900\n'+TURN,'pc090-cap','e%02d.epub'%i,('--page-cache-mib','1'))
  total=sum(p.stat().st_size for p in cache_files(d));assert total<=1<<20,total
 names=[p.name for p in cache_files(d)]
 import hashlib
 def fnv(s):
  h=0xcbf29ce484222325
  for c in s.encode():h^=c;h=(h*0x100000001b3)&0xFFFFFFFFFFFFFFFF
  return h
 last='%016x.pg'%fnv(str(d/'books/e15.epub'));first='%016x.pg'%fnv(str(d/'books/e00.epub'))
 assert last in names and first not in names and 4<len(names)<16,(len(names),last in names,first in names)
 print(f'PASS cap: 16 books under a 1 MiB cap keep {len(names)} newest saved pages (oldest evicted, total <= cap)')
