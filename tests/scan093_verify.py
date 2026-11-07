# v0.9.3 MRC scan fast path: background + foreground with a 1-bit soft mask (Internet Archive layout).
from pathlib import Path
import subprocess,tempfile,zlib,math,re,os,time
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parent.parent;P=R/'out/scan092-probe'
def mrc_pdf(path,bg,fg,mask,pw=612,ph=816,extra=''):
 objs=[];add=lambda b:objs.append(b) or len(objs)
 def img(im,mode,smask=None):
  if mode=='1':
   w,h=im.size;data=im.convert('1').tobytes();bpc,cs=1,b'/DeviceGray'
  else:
   w,h=im.size;data=im.convert('RGB').tobytes();bpc,cs=8,b'/DeviceRGB'
  z=zlib.compress(data);sm=b' /SMask %d 0 R'%smask if smask else b''
  return add(b'<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent %d%s /Filter /FlateDecode /Length %d >>\nstream\n'%(w,h,cs,bpc,sm,len(z))+z+b'\nendstream')
 b=img(bg,'RGB');m=img(mask,'1');f=img(fg,'RGB',m)
 font=add(b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
 c=(f'q {pw} 0 0 {ph} 0 0 cm /Im0 Do Q q {pw} 0 0 {ph} 0 0 cm /Im1 Do Q BT /F1 12 Tf 3 Tr 72 700 Td (invisible OCR) Tj ET '+extra).encode()
 cs=add(b'<< /Length %d >>\nstream\n'%len(c)+c+b'\nendstream');pn=len(objs)+2
 pg=add(b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] /Resources << /Font << /F1 %d 0 R >> /XObject << /Im0 %d 0 R /Im1 %d 0 R >> >> /Contents %d 0 R >>'%(pn,pw,ph,font,b,f,cs))
 add(b'<< /Type /Pages /Kids [%d 0 R] /Count 1 >>'%pg);cat=add(b'<< /Type /Catalog /Pages %d 0 R >>'%pn)
 out=bytearray(b'%PDF-1.4\n');offs=[]
 for i,o in enumerate(objs,1):offs.append(len(out));out+=b'%d 0 obj\n'%i+o+b'\nendobj\n'
 x=len(out);out+=b'xref\n0 %d\n0000000000 65535 f \n'%(len(objs)+1)+b''.join(b'%010d 00000 n \n'%o for o in offs)
 out+=b'trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n'%(len(objs)+1,cat,x);Path(path).write_bytes(out)
def render(path,page,flags,out,reps=1):
 r=subprocess.run([str(P),str(path),str(page),str(flags),str(out),str(reps)],capture_output=True,text=True,check=True).stdout
 m=re.search(r'cleaned=(\d+) image_count=(\d+) coverage=([\d.]+) best_ms=([\d.]+) first_ms=([\d.]+)',r);return int(m[1]),float(m[5])
def pix(p):b=Path(p).read_bytes();return b[b.index(b'\n')+1:]
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='scan093-') as t:
 d=Path(t)
 W,H=1200,1600
 bg=Image.new('RGB',(W//3,H//3));px=bg.load()
 for y in range(bg.height):
  for x in range(bg.width):v=int(150-25*((x-200)**2+(y-266)**2)/(200**2+266**2)+6*math.sin(y/30));px[x,y]=(v+12,v,v-30)
 mask=Image.new('L',(W,H),0);dr=ImageDraw.Draw(mask)
 try:f=ImageFont.truetype(str(R/'src/fonts/NotoSans-Regular.ttf'),30)
 except Exception:f=ImageFont.load_default()
 for i in range(38):dr.text((90,90+i*38),'The frontier settlers moved west along the river valley %d'%i,fill=255,font=f)
 fg=Image.new('RGB',(W,H),(40,34,30))
 plain=d/'mrc-plain.pdf';mrc_pdf(plain,bg,fg,mask)
 c0=render(plain,0,1,d/'off.pgm');c1=render(plain,0,3,d/'on.pgm')
 assert c0[0]==0 and c1[0]==1,(c0,c1)
 a=pix(d/'on.pgm');src=mask.resize((1272,1696)).tobytes()
 paper=[i for i in range(0,len(a),11) if src[i]==0];ink=[i for i in range(0,len(a),3) if src[i]==255]
 white=sum(1 for i in paper if a[i]>=250)/len(paper);inkm=sum(a[i] for i in ink)/len(ink)
 assert white>=0.97 and inkm<=40,(white,inkm)
 print(f'PASS MRC scan (1-bit soft-mask foreground over a tinted background): white paper on {white*100:.1f}%, ink mean {inkm:.0f}; host {c0[1]:.1f} ms normal vs {c1[1]:.1f} ms fast path')
 # background holding a picture: rendered normally (identical on vs off)
 ph=Image.new('RGB',bg.size);pp=ph.load()
 for y in range(ph.height):
  for x in range(ph.width):v=int(127+120*math.sin(x/9.0)*math.cos(y/13.0));pp[x,y]=(v,v,v)
 photo=d/'mrc-photo.pdf';mrc_pdf(photo,ph,fg,mask)
 # visible text on the page: not an MRC scan
 vt=d/'mrc-text.pdf';mrc_pdf(vt,bg,fg,mask,extra='BT /F1 18 Tf 0 Tr 72 400 Td (Visible digital text) Tj ET')
 for q in (photo,vt):
  for dith in (0,1):
   r0=render(q,0,dith,d/'off.pgm');r1=render(q,0,dith|2,d/'on.pgm')
   assert r1[0]==0 and pix(d/'off.pgm')==pix(d/'on.pgm'),(q.name,dith,r1)
 print('PASS fallbacks render exactly as with cleanup off: picture in the background, visible text on the page')
 # optional real books (not included): ZR_MRC_BOOKS="a.pdf:page,b.pdf:page"
 for spec in filter(None,os.environ.get('ZR_MRC_BOOKS','').split(',')):
  f,pg=spec.rsplit(':',1);b0=render(f,int(pg),1,d/'off.pgm');b1=render(f,int(pg),3,d/'on.pgm')
  assert b1[0]==1,(spec,b1)
  print(f'PASS real MRC book page {pg}: cleaned; host first render {b0[1]:.0f} ms -> {b1[1]:.0f} ms')
