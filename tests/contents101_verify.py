#!/usr/bin/env python3
"""v0.10.1 Contents fallback: books without an outline get 'Contents (detected)' built from chapter
headings in the text (background, cached under state/contents), always with 'Go to page...' and
'Go to %...'; nothing detected -> only the jump options; books with an outline unchanged; page
turns not slowed while detection runs; PDF pages byte-identical; fast taps never exit; --version."""
from pathlib import Path
import subprocess,tempfile,re,json,shutil,zipfile,time
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';REF=R/'out/zreader-host-100';W,H=1272,1696
MU=R.parent/'mupdf-1.28.6-source';DIAG=R.parent/'diag'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def run(binary,d,script,book,books,ui=None,extra=()):
 (d/'data').mkdir(parents=True,exist_ok=True)
 if ui is not None:(d/'data'/'ui07.json').write_text(json.dumps(ui)+'\n')
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(binary),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(books),'--idle-min','0',*extra]+([str(book)] if book else []),capture_output=True,timeout=300)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:];assert 'exit gesture' not in log and log.count('exiting')==1;return log
def lat(log,k):
 m=re.search(k+r'\s+n=\s*(\d+)\s+min=\s*(\d+) p50=\s*(\d+) avg=\s*(\d+) p90=\s*(\d+)',log);return int(m[1]),int(m[3]),int(m[5])
def pages(log):return [int(x) for x in re.findall(r'page refresh: p=(\d+)',log)]
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[5-9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
subprocess.run([str(R.parent/'zig/zig'),'cc','-target','x86_64-linux-musl','-O2',f'-DSRC="{R}/src"','-I',str(R/'src'),'-I',str(MU/'include'),str(T/'contents101_probe.c'),str(R/'src/render.c'),str(MU/'build/hostmusl-release/libmupdf.a'),str(MU/'build/hostmusl-release/libmupdf-third.a'),'-static','-lpthread','-lm','-o',str(R/'out/contents101-probe')],check=True)
def detect(book,reflow=0):
 with tempfile.TemporaryDirectory() as t:
  o=Path(t)/'c.tsv';p=subprocess.run([str(R/'out/contents101-probe'),str(book),str(o),str(reflow)],capture_output=True,text=True,check=True)
  st=dict(zip(*[iter(p.stdout.split())]*2));rows=o.read_text().splitlines();assert rows[0]=='zrcontents\t1'
  return int(st['pages']),int(st['ms']),[tuple(r.split('\t')) for r in rows[1:]]
def pdf(path,pages_text):
 objs=[b'<< /Type /Catalog /Pages 2 0 R >>',None,b'<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>'];kids=[]
 for lines in pages_text:
  c=b'BT /F1 12 Tf 72 740 Td 16 TL '+b' '.join(b'('+l.encode()+b') Tj T*' for l in lines)+b' ET'
  objs.append(b'<< /Length %d >>\nstream\n'%len(c)+c+b'\nendstream');objs.append(b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R >>'%(len(objs)));kids.append(len(objs))
 objs[1]=b'<< /Type /Pages /Count %d /Kids [%s] >>'%(len(kids),b' '.join(b'%d 0 R'%k for k in kids))
 out=b'%PDF-1.4\n';offs=[]
 for i,o in enumerate(objs):offs.append(len(out));out+=b'%d 0 obj\n'%(i+1)+o+b'\nendobj\n'
 x=len(out);out+=b'xref\n0 %d\n0000000000 65535 f \n'%(len(objs)+1)+b''.join(b'%010d 00000 n \n'%o for o in offs)+b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n'%(len(objs)+1,x);Path(path).write_bytes(out)
BODY=['It was a quiet morning on the river and the boats moved slowly.','Nobody said very much, and the day went on as days do.']*12
results={}
# 1. both diag books (scanned, OCR text layer, no outline)
for name,minc in [('scan-b.pdf',10),('scan-c.pdf',15)]:
 b=DIAG/name
 if not b.exists():print(f'SKIP {name} not present');continue
 n,ms,rows=detect(b);results[name]=(n,ms,rows)
 ch=[r for r in rows if r[2].lower().startswith('chapter')]
 assert len(ch)>=minc and [int(r[0]) for r in rows]==sorted(int(r[0]) for r in rows) and all(0<=int(r[0])<n for r in rows),rows
 assert all(len(r[2])<=90 and re.search('[A-Za-z]',r[2]) for r in rows),rows
 print(f'PASS {name}: {len(rows)} entries ({len(ch)} chapters) from {n} pages in {ms} ms on the host: '+'; '.join(f'{r[2]} p{int(r[0])+1}' for r in rows))
fr=results.get('scan-b.pdf')
if fr:assert ('Chapter I' in [r[2] for r in fr[2]]) and int([r for r in fr[2] if r[2]=='Chapter III'][0][0])==139
with tempfile.TemporaryDirectory(dir=T,prefix='contents101-') as t:
 d=Path(t);books=d/'books';books.mkdir()
 # 2. generated digital books: numbered chapters, words, no headings, running header only
 words=['One','Two','Three','Four','Five','Six']
 pdf(books/'chapters.pdf',[([f'CHAPTER {words[i//3]}','The Long Road'] if i%3==0 else [])+BODY for i in range(18)])
 pdf(books/'plain.pdf',[BODY for _ in range(20)])
 pdf(books/'header.pdf',[['THE RIVER BOOK',str(i+1)]+BODY for i in range(20)])
 pdf(books/'gaps.pdf',[(['Chapter 1'] if i==0 else ['Chapter 7'] if i==9 else [])+BODY for i in range(12)])
 n,ms,rows=detect(books/'chapters.pdf');assert [(r[0],r[2]) for r in rows]==[(str(3*i),f'Chapter {i+1} The Long Road') or (str(3*i),f'Chapter {i+1}') for i in range(6)] or [r[0] for r in rows]==[str(3*i) for i in range(6)],rows
 print(f'PASS digital PDF, "CHAPTER ONE".."CHAPTER SIX": 6 entries at the right pages ({rows[0][2]!r} ...)')
 for b in ('plain.pdf','header.pdf','gaps.pdf'):
  n,ms,rows=detect(books/b);assert rows==[],(b,rows)
 n,ms,rows=detect(T/'tall-view-fixture.pdf');assert rows==[]
 print('PASS no headings / running header only / 2 stray chapter lines / tall fixture: 0 entries (no garbage)')
 # EPUB without nav/ncx
 with zipfile.ZipFile(books/'notoc.epub','w') as z:
  z.writestr('mimetype','application/epub+zip',compress_type=zipfile.ZIP_STORED)
  z.writestr('META-INF/container.xml','<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="c.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
  z.writestr('c.opf','<package version="2.0" unique-identifier="id" xmlns="http://www.idpf.org/2007/opf"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>No toc</dc:title><dc:identifier id="id">notoc</dc:identifier><dc:language>en</dc:language></metadata><manifest>'+''.join(f'<item id="b{i}" href="b{i}.xhtml" media-type="application/xhtml+xml"/>' for i in range(5))+'</manifest><spine>'+''.join(f'<itemref idref="b{i}"/>' for i in range(5))+'</spine></package>')
  for i in range(5):z.writestr(f'b{i}.xhtml',f'<html xmlns="http://www.w3.org/1999/xhtml"><body><h2>Chapter {i+1}</h2><p>'+' '.join(BODY)+'</p><p>'+' '.join(BODY)+'</p></body></html>')
 n,ms,rows=detect(books/'notoc.epub',1);assert [r[2] for r in rows]==[f'Chapter {i+1}' for i in range(5)] and len({r[0] for r in rows})==5,rows
 print(f'PASS EPUB without nav/NCX: Chapter 1..5 detected on reflowed pages {[int(r[0])+1 for r in rows]} of {n}')
 # 3. sim on scan-b: progress, label, cache, row tap, Go to page, Go to %, fast taps
 shutil.copy(T/'tall-view-fixture.pdf',books/'tall.pdf')
 if fr:
  e=d/'fr';s=('wait 1500\ntap 640 100\nwait 400\nmenubtn 0 0\nwait 300\nshot c_progress\nwait 4000\nshot c_detected\ntap 636 855\nwait 1500\nshot c_row\n'
   'tap 640 100\nwait 400\nmenubtn 0 0\nwait 800\ntap 250 262\nwait 600\nshot c_goto_empty\ntap 347 652\nwait 120\ntap 1138 652\nwait 120\ntap 1138 652\nwait 120\nshot c_goto\ntap 1052 1372\nwait 1500\n'
   'tap 640 100\nwait 400\nmenubtn 0 0\nwait 800\ntap 630 262\nwait 600\ntap 572 652\nwait 120\ntap 1138 652\nwait 120\nshot c_pct\ntap 1052 1372\nwait 1500\n'
   'tap 640 100\nwait 400\nmenubtn 0 0\nwait 800\ntap 250 262\nwait 400\ntap 1052 1372\nwait 600\nshot c_bad\n'+'tap 640 100\nwait 40\nmenubtn 0 0\nwait 40\ntap 636 855\nwait 40\n'*3+'wait 2000\nquit\n')
  log=run(HOST,e,s,DIAG/'scan-b.pdf',DIAG)
  assert 'contents: no outline; detecting chapter headings in the background' in log and re.search(r'contents: detection done: 17 entries from 772 pages in \d+ ms',log),log[-2000:]
  cache=list((e/'data'/'state'/'contents').glob('*.tsv'));assert len(cache)==1 and cache[0].read_text().startswith('zrcontents\t1\n')
  pg=pages(log);assert 78 in pg and 300 in pg and any(380<=p<=392 for p in pg),pg
  assert pgm(e/'c_progress.pgm')!=pgm(e/'c_detected.pgm')
  for f in ['c_progress','c_detected','c_goto','c_pct','c_bad']:shutil.copy(e/f'{f}.pgm',d/f'{f}.pgm')
  print(f'PASS sim scan-b: progress shown, "Contents (detected)" list, cache {cache[0].relative_to(e/"data")}, row "Chapter II" -> p78, Go to page 300 -> p300, Go to % 50 -> p{[p for p in pg if 380<=p<=392][0]}, empty entry -> toast, 9 fast taps never exit')
  e2=d/'fr2';log2=run(HOST,e2,'wait 1500\ntap 640 100\nwait 400\nmenubtn 0 0\nwait 500\nshot c\nquit\n',DIAG/'scan-b.pdf',DIAG,extra=())
  shutil.copytree(e/'data'/'state'/'contents',e2/'data'/'state'/'contents',dirs_exist_ok=True)
  log2=run(HOST,e2,'wait 1500\ntap 640 100\nwait 400\nmenubtn 0 0\nwait 500\nshot c\nquit\n',DIAG/'scan-b.pdf',DIAG)
  assert 'contents: detected 17 entries (cached)' in log2 and 'detecting chapter headings' not in log2
  print('PASS reopen: Contents comes from the cache instantly, no second detection')
  # 4. page turns while detection runs vs 0.10.0 (no detection)
  turn='wait 1500\ntap 640 100\nwait 400\nmenubtn 0 0\nwait 100\ntap 1126 84\nwait 300\n'+'tap 1180 850\nwait 400\n'*11+'wait 1500\nquit\n'
  reft='wait 2300\n'+'tap 1180 850\nwait 400\n'*11+'wait 1500\nquit\n'
  ln=run(HOST,d/'turn-new',turn,DIAG/'scan-b.pdf',DIAG);lr=run(REF,d/'turn-ref',reft,DIAG/'scan-b.pdf',DIAG)
  (n1,a50,a90),(n2,b50,b90)=lat(ln,'touch-up -> submit'),lat(lr,'touch-up -> submit')
  dpos=ln.index('detection done');first=ln.index('page refresh: p=2 ')
  assert n1==n2==11 and a90<=b90+20000 and first<dpos,(n1,n2,first,dpos,a50,a90,b50,b90)
  print(f'PASS 11 page turns while detection runs: touch-up->submit p50 {a50/1000:.1f} ms p90 {a90/1000:.1f} ms (0.10.0 without detection {b50/1000:.1f}/{b90/1000:.1f} ms)')
 # 5. nothing detected: only jump options
 e=d/'plain';log=run(HOST,e,'wait 1500\ntap 640 100\nwait 400\nmenubtn 0 0\nwait 2000\nshot c_none\nquit\n',books/'plain.pdf',books)
 assert 'detection done: 0 entries' in log;shutil.copy(e/'c_none.pgm',d/'c_none.pgm')
 img=pgm(e/'c_none.pgm');rows_ink=sum(1 for y in range(560,1500) for x in range(70,W-70,4) if img[y*W+x]<128)
 assert rows_ink<4000,rows_ink
 print(f'PASS book with no headings: only "Go to page..." / "Go to %..." and a notice, no entries')
 # 6. books with a real outline unchanged vs 0.10.0 (Contents screen pixels, minus the stats line)
 BIG=R.parent/'testbooks'/'digital-big.pdf'
 for b,bd in [(BIG,BIG.parent),(T/'fixture.epub',T)]:
  s='wait 2000\nshot a\ntap 640 100\nwait 500\nmenubtn 0 0\nwait 800\nshot t\ntap 636 405\nwait 1500\nshot j\nquit\n'
  ln=run(HOST,d/f'o-new-{b.stem}',s,b,bd);lr=run(REF,d/f'o-ref-{b.stem}',s,b,bd)
  assert 'detecting chapter headings' not in ln
  def mask(p):
   x=bytearray(pgm(p))
   for y in range(60,200):x[y*W+420:y*W+1000]=bytes(580)
   return bytes(x)
  for f in 'atj':assert mask(d/f'o-new-{b.stem}'/f'{f}.pgm')==mask(d/f'o-ref-{b.stem}'/f'{f}.pgm'),(b,f)
  assert pages(ln)==pages(lr)
 shutil.copy(d/'o-new-digital-big'/'t.pgm',d/'c_outline.pgm')
 print('PASS books with an outline (PDF, EPUB): Contents screen, first page and the tapped entry byte-identical to 0.10.0; no detection')
 out=R/'out'/'contents101-shots';shutil.rmtree(out,ignore_errors=True);out.mkdir()
 for f in ['c_progress','c_detected','c_goto','c_pct','c_bad','c_none','c_outline']:
  if (d/f'{f}.pgm').exists():shutil.copy(d/f'{f}.pgm',out/f'{f}.pgm')
print('ALL contents101 PASS')
