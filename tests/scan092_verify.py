# v0.9.2 "Clean up scanned pages": synthetic sepia scan is cleaned; digital pages are byte-identical on vs off.
from pathlib import Path
import subprocess,tempfile,zlib,random,math,re
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parent.parent;P=R/'out/scan092-probe'
def pdf(path,pw,ph,images,content,group=False):
 """minimal PDF: images=[(name,w,h,gray_bytes)], content=page stream (uses /F1 Helvetica)."""
 objs=[];add=lambda b:objs.append(b) or len(objs)
 xo=[]
 for name,w,h,data in images:
  z=zlib.compress(data);n=add(b'<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode /Length %d >>\nstream\n'%(w,h,len(z))+z+b'\nendstream')
  xo.append(b'/%s %d 0 R'%(name.encode(),n))
 font=add(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
 c=content.encode()
 if group:  # wrap the content in a transparency-group form XObject (as many scanners/producers do)
  fm=add(b'<< /Type /XObject /Subtype /Form /BBox [0 0 %d %d] /Group << /S /Transparency >> /Resources << /Font << /F1 %d 0 R >> /XObject << %s >> >> /Length %d >>\nstream\n'%(pw,ph,font,b' '.join(xo),len(c))+c+b'\nendstream')
  xo.append(b'/Fm0 %d 0 R'%fm);c=b'q /Fm0 Do Q'
 cs=add(b'<< /Length %d >>\nstream\n'%len(c)+c+b'\nendstream')
 pages_n=len(objs)+2
 page=add(b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] /Resources << /Font << /F1 %d 0 R >> /XObject << %s >> >> /Contents %d 0 R >>'%(pages_n,pw,ph,font,b' '.join(xo),cs))
 add(b'<< /Type /Pages /Kids [%d 0 R] /Count 1 >>'%page);cat=add(b'<< /Type /Catalog /Pages %d 0 R >>'%pages_n)
 out=bytearray(b'%PDF-1.4\n');offs=[]
 for i,o in enumerate(objs,1):offs.append(len(out));out+=b'%d 0 obj\n'%i+o+b'\nendobj\n'
 x=len(out);out+=b'xref\n0 %d\n0000000000 65535 f \n'%(len(objs)+1)+b''.join(b'%010d 00000 n \n'%o for o in offs)
 out+=b'trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n'%(len(objs)+1,cat,x);Path(path).write_bytes(out)
def sepia_scan(w=1200,h=1600,seed=3):
 rnd=random.Random(seed);im=Image.new('L',(w,h))
 px=im.load()
 for y in range(h):
  for x in range(0,w):
   v=196-22*((x-w/2)**2+(y-h/2)**2)/((w/2)**2+(h/2)**2)+8*math.sin(y/90)+rnd.uniform(-2,2)
   px[x,y]=int(v)
 d=ImageDraw.Draw(im)
 try:f=ImageFont.truetype(str(R/'src/fonts/NotoSans-Regular.ttf'),30)
 except Exception:f=ImageFont.load_default()
 for i in range(38):d.text((90,90+i*38),'The frontier settlers moved west along the river valley %d'%i,fill=48,font=f)
 return im
def photo(w=900,h=1200):
 im=Image.new('L',(w,h));px=im.load()
 for y in range(h):
  for x in range(w):px[x,y]=int(127+120*math.sin(x/37.0)*math.cos(y/53.0))
 return im
def render(path,page,flags,out,reps=1):
 r=subprocess.run([str(P),str(path),str(page),str(flags),str(out),str(reps)],capture_output=True,text=True,check=True).stdout
 m=re.search(r'cleaned=(\d+) image_count=(\d+) coverage=([\d.]+) best_ms=([\d.]+)',r);return int(m[1]),int(m[2]),float(m[3]),float(m[4])
def pix(p):b=Path(p).read_bytes();return b[b.index(b'\n')+1:]
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='scan092-') as t:
 d=Path(t)
 sc=sepia_scan();sp=d/'sepia-scan.pdf';pdf(sp,612,816,[('Im0',sc.width,sc.height,sc.tobytes())],'q 612 0 0 816 0 0 cm /Im0 Do Q BT /F1 0 Tf 3 Tr ET')
 cb=render(sp,0,1,d/'before.pgm');ca=render(sp,0,3,d/'after.pgm')
 assert cb[0]==0 and ca[0]==1,(cb,ca)
 b,a=pix(d/'before.pgm'),pix(d/'after.pgm');W,H=1272,1696
 # paper mask = pixels that are paper in the source (no text): use the source image resampled
 from PIL import ImageFilter
 src=sc.resize((W,H)).tobytes();far=sc.resize((W,H)).filter(ImageFilter.MinFilter(9)).tobytes();mask=[i for i in range(0,W*H,7) if far[i]>150]  # paper at least 4 px from any text
 ink=[i for i in range(0,W*H,3) if src[i]<70]
 def levels(img,idx):
  from collections import Counter;c=Counter(img[i] for i in idx);n=len(idx);return sorted((v,k*100/n) for v,k in c.items() if k*100/n>=1)
 lb,la=levels(b,mask),levels(a,mask)
 white=sum(1 for i in mask if a[i]>=250)/len(mask)
 inkb=sum(b[i] for i in ink)/len(ink);inka=sum(a[i] for i in ink)/len(ink)
 paperb=sum(b[i] for i in mask)/len(mask)
 assert white>=0.97,(white,levels(a,mask))
 assert len(la)<=1 and len(lb)>=3,(lb,la)
 assert inka<=inkb+2 and (255-inka)>=(paperb-inkb),(inka,inkb,paperb)
 print(f'PASS sepia scan: paper {paperb:.0f} -> white on {white*100:.1f}% of paper pixels; paper gray levels with >=1% share: before {len(lb)} {[v for v,_ in lb]}, after {len(la)} {[v for v,_ in la]}; ink mean {inkb:.0f} -> {inka:.0f} (contrast {paperb-inkb:.0f} -> {255-inka:.0f})')
 tb=render(sp,0,1,d/'x.pgm',15)[3];ta=render(sp,0,3,d/'x.pgm',15)[3]
 print(f'TIMING host: scanned page render best-of-15 {tb:.2f} ms without cleanup, {ta:.2f} ms with (+{ta-tb:.2f} ms)')
 Image.frombytes('L',(W,H),b).save(d/'synthetic-before.png');Image.frombytes('L',(W,H),a).save(d/'synthetic-after.png')
 import shutil;shutil.copy(d/'synthetic-before.png',R.parent/'stage/zr092-synthetic-before.png');shutil.copy(d/'synthetic-after.png',R.parent/'stage/zr092-synthetic-after.png')
 # scans whose page is drawn in several raster layers or inside a transparency group are cleaned too
 lay=Image.new('L',(400,100),255);ImageDraw.Draw(lay).text((10,10),'layer',fill=0)
 for nm,kw,cont in [('layered',{},'q 612 0 0 816 0 0 cm /Im0 Do Q q 300 0 0 75 100 300 cm /Im1 Do Q'),('grouped',{'group':True},'q 612 0 0 816 0 0 cm /Im0 Do Q')]:
  q=d/(nm+'.pdf');pdf(q,612,816,[('Im0',sc.width,sc.height,sc.tobytes()),('Im1',400,100,lay.tobytes())],cont,**kw)
  c=render(q,0,3,d/'x.pgm');assert c[0]==1,(nm,c)
  x=pix(d/'x.pgm');wf=sum(1 for i in mask if x[i]>=250)/len(mask);assert wf>=0.9,(nm,wf)
 print('PASS layered scan (two raster layers) and grouped scan (transparency group) are cleaned')
 import os;rs=Path(os.environ.get('ZR_REAL_SCAN',''))  # optional: a real layered scan PDF (not included)
 if os.environ.get('ZR_REAL_SCAN') and rs.exists():
  got=[render(rs,pg,3,d/'x.pgm')[0] for pg in (20,40,100)];assert got==[1,1,1],got
  print('PASS real archive-style scan (separated layers in a group): pages 20/40/100 cleaned')
 # digital content: must be byte-identical with cleanup on vs off (both with dithering on and off)
 ph=photo();fig=d/'figure.pdf';pdf(fig,612,792,[('Im0',ph.width,ph.height,ph.tobytes())],'BT /F1 14 Tf 72 740 Td (A digital page with a figure and text.) Tj ET q 300 0 0 400 156 250 cm /Im0 Do Q BT /F1 11 Tf 72 200 Td (Figure 1: caption text under the photo.) Tj ET')
 bg=d/'background.pdf';pdf(bg,612,816,[('Im0',sc.width,sc.height,sc.tobytes())],'q 612 0 0 816 0 0 cm /Im0 Do Q BT /F1 18 Tf 72 400 Td (Visible digital text over a full-page background image) Tj ET')
 full_photo=d/'fullphoto.pdf';pdf(full_photo,612,816,[('Im0',ph.width,ph.height,ph.tobytes())],'q 612 0 0 816 0 0 cm /Im0 Do Q')
 vec=d/'vector.pdf';pdf(vec,612,792,[],'0.9 g 50 50 500 690 re f 0 g BT /F1 24 Tf 72 700 Td (Vector and text only) Tj ET 0.5 G 4 w 72 600 m 540 600 l S')
 lt=d/'layered-text.pdf';pdf(lt,612,816,[('Im0',sc.width,sc.height,sc.tobytes()),('Im1',400,100,lay.tobytes())],'q 612 0 0 816 0 0 cm /Im0 Do Q q 300 0 0 75 100 300 cm /Im1 Do Q BT /F1 18 Tf 72 400 Td (Visible text after two image layers) Tj ET')
 gt=d/'grouped-text.pdf';pdf(gt,612,816,[('Im0',sc.width,sc.height,sc.tobytes())],'q 612 0 0 816 0 0 cm /Im0 Do Q BT /F1 18 Tf 72 400 Td (Visible text in a group over a background image) Tj ET',group=True)
 gf=d/'grouped-figure.pdf';pdf(gf,612,792,[('Im0',ph.width,ph.height,ph.tobytes())],'BT /F1 14 Tf 72 740 Td (Grouped digital page with a figure.) Tj ET q 300 0 0 400 156 250 cm /Im0 Do Q',group=True)
 gp=d/'grouped-photo.pdf';pdf(gp,612,816,[('Im0',ph.width,ph.height,ph.tobytes())],'q 612 0 0 816 0 0 cm /Im0 Do Q',group=True)
 cases=[(lt,0),(gt,0),(gf,0),(gp,0),(vec,0),(fig,0),(bg,0),(full_photo,0),(R/'tests/fixture.epub',0),(R/'tests/fixture.epub',3),(R/'tests/large08.epub',2),(R/'tests/anchor-fixture.epub',0),(R/'tests/image-clip-fixture.pdf',0),(R/'tests/tall-view-fixture.pdf',0)]
 for bk in ['digital-small1.pdf','digital-big.pdf']:
  q=R.parent/'testbooks'/bk
  if q.exists():cases+=[(q,0),(q,5),(q,17),(q,40)]
 n=0
 for path,page in cases:
  for dith in (0,1):
   c0=render(path,page,dith,d/'off.pgm');c1=render(path,page,dith|2,d/'on.pgm')
   assert c1[0]==0 and pix(d/'off.pgm')==pix(d/'on.pgm'),(path.name,page,dith,c1)
   n+=1
 print(f'PASS byte-identical with cleanup on vs off: {n} renders ({len(cases)} pages x dithering on/off) incl. vector PDF, text PDFs, grouped and layered pages with visible text, PDF with a photo figure, full-page background image with visible text, full-page photo, EPUBs')
