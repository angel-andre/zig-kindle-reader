#!/usr/bin/env python3
"""Build compact, shared-gloss WordNet 3.0 index using only the Python stdlib.
Input: official WNdb-3.0.tar.gz (Princeton WordNet licence; see LICENSE).
Output layout documented in FORMAT; keys sorted, references preserve sense order.
"""
import argparse,hashlib,struct,tarfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
glosses=bytearray();synsets={};dedup={};entries={}
with tarfile.open(a.source,'r:gz') as t:
 for pos,label in [('noun','n.'),('verb','v.'),('adj','adj.'),('adv','adv.')]:
  for line in t.extractfile('dict/data.'+pos).read().decode('utf-8').splitlines():
   if not line or line[0].isspace():continue
   left,gloss=line.split('|',1);num=int(left.split()[0]);value=f'({label}) {gloss.strip()}'.encode()+b'\0'
   off=dedup.get(value)
   if off is None:off=len(glosses);dedup[value]=off;glosses.extend(value)
   synsets[pos,num]=off
  for line in t.extractfile('dict/index.'+pos).read().decode('utf-8').splitlines():
   if not line or line[0].isspace():continue
   fields=line.split();key=fields[0].lower().replace('_',' ').encode('utf-8');n=int(fields[2]);np=int(fields[3]);refs=[synsets[pos,int(x)] for x in fields[6+np:6+np+n]]
   assert len(refs)==n
   dest=entries.setdefault(key,[])
   for r in refs:
    if r not in dest:dest.append(r)
keys=bytearray();refs=bytearray();index=bytearray()
for key,rs in sorted(entries.items()):
 assert len(key)<256 and len(rs)<65536
 index.extend(struct.pack('<IHHII',len(keys),len(key),len(rs),len(refs),0));keys.extend(key)
 refs.extend(struct.pack('<'+'I'*len(rs),*rs))
io=32;ko=io+len(index);ro=ko+len(keys);go=ro+len(refs);end=go+len(glosses)
assert end<=40*1024*1024
blob=struct.pack('<8sIIIIII',b'ZRWN3001',len(entries),io,ko,ro,go,end)+index+keys+refs+glosses
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(blob)
print(f'WordNet 3.0: {len(entries):,} keys, {len(dedup):,} shared glosses; {len(blob):,} bytes ({len(blob)/1024**2:.2f} MiB)')
print('source sha256',hashlib.sha256(a.source.read_bytes()).hexdigest());print('output sha256',hashlib.sha256(blob).hexdigest())
