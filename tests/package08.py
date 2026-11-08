#!/usr/bin/env python3
"""Private box release packaging; no deploy, upload or device access."""
from pathlib import Path
import hashlib,json,tarfile,gzip,io
R=Path(__file__).resolve().parent.parent;STAGE=R.parent/'stage';STAGE.mkdir(exist_ok=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write_tar(dest,files):
 with dest.open('wb') as raw,gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0,compresslevel=6) as gz,tarfile.open(fileobj=gz,mode='w|',format=tarfile.GNU_FORMAT) as tar:
  for name,p in sorted(files.items()):
   info=tar.gettarinfo(str(p),arcname=name);info.uid=info.gid=0;info.uname=info.gname='';info.mtime=0
   with p.open('rb') as f:tar.addfile(info,f)
runtime={name:R/name for name in ['out/zreader','zreader-run.sh','zreader-maintenance.sh','README','COPYING','dictionary/wordnet.zdict','dictionary/LICENSE','dictionary/FORMAT']}
for p in (R/'kual').rglob('*'):
 if p.is_file():runtime[str(p.relative_to(R))]=p
assert 'for p in awesome volumd blanket Xorg; do' in (R/'zreader-run.sh').read_text()
assert not any(p.is_symlink() for p in runtime.values())
write_tar(STAGE/'zr08.tgz',runtime)
source={}
for folder in ['src','kual','dictionary']:
 for p in (R/folder).rglob('*'):
  if p.is_file() and '__pycache__' not in p.parts:source['zigreader/'+str(p.relative_to(R))]=p
for name in ['README','COPYING','SOURCE-BUILD','build.sh','build-mupdf.sh','zreader-run.sh','zreader-maintenance.sh']:
 source['zigreader/'+name]=R/name
for p in (R/'tests').iterdir():
 if p.is_file() and p.name != 'package08-results.txt' and (p.suffix in ['.c','.py','.sh','.sim','.epub'] or p.name in ['tall-view-fixture.pdf','image-clip-fixture.pdf','REPORT06','REPORT08'] or p.name.endswith('08-results.txt') or p.name.endswith('08-regression.txt') or p.name in ['results08.txt','integration08-results.txt','refresh08-results.txt']):
  source['zigreader/tests/'+p.name]=p
for p in (R/'shots').glob('*.png'):
 if p.name.startswith(('86_library_storage_battery_mock','89_scan-d_turn_log')): source['zigreader/shots/'+p.name]=p
for name in ['performance08.json','scan-d08-before.csv','scan-d08-after.csv','turn08-before.log','turn08-after.log','unit08-results.txt','v08-results.txt','cache08-results.txt','platform08-regression.txt','ui08-regression.txt','refresh08-results.txt']:
 source['zigreader/tests/'+name]=R/'tests'/name
source['zigreader/third_party/mupdf-1.28.6-source.tar.gz']=R.parent/'mupdf-1.28.6-source.tar.gz'
assert not any(p.is_symlink() for p in source.values())
write_tar(STAGE/'zr08-source.tgz',source)
sizes=dict(binary_bytes=(R/'out/zreader').stat().st_size,dictionary_bytes=(R/'dictionary/wordnet.zdict').stat().st_size,install_file_bytes=sum(p.stat().st_size for p in runtime.values()),runtime_archive_bytes=(STAGE/'zr08.tgz').stat().st_size,source_archive_bytes=(STAGE/'zr08-source.tgz').stat().st_size,runtime_files=len(runtime))
sizes['install_mib']=round(sizes['install_file_bytes']/1024**2,3)
(STAGE/'zr08-sizes.json').write_text(json.dumps(sizes,indent=2)+'\n')
manifest=''.join(f'{digest(p)}  {name}\n' for name,p in [('zr08.tgz',STAGE/'zr08.tgz'),('zr08-source.tgz',STAGE/'zr08-source.tgz'),('out/zreader',R/'out/zreader'),('dictionary/wordnet.zdict',R/'dictionary/wordnet.zdict')])
(STAGE/'zr08.sha256').write_text(manifest)
with tarfile.open(STAGE/'zr08.tgz','r:gz') as t:
 assert set(t.getnames())==set(runtime)
 for member in t:
  assert hashlib.sha256(t.extractfile(member).read()).hexdigest()==digest(runtime[member.name])
 assert all(not m.name.endswith(('.pdf','.epub')) for m in t)
print(json.dumps(sizes,indent=2));print(manifest)
