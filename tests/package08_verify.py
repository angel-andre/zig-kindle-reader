#!/usr/bin/env python3
from pathlib import Path
import tarfile,hashlib,json
R=Path(__file__).resolve().parent.parent;S=R.parent/'stage'
def sha(b):return hashlib.sha256(b).hexdigest()
with tarfile.open(S/'zr07.tgz') as old,tarfile.open(S/'zr08.tgz') as new:
 assert set(old.getnames())==set(new.getnames())
 assert old.extractfile('dictionary/wordnet.zdict').read()==new.extractfile('dictionary/wordnet.zdict').read()
 assert b'zreader 0.8.0' in new.extractfile('README').read()
 assert b'restore-ui' in new.extractfile('zreader-maintenance.sh').read()
 for m in new:
  assert m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts
  assert not m.name.endswith(('.pdf','.epub'))
with tarfile.open(S/'zr08-source.tgz') as src:
 names=set(src.getnames())
 for n in ['src/zreader.zig','src/platform07.c','src/render.c','src/render.h','build.sh','tests/run08.sh','tests/REPORT08','third_party/mupdf-1.28.6-source.tar.gz','dictionary/source/WNdb-3.0.tar.gz']:
  assert 'zigreader/'+n in names,n
 assert not any(n.endswith(('digital-small1.pdf','digital-big.pdf')) for n in names)
 for n in ['src/zreader.zig','src/platform07.c','README','zreader-maintenance.sh','build.sh']:
  assert src.extractfile('zigreader/'+n).read()==(R/n).read_bytes()
 for n in ['README','SOURCE-BUILD','src/zreader.zig','src/platform07.c','zreader-run.sh']:
  b=src.extractfile('zigreader/'+n).read()
  for private in [b'192.'+b'168.',b'/Users/',b'PRIVATE KEY',b'ssh-ed25519 ']:assert private not in b
sizes=json.loads((S/'zr08-sizes.json').read_text())
assert sizes['binary_bytes']==(R/'out/zreader').stat().st_size
for line in (S/'zr08.sha256').read_text().splitlines():
 h,n=line.split('  ');p=S/n if n.endswith('.tgz') else R/n;assert sha(p.read_bytes())==h
print('PASS runtime layout identical to zr07; dictionary unchanged; current source/dependencies included; private books excluded; manifests and source hashes match')
