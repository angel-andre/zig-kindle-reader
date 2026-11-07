# v0.9.4: single full-page JPEG 2000 scans decode at reduced resolution (cleanup on), photos untouched;
# slow-pages log line.
from pathlib import Path
import subprocess,tempfile,zlib,math,re,io,random,json
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parent.parent;P=R/'out/scan092-probe'
def jpx_pdf(path,im,pw=612,ph=816):
 b=io.BytesIO();im.save(b,'JPEG2000',quality_mode='rates',quality_layers=[40],irreversible=True,num_resolutions=6);data=b.getvalue()
 objs=[];add=lambda x:objs.append(x) or len(objs)
 cs=b'/DeviceGray' if im.mode=='L' else b'/DeviceRGB'
 i0=add(b'<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent 8 /Filter /JPXDecode /Length %d >>\nstream\n'%(im.width,im.height,cs,len(data))+data+b'\nendstream')
 c=f'q {pw} 0 0 {ph} 0 0 cm /Im0 Do Q'.encode();ct=add(b'<< /Length %d >>\nstream\n'%len(c)+c+b'\nendstream');pn=len(objs)+2
 pg=add(b'<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] /Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>'%(pn,pw,ph,i0,ct))
 add(b'<< /Type /Pages /Kids [%d 0 R] /Count 1 >>'%pg);cat=add(b'<< /Type /Catalog /Pages %d 0 R >>'%pn)
 out=bytearray(b'%PDF-1.5\n');offs=[]
 for i,o in enumerate(objs,1):offs.append(len(out));out+=b'%d 0 obj\n'%i+o+b'\nendobj\n'
 x=len(out);out+=b'xref\n0 %d\n0000000000 65535 f \n'%(len(objs)+1)+b''.join(b'%010d 00000 n \n'%o for o in offs)
 out+=b'trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n'%(len(objs)+1,cat,x);Path(path).write_bytes(out)
def render(path,flags,out,reps=1):
 r=subprocess.run([str(P),str(path),'0',str(flags),str(out),str(reps)],capture_output=True,text=True,check=True).stdout
 m=re.search(r'cleaned=(\d+) image_count=(\d+) coverage=([\d.]+) best_ms=([\d.]+) first_ms=([\d.]+)',r);return int(m[1]),float(m[5])
def pix(p):b=Path(p).read_bytes();return b[b.index(b'\n')+1:]
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='scan094-') as t:
 d=Path(t);W,H=2544,3392
 sc=Image.new('L',(W//4,H//4));px=sc.load();rnd=random.Random(5)
 for y in range(sc.height):
  for x in range(sc.width):px[x,y]=int(196-22*((x-W/8)**2+(y-H/8)**2)/((W/8)**2+(H/8)**2)+8*math.sin(y/22))
 sc=sc.resize((W,H),Image.BILINEAR);dr=ImageDraw.Draw(sc)
 try:f=ImageFont.truetype(str(R/'src/fonts/NotoSans-Regular.ttf'),60)
 except Exception:f=ImageFont.load_default()
 for i in range(40):dr.text((180,180+i*76),'The frontier settlers moved west along the river %d'%i,fill=48,font=f)
 sp=d/'jpx-scan.pdf';jpx_pdf(sp,sc)
 c0=render(sp,1,d/'off.pgm');c1=render(sp,3,d/'on.pgm')
 assert c0[0]==0 and c1[0]==1,(c0,c1)
 a=pix(d/'on.pgm');src=sc.resize((1272,1696)).tobytes()
 from PIL import ImageFilter
 far=sc.resize((1272,1696)).filter(ImageFilter.MinFilter(9)).tobytes()
 paper=[i for i in range(0,len(a),7) if far[i]>150];ink=[i for i in range(0,len(a),3) if src[i]<110]
 white=sum(1 for i in paper if a[i]>=250)/len(paper);inkm=sum(a[i] for i in ink)/len(ink)
 assert white>=0.95 and inkm<=90,(white,inkm)
 print(f'PASS single full-page JPEG 2000 scan ({W}x{H}): reduced-resolution decode + cleanup, white {white*100:.1f}%, ink mean {inkm:.0f}; host first render {c0[1]:.0f} ms -> {c1[1]:.0f} ms')
 ph=Image.new('RGB',(W//2,H//2));pp=ph.load()
 for y in range(ph.height):
  for x in range(ph.width):v=int(127+120*math.sin(x/37.0)*math.cos(y/53.0));pp[x,y]=(v,(v*3)//4,255-v)
 fp=d/'jpx-photo.pdf';jpx_pdf(fp,ph.resize((W,H)))
 for dith in (0,1):
  r0=render(fp,dith,d/'off.pgm');r1=render(fp,dith|2,d/'on.pgm')
  assert r1[0]==0 and pix(d/'off.pgm')==pix(d/'on.pgm'),(dith,r1)
 print('PASS full-page JPEG 2000 photo (cover-like) is byte-identical with cleanup on vs off')
 # slow-pages line: logged once after 8 renders of a book (sim logs it even when fast)
 data=d/'data';data.mkdir();(d/'sim').write_text('wait 1000\n'+'tap 1180 850\nwait 250\n'*10+'quit\n')
 bk=R.parent/'testbooks'/'digital-big.pdf'
 if bk.exists():
  log=subprocess.run([str(R/'out/zreader-host'),'--sim',str(d/'sim'),'--shots',str(d),'--data',str(data),'--books',str(bk.parent),'--idle-min','0',str(bk)],capture_output=True,timeout=60).stderr.decode()
  m=re.search(r'slow pages: (\w+) avg=(\d+)ms max=(\d+)ms over (\d+) renders',log);assert m and m[1]=='ok',log[-2000:]
  assert 'launch profile: ' in log
  print(f'PASS slow-pages check logged once: {m[0]}; launch profile line present')
