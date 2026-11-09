#!/usr/bin/env python3
"""Black-box host/UI checks. Run after ./build.sh and tests/run.sh.
Requires my local test PDF; it is deliberately not distributed.
"""
from pathlib import Path
import hashlib,json,struct,subprocess,tempfile,zipfile
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
BOOK=ROOT.parent/'testbooks/digital-small1.pdf'
SHOTS=ROOT/'shots'
EXPECTED='could think to say at that exact moment was this: “If Edgar Allan Mitchell—the sixth man to walk on the'
def fnv(s):
    h=0xcbf29ce484222325
    for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
    return f'{h:016x}'
def run(script,page=6,book=BOOK,shots=SHOTS):
    with tempfile.TemporaryDirectory(prefix='run-verify-',dir=ROOT/'tests') as tmp:
        data=Path(tmp);(data/'state').mkdir()
        (data/'state'/f'{fnv(str(book))}.json').write_text(json.dumps(dict(page=page,trim=1)))
        sim=data/'test.sim';sim.write_text(script)
        p=subprocess.run([str(ROOT/'out/zreader-host'),'--sim',str(sim),'--shots',str(shots),'--data',tmp,'--books',str(book.parent),'--idle-min','0',str(book)],cwd=ROOT,capture_output=True,timeout=35)
        assert p.returncode==0,p.stderr.decode()
        log=p.stderr.decode();assert 'render_errors=0' in log,log
        notes=[json.loads(f.read_text()) for f in (data/'notes').glob('*.json')]
        txt=''.join(f.read_text() for f in (data/'notes').glob('*.txt'))
        states=[json.loads(f.read_text()) for f in (data/'state').glob('*.json')]
        return notes,txt,log,states
# Test real evdev events through the host main loop, not just unit calls.
notes,txt,log,_=run((ROOT/'tests/ui.sim').read_text())
assert notes==[[dict(notes[0][0],style='note',text=EXPECTED)]] and len(notes[0])==1
assert notes[0][0]['text']==EXPECTED and notes[0][0]['page']==7
assert len(notes[0][0]['quads'])==2
assert txt.count(EXPECTED)==1 and 'Underline' not in txt and 'Highlight' not in txt
(ROOT/'tests/ui-verified.log').write_text(log)
print('PASS physical-input stream: cross-line drag, underline, tap-to-edit, style change, copy and delete; JSON/TXT exact')
# Move each existing handle using normal down/move/up (swipe has no long hold).
notes,txt,log,_=run('''wait 1000
long 288 548 300 585
wait 200
swipe 253 588 329 588
wait 200
swipe 318 626 276 626
wait 200
popup 1
wait 200
quit
''')
assert notes[0][0]['text']=='think to say at that exact moment was this: “If Edgar Allan Mitchell—the sixth man to walk on',notes
assert notes[0][0]['style']=='highlight'
print('PASS both physical-input handle adjustments: exact trimmed endpoints')
# Reverse selection, including a line break.
notes,_,_,_=run('''wait 1000
long 300 585 288 548
wait 200
popup 0
wait 200
quit
''')
assert notes[0][0]['text']==EXPECTED,notes
print('PASS reversed physical-input selection preserves reading order')
# Page turns and menus remain on the existing prefetch/cache path.
_,_,log,states=run('''wait 1000
tap 1180 850
wait 300
tap 1180 850
wait 300
tap 1180 850
wait 300
tap 640 850
wait 200
shot 26_menu_regression
menubtn 0 0
wait 200
shot 27_contents_regression
tap 1120 80
wait 200
tap 640 850
wait 200
menubtn 0 1
wait 200
shot 28_notes_regression
tap 1120 80
wait 200
quit
''')
assert 'turns=3' in log and 'wf=reagl' in log,log
assert states[0]['page']==9,states
print('PASS 3 cached page turns, menu, contents and notes; REAGL retained')
# Minimal self-authored EPUB fixture: no copyrighted book is bundled.
fixture=ROOT/'tests/fixture.epub'
with zipfile.ZipFile(fixture,'w') as z:
    z.writestr('mimetype','application/epub+zip',compress_type=zipfile.ZIP_STORED)
    z.writestr('META-INF/container.xml','''<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''')
    z.writestr('content.opf','''<package version="2.0" unique-identifier="id" xmlns="http://www.idpf.org/2007/opf"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Reader regression</dc:title><dc:identifier id="id">reader-regression</dc:identifier><dc:language>en</dc:language></metadata><manifest><item id="body" href="body.xhtml" media-type="application/xhtml+xml"/><item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="toc"><itemref idref="body"/></spine></package>''')
    z.writestr('toc.ncx','''<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head/><docTitle><text>Reader regression</text></docTitle><navMap><navPoint id="c1" playOrder="1"><navLabel><text>Chapter one</text></navLabel><content src="body.xhtml"/></navPoint></navMap></ncx>''')
    z.writestr('body.xhtml','<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Reader regression</title></head><body><h1>Chapter one</h1>'+('<p>Exact words matter. A reader should keep its place and let us choose each passage carefully. The quiet lake reflects a clear sky.</p>'*180)+'</body></html>')
_,_,log,states=run('''wait 1200
tap 640 850
wait 200
menubtn 1 1
wait 400
shot 29_epub_larger_text
tap 640 850
wait 200
tap 1180 850
wait 500
quit
''',page=0,book=fixture)
assert 'reflow=true' in log and 'render_errors=0' in log,log
assert any(s.get('font')==10.5 and s.get('page')==1 for s in states),states
print('PASS EPUB open/reflow, font increase and page turn')
# Assert ELF target properties directly (no file(1) dependency).
arm=(ROOT/'out/zreader').read_bytes();host=(ROOT/'out/zreader-host').read_bytes()
for binary,machine,elfclass in [(arm,40,1),(host,62,2)]:
    assert binary[:4]==b'\x7fELF' and binary[4]==elfclass
    if machine==40: assert struct.unpack_from('<I',binary,36)[0]&0x400, 'expected ARM hard-float ABI'
    assert struct.unpack_from('<H',binary,18)[0]==machine
    if elfclass==1: off=struct.unpack_from('<I',binary,28)[0];size,num=struct.unpack_from('<HH',binary,42)
    else: off=struct.unpack_from('<Q',binary,32)[0];size,num=struct.unpack_from('<HH',binary,54)
    assert all(struct.unpack_from('<I',binary,off+i*size)[0]!=3 for i in range(num)), 'unexpected PT_INTERP'
print('PASS ARM EABI static executable and static host executable')
# Evidence is honest: the renderer still reproduces the defective source PDF.
for before,after in [('20_dropcap_before','21_dropcap_after'),('20b_edward_before','21b_edward_after')]:
    assert Image.open(SHOTS/(before+'.png')).tobytes()==Image.open(SHOTS/(after+'.pgm')).tobytes()
print('PASS source-fidelity comparison: drop-cap pixels unchanged (SOURCE LAYOUT STILL DEFECTIVE, NOT FIXED)')
for p in SHOTS.glob('*.pgm'):
    im=Image.open(p);assert im.size==(1272,1696)
    im.save(p.with_suffix('.png'));im.thumbnail((636,848));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS device-resolution screenshots and small PNG previews generated')
