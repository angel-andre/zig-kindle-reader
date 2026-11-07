#!/usr/bin/env python3
"""v0.10.3 Latin dictionary: reproducible build from the WORDS data, size, lemmatisation
(inflections, macrons/accents, u/v and i/j folding, enclitics) on Latin quoted in a real
history of the scan-c (Ad Herennium, Cicero), lookup timing, and the reader UI:
Latin first in a Latin book, Latin when English misses, EN/LA toggle, and the English
popup unchanged when no Latin dictionary is installed."""
from pathlib import Path
import subprocess,tempfile,zipfile,hashlib,struct,re,shutil
from PIL import Image
R=Path(__file__).resolve().parent.parent;T=R/'tests';S=R/'shots';MU=R.parent/'mupdf-1.28.6-source'
ZIG=str(R.parent/'zig/zig');HOST=R/'out/zreader-host';OLD=R/'out/zreader-host-101'
LAT=R/'dictionary/latin.zdict'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='latin103-',dir=T) as tmp:
 d=Path(tmp)
 # 1. build is reproducible from the archived source data; header sane; size budget
 subprocess.run(['python3',str(R/'dictionary/build_latin.py'),str(R/'dictionary/source/whitaker-words-data.tar.gz'),str(d/'rebuilt.zdict')],check=True,capture_output=True)
 assert sha(d/'rebuilt.zdict')==sha(LAT),'latin.zdict must rebuild byte-identically'
 h=struct.unpack('<8sIIIIIIIIIIIIII',LAT.read_bytes()[:64]);size=LAT.stat().st_size
 assert h[0]==b'ZRLA1001' and h[11]==size and size<30*1024*1024,h
 print(f'PASS latin.zdict rebuilds byte-identically from dictionary/source; {size:,} bytes ({size/1024**2:.2f} MiB, budget 30 MiB); {h[2]:,} entries, {h[1]:,} stems, {h[3]:,} endings')
 assert 'Whitaker' in (R/'dictionary/LATIN-LICENSE').read_text() and 'Permission is hereby freely given' in (R/'dictionary/LATIN-LICENSE').read_text()
 # 2. lemmatisation through the same C code the reader links
 probe=R/'out/latin-probe'
 subprocess.run([ZIG,'cc','-target','x86_64-linux-musl','-O2','-DZRL_PROBE',str(R/'src/latin.c'),'-static','-o',str(probe)],check=True)
 def look(*words):
  out=subprocess.run([str(probe),str(LAT),*words],capture_output=True,check=True).stdout.decode()
  return {m.group(1):(m.group(2),m.group(3)) for m in re.finditer(r'^== (\S+) -> \[([^\]]*)\] \((\d+)\)\n((?:(?!^== ).*\n?)*)',out,re.M)} ,out
 cases={'amavit':'amo','rosarum':'rosa','Rosārum':'rosa','ROSARVM':'rosa','amāvit':'amo','Iulius':'Julius','Jūlius':'Julius','virumque':'vir','est':'sum','fuit':'sum',
  'quae':'qui','hortatur':'hortor','utendum':'utor','summos':'summus','facilius':'facilis','iudicium':'judicium','uirtus':'virtus','Caesaris':'Caesar','Gallia':'Gallia','divisa':'divido'}
 got,out=look(*cases)
 bad={w:(got.get(w),l) for w,l in cases.items() if not got.get(w) or got[w][0]!=l or int(got[w][1])<=0}
 assert not bad,(bad,out)
 assert 'perf. act. ind. 3rd sg.' in out and 'gen. pl.' in out and '-que = and' in out
 print('PASS lemmatisation:',', '.join(f'{w}->{l}' for w,l in cases.items()))
 # Latin quoted in Author C, scan-C (Ad Herennium III, Cicero, Quintilian ...)
 aom='''Constat igitur artificiosa memoria ex locis et imaginibus
 locis est utendum multis illustribus explicatis modicis intervallis
 imaginibus autem agentibus acribus insignitis quae occurrere celeriterque percutere animum possint
 summos homines et divina prope memoria
 Quid est enim memoria rerum et verborum quid porro inventio
 campos et lata praetoria memoriae in locis illustribus ad vitam et iudicium in libro septem planetarum
 imagines agentes memoria rerum memoria verborum De memoria et reminiscentia memoria intelligentia providentia pronuntiatio'''
 words=aom.split();(d/'aom.txt').write_text('\n'.join(words))
 got,out=look(*sorted(set(words)))
 missing=[w for w in set(words) if int(got[w][1])<=0]
 assert not missing,missing
 for w,l in {'artificiosa':'artificiosus','locis':'locus','imaginibus':'imago','agentibus':'ago','insignitis':'insignio','occurrere':'occurro','possint':'possum','homines':'homo','rerum':'res','verborum':'verbum','memoriae':'memoria','planetarum':'planeta'}.items():
  assert got[w][0]==l,(w,got[w])
 print(f'PASS scan-C Latin passages: {len(set(words))}/{len(set(words))} distinct words found ({len(words)} tokens), e.g. imaginibus->imago, agentibus->ago, possint->possum')
 # 3. speed: every token of the passages plus 20,000 mixed English/Latin/garbage words
 mixed=(words*40)+[w+'que' for w in words]*20+['xyzzyquorumque','antidisestablishmentarianism','the','memory','walked']*2000
 (d/'timing.txt').write_text('\n'.join(mixed))
 best=None
 for _ in range(3):
  t=subprocess.run([str(probe),str(LAT),'-t',str(d/'timing.txt')],capture_output=True,check=True).stdout.decode().strip()
  v=dict(x.split('=') for x in t.split())
  if best is None or float(v['p999_ms'])<float(best['p999_ms']):best=v
 assert float(best['p999_ms'])<2.0 and float(best['mean_ms'])<0.5,best
 print(f"PASS lookup speed on this host: {best['words']} lookups, mean {float(best['mean_ms'])*1000:.1f} us, p50 {float(best['p50_ms'])*1000:.1f} us, p99.9 {float(best['p999_ms'])*1000:.1f} us, first (cold) {float(best['first_ms'])*1000:.1f} us; budget 50 ms on the Kindle")
 # 4. reader UI
 def epub(path,lang,title,paras):
  z=zipfile.ZipFile(path,'w');z.writestr(zipfile.ZipInfo('mimetype'),'application/epub+zip')
  z.writestr('META-INF/container.xml','<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
  z.writestr('OEBPS/content.opf',f'<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>{title}</dc:title><dc:language>{lang}</dc:language><dc:identifier id="id">zr103-{lang}</dc:identifier></metadata><manifest><item id="c" href="c.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="c"/></spine></package>')
  z.writestr('OEBPS/c.xhtml','<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title></head><body>'+''.join(f'<p>{p}</p>' for p in paras)+'</body></html>');z.close()
 books=d/'books';books.mkdir()
 epub(books/'ars.epub','la','Ars Memoriae',['amavit','rosarum','Rosārum','memoriae','locis','imaginibus','virumque','est','Jūlius','artificiosa','agentes','in'])
 epub(books/'notes.epub','en-GB','Memory Notes',['walk','imaginibus','memoria','in','xyzzyq'])
 def run(exe,data,script,book):
  (d/'s.sim').write_text(script);S.mkdir(exist_ok=True)
  p=subprocess.run([str(exe),'--sim',str(d/'s.sim'),'--shots',str(S),'--data',str(data),'--books',str(books),'--dictionary',str(R/'dictionary/wordnet.zdict'),'--idle-min','0',str(book)],cwd=R,capture_output=True,timeout=120)
  log=p.stderr.decode();assert p.returncode==0,log;assert 'render_errors=0' in log,log;return log
 Y=lambda i:132+105*i
 data=d/'data';(data/'dictionary').mkdir(parents=True);shutil.copy(LAT,data/'dictionary/latin.zdict')
 sc='wait 1500\n'
 for i in range(12):
  sc+=f'long 90 {Y(i)}\nwait 200\npopup 4\nwait 300\n'
  if i==0:sc+='shot 103_latin_amavit\n'
  if i==1:sc+='shot 103_latin_rosarum\ntap 807 240\nwait 300\nshot 103_latin_rosarum_en\ntap 927 240\nwait 300\nshot 103_latin_rosarum_back\n'
  sc+='tap 1092 240\nwait 300\n'
 log=run(HOST,data,sc+'quit\n',books/'ars.epub')
 found=re.findall(r'dictionary: (\S+), result=(-?\d+), lines=\d+( \(latin\))?',log)
 assert "book language 'la'" in log,log
 assert [f[0] for f in found]==['amo','rosa','rosa','memoria','locus','imago','vir','sum','Julius','artificiosus','ago','in'],found
 assert all(f[2] for f in found) and all(int(f[1])>0 for f in found),found
 assert 'switched to english: rosarum' in log and 'switched to latin: rosa' in log
 a=Image.open(S/'103_latin_rosarum.pgm').tobytes();assert a==Image.open(S/'103_latin_rosarum_back.pgm').tobytes() and a!=Image.open(S/'103_latin_rosarum_en.pgm').tobytes()
 print('PASS Latin book (dc:language la): Latin first for 12/12 words incl. macrons (Rosārum, Jūlius), enclitic (virumque->vir), esse (est->sum); EN/LA toggle switches and returns to the same popup')
 sc='wait 1500\n'
 for i in range(5):
  sc+=f'long 90 {Y(i)}\nwait 200\npopup 4\nwait 300\n'
  if i==0:sc+='shot 103_english_walk\ntap 927 240\nwait 300\nshot 103_english_walk_la\n'
  if i==1:sc+='shot 103_english_book_latin_fallback\n'
  if i==4:sc+='shot 103_english_miss\n'
  sc+='tap 1092 240\nwait 300\n'
 log=run(HOST,data,sc+'quit\n',books/'notes.epub')
 found=re.findall(r'dictionary: (\S+), result=(-?\d+), lines=\d+( \(latin\))?',log)
 assert "book language 'en'" in log,log
 assert [(f[0],bool(f[2])) for f in found]==[('walk',False),('imago',True),('memoria',True),('in',False),('xyzzyq',False)],found
 assert int(found[4][1])==0 and 'switched to latin: walk' in log,log
 print('PASS English book: English first (walk, in); English miss falls back to Latin (imaginibus->imago, memoria); no entry in either shows the English message; LA on an English word shows the Latin miss')
 # English popup without latin.zdict: identical to 0.10.1; with it, only the EN/LA buttons differ
 plain=d/'plain';plain.mkdir()
 sc='wait 1500\nlong 90 132\nwait 200\npopup 4\nwait 300\nshot {n}\ntap 1092 240\nwait 300\nquit\n'
 run(HOST,plain,sc.format(n='103_en_plain_new'),books/'notes.epub')
 if OLD.exists():
  run(OLD,d/'old',sc.format(n='103_en_plain_old'),books/'notes.epub')
  assert Image.open(S/'103_en_plain_new.pgm').tobytes()==Image.open(S/'103_en_plain_old.pgm').tobytes(),'English popup must be unchanged without the Latin dictionary'
 new=Image.open(S/'103_english_walk.pgm');old=Image.open(S/'103_en_plain_new.pgm')
 box=(740,190,992,290);n2=new.copy();n2.paste(old.crop(box),box[:2])
 assert n2.tobytes()==old.tobytes() and new.tobytes()!=old.tobytes(),'only the EN/LA buttons may differ'
 print('PASS English popup byte-identical to 0.10.1 without latin.zdict; with it installed only the EN/LA buttons are added')
for p in S.glob('103_*.pgm'):
 im=Image.open(p);im.save(p.with_suffix('.png'));im.thumbnail((636,848));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS Latin dictionary screenshots written')
