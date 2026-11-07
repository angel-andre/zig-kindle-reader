# v0.9.0 host-only timing: request-to-first-frame on reopen, saved page off vs on. Host x86 numbers, not Kindle numbers.
from pathlib import Path
import subprocess,tempfile,re,shutil,statistics,sys
R=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'tests'))
def big_epub(path):
 import importlib.util,types
 src=(R/'tests/pc090_verify.py').read_text();ns={'__file__':str(R/'tests/pc090_verify.py')};exec(src.split('def run(')[0],ns);ns['big_epub'](path)
BOOKS=[('scanned PDF (scan-D copy, 47 MB)',R.parent/'diag/scan-d.pdf','x.pdf'),('synthetic EPUB (80 chapters, 1762 pages)',None,'b.epub')]
def run(d,book,extra=(),script='wait 2500\n'):
 s=d/'s.sim';s.write_text(script+'quit\n')
 p=subprocess.run([str(R/'out/zreader-host'),'--data',str(d/'data'),'--books',str(d/'books'),'--sim',str(s),'--shots',str(d/'shots'),'--idle-min','0',*extra,str(d/'books'/book)],capture_output=True,timeout=300,check=True)
 return p.stderr.decode()
out=[]
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='bench090-') as t:
 d=Path(t);(d/'books').mkdir();(d/'data').mkdir()
 for label,src,name in BOOKS:
  if src is None:big_epub(d/'books'/name)
  elif src.exists():shutil.copy(src,d/'books'/name)
  else:out.append(f'{label}: source missing, skipped');continue
  run(d,name,script='wait 3000\n'+'tap 1100 850\nwait 2500\n'*3)
  off=[int(re.search(r'first_frame_us=(\d+) \(rendered\)',run(d,name,('--page-cache-mib','0')))[1]) for _ in range(3)]
  logs=[run(d,name) for _ in range(3)];on=[int(re.search(r'first_frame_us=(\d+) \(saved page\)',l)[1]) for l in logs]
  size=max(p.stat().st_size for p in (d/'data/cache/pages').glob('*.pg'))
  out.append(f'{label}: first frame on reopen, saved page OFF median {statistics.median(off)/1000:.1f} ms {off} us; ON median {statistics.median(on)/1000:.1f} ms {on} us; saved page file {size/1024:.0f} KiB')
print('HOST (x86_64 box) numbers, not measured on the Kindle:');print('\n'.join(out))
