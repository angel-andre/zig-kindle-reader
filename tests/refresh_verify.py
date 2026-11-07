#!/usr/bin/env python3
"""Adaptive refresh regression. No device access or deployment."""
from pathlib import Path
import csv,collections,hashlib,json,re,subprocess,tempfile,zlib
from PIL import Image
R=Path(__file__).resolve().parent.parent
S=R/'shots';T=R/'tests'; B=R.parent/'testbooks'
def audit(name,every):
    stem='off' if every=='off' else str(every)
    f=T/f'{name}-refresh{stem}.csv'; log=T/f'{name}-refresh{stem}.log'
    with f.open('wb') as out,log.open('wb') as err:
        subprocess.run([str(R/'out/zreader-host'),'--audit-refresh','--full-refresh',str(every),'--shots',str(S),str(B/f'{name}.pdf')],stdout=out,stderr=err,check=True,timeout=120,cwd=R)
    return list(csv.DictReader(f.open()))
allrows={}
for name,total in [('digital-big',434),('digital-small1',332)]:
    for every in [8,'off']:
        rows=audit(name,every);allrows[name,every]=rows
        assert len(rows)==total
        assert all(r['update_mode']=='1' for r in rows)
        assert all(r['waveform']=='4' for r in rows if r['reason']=='text')
        assert all(r['waveform']=='2' for r in rows if r['reason']!='text')
        for r in rows:
            for f in ['ink','dark','tone','image','dark_to_light','light_to_dark']:assert 0<=float(r[f])<=1
        flashes=sum(r['waveform']=='2' for r in rows)
        print(f'PASS {name}: every={every}, {flashes}/{total} full, {flashes*100/total:.2f}/100 pages; '+str(dict(collections.Counter(r['reason'] for r in rows))),flush=True)
assert [r['waveform'] for r in allrows['digital-big',8][:4]]==['2','2','4','4']
assert float(allrows['digital-big',8][1]['dark_to_light'])>0.20
# Beyond the cover/front matter and final cover, the novel has no heavy cleans.
assert all(r['reason']=='text' for r in allrows['digital-small1','off'][3:-2])
print('PASS digital-big 1 -> 2 -> 3 -> 4 = GC16 FULL, GC16 FULL, REAGL FULL, REAGL FULL',flush=True)
def fnv(s):
    h=0xcbf29ce484222325
    for b in s.encode():h=((h^b)*0x100000001b3)&0xffffffffffffffff
    return f'{h:016x}'
def ui(data,book,page,script):
    (data/'state').mkdir(exist_ok=True)
    (data/'state'/f'{fnv(str(book))}.json').write_text(json.dumps(dict(page=page,trim=1)))
    sim=data/'case.sim';sim.write_text(script)
    result=subprocess.run([str(R/'out/zreader-host'),'--sim',str(sim),'--shots',str(S),'--data',str(data),'--books',str(book.parent),'--idle-min','0',str(book)],cwd=R,capture_output=True,timeout=25)
    assert result.returncode==0,result.stderr.decode()
    return result.stderr.decode()
with tempfile.TemporaryDirectory(dir=T,prefix='refresh-ui-') as d:
    data=Path(d)
    log=ui(data,B/'digital-big.pdf',0,'''wait 700
tap 1180 850
wait 200
tap 1180 850
wait 200
tap 1180 850
wait 200
shot 30_digital-big_p4_onreader
quit
''')
    modes=re.findall(r'page refresh: p=\d+ reason=\w+ wf=(\d+)',log)
    assert modes==['2','2','4','4'],log
    (T/'refresh-ui-sequence.log').write_text(log)
    log=ui(data,B/'digital-small1.pdf',6,'''wait 700
tap 640 850
wait 150
shot 30_refresh_menu8
tap 640 1640
wait 150
tap 640 1640
wait 150
tap 640 1640
wait 150
tap 640 1640
wait 150
shot 30_refresh_menu_off
tap 640 850
wait 150
quit
''')
    assert json.loads((data/'settings.json').read_text())['full_refresh']==0
    assert log.count('refresh submit: wf=2 full=true 1272x1696')>=2,log
    log=ui(data,B/'digital-small1.pdf',6,'''wait 700
tap 1180 850
wait 150
tap 1180 850
wait 150
quit
''')
    assert 'refresh configuration: every=0' in log,log
    assert re.findall(r'page refresh: p=\d+ reason=\w+ wf=(\d+)',log)==['2','4','4'],log
    log=ui(data,B/'digital-small1.pdf',6,"""wait 700
tap 640 850
wait 150
tap 150 85
wait 150
tap 1120 85
wait 200
quit
""")
    assert 'page refresh: p=7 reason=context wf=2' in log,log
    probe=subprocess.run([str(R/'out/render-probe'),str(B/'digital-big.pdf'),'1',str(data/'probe.pgm')],capture_output=True,check=True)
    word=probe.stdout.decode().splitlines()[2].split('\t')
    x,y=int(word[6]),int(word[7])
    log=ui(data,B/'digital-big.pdf',0,f"""wait 700
long {x} {y}
wait 150
popup 3
wait 150
quit
""")
    assert log.count('refresh submit: wf=2 full=true 1272x1696')==2,log
print('PASS actual UI sequence, menu/library return, image-popup dismissal, setting cycle and persisted off',flush=True)
# Synthetic PDF with a clipped gradient image and antialiased text outside it.
def pdf_fixture(path):
    gradient=bytes((x*255)//95 for y in range(96) for x in range(96))
    packed=zlib.compress(gradient)
    content=b'0.3 g BT /F1 13 Tf 105 350 Td (BEFORE IMAGE CLIP) Tj ET\nq 150 250 200 200 re W n 300 0 0 300 100 200 cm /Im0 Do Q\n0 g BT /F1 20 Tf 50 730 Td (TEXT AFTER IMAGE) Tj ET\n'
    objects=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> /XObject << /Im0 5 0 R >> >> /Contents 6 0 R >>',b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',f'<< /Type /XObject /Subtype /Image /Width 96 /Height 96 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode /Length {len(packed)} >>\nstream\n'.encode()+packed+b'\nendstream',f'<< /Length {len(content)} >>\nstream\n'.encode()+content+b'endstream']
    out=bytearray(b'%PDF-1.4\n');offsets=[]
    for i,obj in enumerate(objects,1):offsets.append(len(out));out+=f'{i} 0 obj\n'.encode()+obj+b'\nendobj\n'
    start=len(out);out+=f'xref\n0 {len(objects)+1}\n0000000000 65535 f \n'.encode()
    for off in offsets:out+=f'{off:010d} 00000 n \n'.encode()
    out+=f'trailer << /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n'.encode();path.write_bytes(out)
fixture=T/'image-clip-fixture.pdf';pdf_fixture(fixture)
p=subprocess.run([str(R/'out/render-stats-probe'),str(fixture),str(S/'30_dither_before.pgm'),str(S/'30_dither_after.pgm')],capture_output=True,check=True)
a=Image.open(S/'30_dither_before.pgm');b=Image.open(S/'30_dither_after.pgm')
s=1272/612;oy=(1696-792*s)/2
changed=0
for y in range(1696):
    for x in range(1272):
        va=a.getpixel((x,y));vb=b.getpixel((x,y))
        if va==vb:continue
        assert 150*s-1<=x<=350*s+1 and (792-450)*s+oy-1<=y<=(792-250)*s+oy+1,(x,y)
        assert vb%17==0
        changed+=1
assert changed>50000
# Text above/outside the image is exactly unchanged, including its AA edges.
assert a.crop((0,0,1272,500)).tobytes()==b.crop((0,0,1272,500)).tobytes()
print('PASS image-only ordered dithering: clipped footprint only, 16 levels, text bytes unchanged; '+p.stdout.decode().strip(),flush=True)
for p in S.glob('30_*.pgm'):
    im=Image.open(p);im.save(p.with_suffix('.png'));im.thumbnail((424,565));im.save(p.with_name(p.stem+'_preview.png'))
print('PASS 30-series device-resolution screenshots and compact previews',flush=True)
