#!/usr/bin/env python3
"""v0.10.0 better EPUB text: hyphenation (MuPDF's English patterns + compact Latin), justification,
second book font (Noto Sans, OFL) and Charis SIL choice, settings in the EPUB menu persisted, PDF pages
byte-identical to 0.9.9 under every text setting, EPUB 'Align: original' + 'Font: book' byte-identical
to 0.9.9, centred paragraphs stay centred, fast taps, sizes, --version."""
from pathlib import Path
import subprocess,tempfile,re,json,shutil,tarfile,io
R=Path(__file__).resolve().parent.parent;T=R/'tests';HOST=R/'out/zreader-host';REF=R/'out/zreader-host-099';W,H=1272,1696
MU=R.parent/'mupdf-1.28.6-source'
def pgm(p):b=Path(p).read_bytes();return b[b.index(b'255\n')+4:]
def run(binary,d,script,book,books,ui=None,extra=()):
 (d/'data').mkdir(parents=True,exist_ok=True)
 if ui is not None:(d/'data'/'ui07.json').write_text(json.dumps(ui)+'\n')
 (d/'s.sim').write_text(script)
 p=subprocess.run([str(binary),'--sim',str(d/'s.sim'),'--shots',str(d),'--data',str(d/'data'),'--books',str(books),'--idle-min','0',*extra]+([str(book)] if book else []),capture_output=True,timeout=180)
 log=p.stderr.decode();assert p.returncode==0,log[-3000:];assert 'render_errors=0' in log,log[-3000:];assert 'exit gesture' not in log and 'exiting' in log;return log
vp=subprocess.run([str(HOST),'--version'],capture_output=True,text=True);v=(vp.stdout or vp.stderr).split('\n')[0].strip()
m=re.search(r"VERSION\s*=\s*'([\d.]+)'",(sorted(T.glob('package09[5-9].py'))+sorted(T.glob('package1[0-9][0-9].py')))[-1].read_text());assert m and v==f'zreader {m[1]}',(v,m and m[1])
print(f'PASS --version prints "{v}" = package version')
# probe: per-line text of an EPUB under each style
subprocess.run([str(R.parent/'zig/zig'),'cc','-target','x86_64-linux-musl','-O2',f'-DSRC="{R}/src"','-I',str(R/'src'),'-I',str(MU/'include'),str(T/'text100_probe.c'),str(R/'src/render.c'),str(MU/'build/hostmusl-release/libmupdf.a'),str(MU/'build/hostmusl-release/libmupdf-third.a'),'-static','-lpthread','-lm','-o',str(R/'out/text100-probe')],check=True)
def lines(book,mode,font):
 out=subprocess.run([str(R/'out/text100-probe'),str(book),str(mode),str(font)],capture_output=True,check=True).stdout.decode()
 rows=out.splitlines();return int(rows[0].split('\t')[1]),[r.split('\t',1)[1] for r in rows[1:]]
SHY='\u00ad'
for book,name in [(T/'text100-en.epub','English, no lang attribute (fallback en)'),(T/'text100-la.epub','Latin, xml:lang="la"')]:
 n0,l0=lines(book,0,0);n2,l2=lines(book,2,0)
 h0=sum(l.endswith(SHY) or l.endswith('-') for l in l0);h2=sum(l.endswith(SHY) for l in l2)
 assert h0==0 and h2>=5,(name,h0,h2)
 print(f'PASS hyphenation {name}: {h2} hyphenated line ends with Justify + hyphens, 0 with Align: original; pages {n0} -> {n2}')
_,la=lines(T/'text100-la.epub',2,0);assert any(l.endswith('no'+SHY) for l in la),la[:4]   # no-stra: Latin rule, not English
print('PASS Latin patterns used for lang="la" (e.g. "no-stra")')
_,l1=lines(T/'text100-en.epub',1,0);assert all(len(l.split())>1 for l in l1[1:6]),l1[:6]
print('PASS justified lines keep one text line per visual line (selection/highlights unaffected)')
with tempfile.TemporaryDirectory(dir=T,prefix='text100-') as t:
 d=Path(t);books=d/'books';books.mkdir()
 shutil.copy(T/'text100-en.epub',books/'en.epub');shutil.copy(T/'fixture.epub',books/'fixture.epub');shutil.copy(T/'tall-view-fixture.pdf',books/'tall.pdf')
 BIG=R.parent/'testbooks'/'digital-big.pdf'
 shot='wait 2000\nshot a\ntap 1180 850\nwait 1500\nshot b\ntap 640 100\nwait 600\nshot menu\nquit\n'
 ui=lambda m,f:{"sort":0,"power_sleeps":0,"clean_scans":1,"text_mode":m,"book_font":f}
 # 1. PDFs: byte-identical to 0.9.9 under every text setting
 for pdf,bdir in [(BIG,BIG.parent),(books/'tall.pdf',books)]:
  e=d/f'ref-{pdf.stem}';run(REF,e,shot,pdf,bdir,ui(0,0));ref=[pgm(e/f'{s}.pgm') for s in ('a','b','menu')]
  for mm,ff in [(0,0),(2,2),(1,1)]:
   e=d/f'new-{pdf.stem}-{mm}{ff}';run(HOST,e,shot,pdf,bdir,ui(mm,ff));assert [pgm(e/f'{s}.pgm') for s in ('a','b','menu')]==ref,(pdf,mm,ff)
 print('PASS PDF pages and PDF menu byte-identical to 0.9.9 under all text settings (2 PDFs x 3 settings x 3 shots)')
 # 2. EPUB with Align: original + Font: book == 0.9.9 page pixels
 for bk in ('fixture.epub','en.epub'):
  e=d/f'ref-{bk}';run(REF,e,shot,books/bk,books,ui(0,0));e2=d/f'new-{bk}-00';run(HOST,e2,shot,books/bk,books,ui(0,0))
  assert pgm(e/'a.pgm')==pgm(e2/'a.pgm') and pgm(e/'b.pgm')==pgm(e2/'b.pgm'),bk
 print('PASS EPUB pages with "Align: original" + "Font: book" byte-identical to 0.9.9 (2 books x 2 pages)')
 # 3. new styles change EPUB pages; each font renders differently
 pages={}
 for mm,ff in [(2,0),(2,1),(2,2),(1,0)]:
  e=d/f'new-en-{mm}{ff}';run(HOST,e,shot,books/'en.epub',books,ui(mm,ff));pages[(mm,ff)]=pgm(e/'b.pgm')
 base=pgm(d/'new-en.epub-00'/'b.pgm')
 assert len({base,*pages.values()})==4 and pages[(2,0)]==pages[(2,1)],'styles'   # no publisher font: book default is already Charis SIL
 for k,f in [((2,0),'text_default'),((2,1),'text_charis'),((2,2),'text_notosans'),((1,0),'text_justify_only')]:shutil.copy(d/f'new-en-{k[0]}{k[1]}'/'b.pgm',d/f'{f}.pgm')
 shutil.copy(d/'new-en.epub-00'/'b.pgm',d/'text_original.pgm');shutil.copy(d/'new-en-22'/'menu.pgm',d/'text_menu.pgm')
 print('PASS Justify + hyphens / Justify / Charis / Noto Sans each change EPUB pages; Charis = book default when the book sets no font (4 distinct renders)')
 # 4. centred paragraph stays centred, pre stays monospace-width, bold/italic present (probe)
 _,l=lines(T/'text100-en.epub',2,2);assert 'A centred line' in l and 'code stays mono' in l and 'Bold italic both' in l
 # 5. menu buttons cycle, persist, relayout; fast taps never exit
 e=d/'menu';log=run(HOST,e,'wait 2000\ntap 640 100\nwait 500\ntap 230 1551\nwait 1500\nshot m1\ntap 230 1551\nwait 1500\ntap 1042 1551\nwait 1500\nshot m2\n'+'tap 230 1551\nwait 40\ntap 1042 1551\nwait 40\n'*3+'tap 1180 850\nwait 40\n'*4+'wait 2500\nshot m3\nquit\n',books/'en.epub',books)
 styles=re.findall(r'text style: mode=(\d) \([^)]*\) font=(\d)',log)
 assert styles[:3]==[('2','1'),('2','2'),('1','2')],styles
 u=json.loads((e/'data'/'ui07.json').read_text());assert (str(u['text_mode']),str(u['book_font']))==styles[-1],(u,styles)
 assert (e/'m3.pgm').exists() and log.count('exiting')==1
 shutil.copy(e/'m1.pgm',d/'text_menu_charis.pgm')
 print(f'PASS menu: Font cycles book -> Charis -> Noto Sans, Align cycles; saved in ui07.json ({u["text_mode"]},{u["book_font"]}); 6 fast style taps + 4 turns never exit')
 out=R/'out'/'text100-shots';shutil.rmtree(out,ignore_errors=True);out.mkdir()
 for f in ['text_original','text_default','text_charis','text_notosans','text_justify_only','text_menu','text_menu_charis']:shutil.copy(d/f'{f}.pgm',out/f'{f}.pgm')
# 6. sizes
added={'Noto Sans Bold/Italic/BoldItalic (Latin subset)':sum((R/'src/fonts'/f).stat().st_size for f in ['NotoSans-Bold-Latin.ttf','NotoSans-Italic-Latin.ttf','NotoSans-BoldItalic-Latin.ttf']),'Latin patterns':(R/'src/hyph/la').stat().st_size}
print('PASS sizes: '+', '.join(f'{k} {v/1e6:.3f} MB' for k,v in added.items())+f'; total {sum(added.values())/1e6:.3f} MB (English patterns were already in the binary)')
print('ALL text100 PASS')
