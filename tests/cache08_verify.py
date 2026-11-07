from pathlib import Path
import subprocess,tempfile,os,time,shutil
R=Path(__file__).resolve().parent.parent;M=R.parent/'mupdf-1.28.6-source'
subprocess.run([str(R.parent/'zig/zig'),'cc','-target','x86_64-linux-musl','-O2','-I',str(R/'src'),'-I',str(M/'include'),str(R/'tests/platform08_probe.c'),str(R/'src/render.c'),str(M/'build/hostmusl-release/libmupdf.a'),str(M/'build/hostmusl-release/libmupdf-third.a'),'-static','-lpthread','-lm','-o',str(R/'out/platform08-probe')],check=True)
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='cache08-') as t:
 d=Path(t);data=d/'data';data.mkdir();book=d/'book.pdf';shutil.copyfile(R.parent/'testbooks/digital-big.pdf',book);slow=d/'slow.pdf';shutil.copyfile(book,slow)
 def run(mode,**kw):
  cmd=[str(R/'out/platform08-probe'),mode,str(data),str(book)]
  if mode=='blocked':cmd+=[str(slow)]
  return subprocess.run(cmd,check=True,timeout=8,**kw)
 run('miss');files=list((data/'thumbs').glob('*.zrt'));assert len(files)==1 and files[0].stat().st_size==12288
 run('hit',env=dict(os.environ,ZR08_FORBID_RENDER='1'))
 run('blocked')
 page=[]
 for i in range(7):
  path=d/f'page-{i}.pdf';shutil.copyfile(book,path);page.append(str(path))
  subprocess.run([str(R/'out/platform08-probe'),'miss',str(data),str(path)],check=True,timeout=8)
 subprocess.run([str(R/'out/platform08-probe'),'page',str(data)]+page,check=True,timeout=3,env=dict(os.environ,ZR08_FORBID_RENDER='1'))
 # Stat identity includes both mtime and size, not just a filename.
 with book.open('ab') as f:f.write(b'\n')
 run('invalid',env=dict(os.environ,ZR08_FORBID_RENDER='1'))
 print('PASS persistent 96x128 grayscale hit, no renderer on hit, changed-size/mtime miss, hits never wait behind slow subprocess')

with tempfile.TemporaryDirectory(dir=R/'tests',prefix='battery08-') as t:
 d=Path(t);calls=d/'calls';bin=d/'bin';bin.mkdir()
 for name,body in [('lipc-get-prop',f'echo "GET $*" >> "{calls}"\ncase "$3" in battLevel) echo 76;; flIntensity) echo 14;; currentAmberLevel) echo 18;; state) echo active;; esac\n'),('lipc-set-prop',f'echo "WRITE $*" >> "{calls}"\nexit 1\n')]:
  p=bin/name;p.write_text('#!/bin/sh\n'+body);p.chmod(0o755)
 subprocess.run([str(R/'out/platform08-probe'),'battery'],env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH']),check=True,timeout=5)
 text=calls.read_text();assert 'battLevel' in text and 'WRITE' not in text
 print('PASS battery polling issues zero firmware writes')
