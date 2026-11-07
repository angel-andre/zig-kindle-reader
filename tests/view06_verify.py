#!/usr/bin/env python3
from pathlib import Path
import json,subprocess,tempfile,hashlib,re
from PIL import Image
R=Path(__file__).resolve().parent.parent;T=R/'tests';S=R/'shots'
def make_pdf(p):
    objs=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>']
    for content in [6,7]:objs.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 2000] /Resources << /Font << /F1 5 0 R >> >> /Contents {content} 0 R >>'.encode())
    objs.append(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    for page in [1,2]:
        stream=b'0 g\n'+b''.join(f'BT /F1 13 Tf 60 {1940-i*16} Td (Page {page} row {i:03d}: exact words remain readable across viewport slices.) Tj ET\n'.encode() for i in range(119))
        objs.append(f'<< /Length {len(stream)} >>\nstream\n'.encode()+stream+b'endstream')
    data=bytearray(b'%PDF-1.4\n');offs=[]
    for i,o in enumerate(objs,1):offs.append(len(data));data+=f'{i} 0 obj\n'.encode()+o+b'\nendobj\n'
    start=len(data);data+=f'xref\n0 {len(objs)+1}\n0000000000 65535 f \n'.encode()
    for o in offs:data+=f'{o:010d} 00000 n \n'.encode()
    data+=f'trailer << /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n'.encode();p.write_bytes(data)
def fnv(s):
    h=0xcbf29ce484222325
    for c in s.encode():h=((h^c)*0x100000001b3)&0xffffffffffffffff
    return f'{h:016x}'
book=T/'tall-view-fixture.pdf';make_pdf(book)
def run(data,script):
    (data/'state').mkdir(exist_ok=True);sim=data/'case.sim';sim.write_text(script)
    p=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(data),'--books',str(T),'--idle-min','0',str(book)],cwd=R,capture_output=True,timeout=30)
    assert p.returncode==0,p.stderr.decode()
    assert 'render_errors=0' in p.stderr.decode()
    return p.stderr.decode(),json.loads((data/'state'/f'{fnv(str(book))}.json').read_text())
with tempfile.TemporaryDirectory(prefix='view-ui-',dir=T) as tmp:
    data=Path(tmp);(data/'state').mkdir()
    (data/'state'/f'{fnv(str(book))}.json').write_text('{"page":1,"trim":1}')
    log,st=run(data,'''wait 800
shot 40_fit_page
tap 640 850
wait 300
menubtn 1 0
wait 250
tap 640 850
wait 250
shot 41_fit_width_top
tap 1180 850
wait 250
shot 42_fit_width_next
tap 640 850
wait 50
tap 640 850
wait 300
shot 43_zoom15
swipe 900 1100 500 700
wait 250
shot 44_zoom_pan
tap 640 850
wait 50
tap 640 850
wait 300
shot 45_zoom2
quit
''')
    assert 'PDF slice: page=2 step=2/' in log,log
    assert 'PDF view: Fit width' in log and 'PDF view: Zoom 1.5x' in log and 'PDF view: Zoom 2x' in log,log
    assert 'PDF pan:' in log
    assert st['view']==3 and (st['pan_x']>0 or st['pan_y']>0),st
    (T/'view06-ui.log').write_text(log)
    log,restored=run(data,'wait 800\nshot 46_view_restored\nquit\n')
    assert restored['view']==st['view'] and restored['pan_x']==st['pan_x'] and restored['pan_y']==st['pan_y']
    assert (S/'45_zoom2.pgm').read_bytes()==(S/'46_view_restored.pgm').read_bytes()
    # Fit width state survives reopen at the exact slice and can step backwards.
    (data/'state'/f'{fnv(str(book))}.json').write_text('{"page":1,"view":1,"view_step":1,"trim":0}')
    log,st=run(data,'''wait 800
shot 47_width_restored
tap 80 850
wait 250
shot 48_width_previous
quit
''')
    assert 'PDF slice: page=2 step=1/' in log
    assert st['view']==1 and st['view_step']==0
print('PASS real touch: fit-page, auto-cropped fit-width, next/previous slices, double-tap 1.5x/2x, pan and exact per-book restore')
assert Image.open(S/'40_fit_page.pgm').tobytes()!=Image.open(S/'41_fit_width_top.pgm').tobytes()
assert Image.open(S/'41_fit_width_top.pgm').tobytes()!=Image.open(S/'42_fit_width_next.pgm').tobytes()
assert Image.open(S/'43_zoom15.pgm').tobytes()!=Image.open(S/'44_zoom_pan.pgm').tobytes()
for p in S.glob('4[0-9]_*.pgm'):
    im=Image.open(p);assert im.size==(1272,1696);im.save(p.with_suffix('.png'));im.thumbnail((424,565));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS view screenshots/previews and unchanged fixed-size raster buffers')
