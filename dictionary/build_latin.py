#!/usr/bin/env python3
"""Build the compact Latin dictionary (latin.zdict, format ZRLA1001; see LATIN-FORMAT) from
William Whitaker's WORDS data files (DICTLINE.GEN, INFLECTS.LAT, UNIQUES.LAT), stdlib only.
Keys are stems folded like the reader folds words: lowercase, no macrons/accents, j->i, v->u.
Inflected forms are matched at lookup time: ending + stem + declension/conjugation checks."""
import argparse,hashlib,struct,unicodedata
from pathlib import Path
ap=argparse.ArgumentParser(description='src: a folder with the WORDS data files, or dictionary/source/whitaker-words-data.tar.gz')
ap.add_argument('src',type=Path);ap.add_argument('output',type=Path);a=ap.parse_args()
if a.src.is_file():
 import tarfile,tempfile
 tmp=tempfile.TemporaryDirectory();tarfile.open(a.src).extractall(tmp.name,filter='data');a.src=Path(tmp.name)/'whitaker-words-data'
def fold(s):
 s=unicodedata.normalize('NFD',s.lower().replace('æ','ae').replace('œ','oe'))
 return ''.join(c for c in s if not unicodedata.combining(c)).replace('j','i').replace('v','u')
POS={'N':1,'PRON':2,'ADJ':3,'NUM':4,'V':5,'ADV':6,'PREP':7,'CONJ':8,'INTERJ':9,'UNIQUE':10}
IPOS={'N':1,'PRON':2,'ADJ':3,'NUM':4,'V':5,'VPAR':5,'SUPINE':5,'ADV':6,'PREP':7,'CONJ':8,'INTERJ':9}
NCODES={'N':5,'PRON':5,'ADJ':6,'NUM':6,'V':7,'VPAR':8,'SUPINE':5,'ADV':1,'PREP':1,'CONJ':0,'INTERJ':0}
GEN={'X':0,'M':1,'F':2,'N':3,'C':4}
COMP={'X':0,'POS':1,'COMP':2,'SUPER':3}
CASE={'NOM':'nom.','GEN':'gen.','DAT':'dat.','ACC':'acc.','ABL':'abl.','VOC':'voc.','LOC':'loc.','X':''}
NUMB={'S':'sg.','P':'pl.','X':''}
TENSE={'PRES':'pres.','IMPF':'impf.','FUT':'fut.','PERF':'perf.','PLUP':'plupf.','FUTP':'fut. perf.','X':''}
VOICE={'ACTIVE':'act.','PASSIVE':'pass.','X':''}
MOOD={'IND':'ind.','SUB':'subj.','IMP':'imper.','INF':'inf.','PPL':'part.','X':''}
PERS={'0':'','1':'1st','2':'2nd','3':'3rd'}
GN={'M':'m.','F':'f.','N':'n.','C':'','X':''}
CMP={'POS':'','COMP':'comp.','SUPER':'superl.','X':''}
infl=[];descs={}
for line in (a.src/'INFLECTS.LAT').read_text('latin-1').splitlines():
 line=line.split('--')[0].strip()
 if not line:continue
 t=line.split();p=t[0]
 if p not in NCODES:continue
 n=NCODES[p];codes=t[1:1+n];rest=t[1+n:]
 key=int(rest[0]);ln=int(rest[1]);end=rest[2] if ln else '';age,freq=(rest[3:5] if ln else rest[2:4])
 if age!='X' and age not in 'ABCDEFGH':pass
 which=var=0;gender=0;comp=0;d=''
 if p in('N','PRON','ADJ','NUM','SUPINE','VPAR'):
  which,var=int(codes[0]),int(codes[1]);cs,nb,g=codes[2:5];gender=GEN.get(g,0)
  d=' '.join(x for x in [CASE[cs],NUMB[nb],GN[g]] if x)
  if p=='ADJ':comp=COMP[codes[5]];d+=(' '+CMP[codes[5]]) if CMP[codes[5]] else ''
  if p=='VPAR':d=' '.join(x for x in [TENSE[codes[5]],VOICE[codes[6]],'part.',d] if x)
  if p=='SUPINE':d='supine '+d
 elif p=='V':
  which,var=int(codes[0]),int(codes[1]);te,vo,mo,pe,nb=codes[2:7]
  d=' '.join(x for x in [TENSE[te],VOICE[vo],MOOD[mo],PERS[pe],NUMB[nb]] if x)
 elif p=='ADV':comp=COMP[codes[0]];d='adv.'+(' '+CMP[codes[0]] if CMP[codes[0]] else '')
 elif p=='PREP':d='prep. + '+CASE[codes[0]].rstrip('.')
 else:d={'CONJ':'conj.','INTERJ':'interj.'}[p]
 e=fold(end);assert len(e)<=8,end
 di=descs.setdefault(d,len(descs))
 rank='ABCDEFGHIX'.index(freq) if freq in 'ABCDEFGHIX' else 9
 infl.append((IPOS[p],which,var,key,gender,comp,rank,e,di,p,codes))
# ---- dictionary lines
entries=[];stems={};merged={}
def addstem(s,eid,slot):
 if not s or s=='zzz':return
 stems.setdefault(fold(s),[]).append(eid<<2|slot)
NC={'N':4,'PRON':3,'PACK':3,'ADJ':3,'NUM':4,'V':3,'ADV':1,'PREP':1,'CONJ':0,'INTERJ':0}
for line in (a.src/'DICTLINE.GEN').read_text('latin-1').splitlines():
 line=line.rstrip('\r\n')
 if len(line)<80:continue
 st=[line[i*19:(i+1)*19].strip() for i in range(4)];rest=line[76:].split(None,NC.get(line[76:83].strip(),0)+6)
 p=rest[0]
 if p not in POS:continue
 nc=NC[p];codes=rest[1:1+nc];flags=rest[1+nc:6+nc];meaning=rest[6+nc] if len(rest)>6+nc else ''
 which=var=gender=comp=0
 if p in('N','PRON','ADJ','NUM','V'):which,var=int(codes[0]),int(codes[1])
 if p=='N':gender=GEN.get(codes[2],0)
 if p=='ADJ':comp=COMP.get(codes[2],0)
 if p=='ADV':comp=COMP.get(codes[0],0)
 freq='ABCDEFGHIX'.index(flags[3]) if flags[3] in 'ABCDEFGHIX' else 9
 if p=='ADJ' and which==0 and comp in(2,3) and st[0] and not any(x and x!='zzz' for x in st[1:]):st=['','','',''][:];st[comp]=line[0:19].strip()
 meaning=meaning.strip();mk=(tuple(st),p,tuple(codes))
 if mk in merged:
  e=entries[merged[mk]];e['meaning']=(e['meaning'].rstrip()+' '+meaning.lstrip('|').strip()).strip();e['freq']=min(e['freq'],freq);continue
 eid=len(entries);merged[mk]=eid;entries.append(dict(pos=POS[p],p=p,which=which,var=var,gender=gender,comp=comp,freq=freq,stems=st,codes=codes,meaning=meaning.lstrip('|')))
 for i,s in enumerate(st):addstem(s,eid,i)
# 'esse' and a few pronoun forms are built into the WORDS program rather than its data files
SUM='be; exist; (also used to form verb perfect passive tenses) with NOM PERF PPL'
eid=len(entries);entries.append(dict(pos=5,p='V',which=5,var=1,gender=0,comp=0,freq=0,stems=['','','fu','fut'],codes=['5','1','TO_BE'],meaning=SUM,head=('sum, esse, fui, futurus','verb, irreg.')))
addstem('fu',eid,2);addstem('fut',eid,3)
SUPP=[('sum esse fui futurus','verb, irreg.',SUM,'pres. ind.',['sum','es','est','sumus','estis','sunt']),
 ('sum esse fui futurus','verb, irreg.',SUM,'impf. ind.',['eram','eras','erat','eramus','eratis','erant']),
 ('sum esse fui futurus','verb, irreg.',SUM,'fut. ind.',['ero','eris','erit','erimus','eritis','erunt']),
 ('sum esse fui futurus','verb, irreg.',SUM,'pres. subj.',['sim','sis','sit','simus','sitis','sint']),
 ('sum esse fui futurus','verb, irreg.',SUM,'impf. subj.',['essem','esses','esset','essemus','essetis','essent','forem','fores','foret','forent']),
 ('sum esse fui futurus','verb, irreg.',SUM,'pres. inf.',['esse']),('sum esse fui futurus','verb, irreg.',SUM,'fut. inf.',['fore']),
 ('qui, quae, quod','pron.','who; that; which, what; of which kind/degree; person/thing/time/point that;','nom. sg.',['qui','quae','quod']),
 ('is, ea, id','pron.','he/she/it, they (by GENDER/NUMBER); DEMONST: that, this;','nom. sg.',['is','ea','id']),
 ('hic, haec, hoc','pron.','this; these (pl.); (also DEMONST: the latter);','nom. sg.',['hic','haec','hoc']),
 ('ille, illa, illud','pron.','that; those (pl.); also DEMONST; that person/thing; the well known; the former;','nom. sg.',['ille','illa','illud'])]
PN=['1st sg.','2nd sg.','3rd sg.','1st pl.','2nd pl.','3rd pl.']
for hw,tag,mean,d,forms in SUPP:
 hw=', '.join(hw.split()) if ',' not in hw else hw
 for k,f in enumerate(forms):
  dd=d+(' '+PN[k] if len(forms)==6 and 'inf' not in d else '')
  if 'subj' in d and len(forms)==10:dd=d+' '+['1st sg.','2nd sg.','3rd sg.','1st pl.','2nd pl.','3rd pl.','1st sg.','2nd sg.','3rd sg.','3rd pl.'][k]
  if len(forms)==3:dd=d+' '+['m.','f.','n.'][k]
  eid=len(entries);entries.append(dict(pos=10,p='UNIQUE',which=0,var=0,gender=0,comp=0,freq=0,stems=[f,'','',''],codes=[],meaning=mean,head=(hw,tag+' \u2014 '+dd)))
  addstem(f,eid,0)
# headwords from the inflection table
def form(e,pp,pred):
 best=None
 for r in infl:
  if r[9]!=pp:continue
  if r[1] not in(0,e['which']) or r[2] not in(0,e['var']):continue
  if not pred(r):continue
  s=e['stems'][r[3]-1] if r[3]<=4 else ''
  if not s or s=='zzz':continue
  if best is None or r[6]<best[0]:best=(r[6],s+r[7])
 return best[1] if best else None
def cs(r,c,n):return r[10][2]==c and r[10][3]==n
def headword(e):
 p=e['p'];st=e['stems']
 if p=='N':
  g='XMFNC'[e['gender']];ok=lambda r:r[10][4] in(('X',g) if g=='N' else ('X','C',g)) or g in('X','C')
  parts=[form(e,'N',lambda r:cs(r,'NOM','S') and ok(r)),form(e,'N',lambda r:cs(r,'GEN','S') and ok(r))]
  tag=('noun '+GN.get(g,'')).strip()+(f", {e['which']}{['','st','nd','rd'][e['which']] if e['which']<=3 else 'th'} decl." if 1<=e['which']<=5 else '')
 elif p=='V':
  kind=e['codes'][2] if len(e['codes'])>2 else 'X'
  if kind in('DEP','SEMIDEP'):
   act=kind=='SEMIDEP'
   parts=[form(e,'V',lambda r:r[10][2:7]==['PRES','ACTIVE' if act else 'PASSIVE','IND','1','S']),
    form(e,'V',lambda r:r[10][2:5]==['PRES','ACTIVE' if act else 'PASSIVE','INF']),
    (st[3].lower()+'us sum') if st[3] and st[3]!='zzz' else None]
   tag='verb'+(f", {e['which']}{['','st','nd','rd'][e['which']] if e['which']<=3 else 'th'} conj." if 1<=e['which']<=4 else '')+(' dep.' if not act else ' semidep.')
   parts=[x for x in parts if x];out=[];[out.append(x) for x in parts if x not in out]
   return ', '.join(out) or fold(st[0]),tag
  parts=[form(e,'V',lambda r:r[10][2:7]==['PRES','ACTIVE','IND','1','S']) or form(e,'V',lambda r:r[10][2:7]==['PRES','PASSIVE','IND','1','S']),
   form(e,'V',lambda r:r[10][2:5]==['PRES','ACTIVE','INF']) or form(e,'V',lambda r:r[10][2:5]==['PRES','PASSIVE','INF']),
   form(e,'V',lambda r:r[10][2:7]==['PERF','ACTIVE','IND','1','S']),
   (st[3].lower()+'us') if st[3] and st[3]!='zzz' else None]
  tag='verb'+(f", {e['which']}{['','st','nd','rd'][e['which']] if e['which']<=3 else 'th'} conj." if 1<=e['which']<=4 else '')
 elif p in('ADJ','NUM'):
  if p=='NUM':
   c=form(e,'NUM',lambda r:r[10][5]=='CARD' and r[10][2] in('NOM','X') and r[10][4] in('M','X','C'))
   return (c or fold(st[0])),'num.'
  k='POS' if p=='ADJ' else None
  if p=='ADJ' and e['comp'] not in(0,1):k=None
  f=lambda c,n,g:form(e,p,lambda r:cs(r,c,n) and r[10][4] in((g,'X','C') if g!='N' else (g,'X')) and (k is None or r[10][5] in('POS','X')))
  parts=[f('NOM','S','M'),f('NOM','S','F'),f('NOM','S','N')];tag='adj.' if p=='ADJ' else 'num.'
  if parts[0] and parts[0]==parts[1]==parts[2]:parts=[parts[0],form(e,p,lambda r:cs(r,'GEN','S') and (k is None or r[10][5] in('POS','X')))]
  elif parts[0] and parts[0]==parts[1]:parts=[parts[0],parts[2]]
 elif p=='PRON':parts=[form(e,'PRON',lambda r:cs(r,'NOM','S')) or fold(st[0])];tag='pron.'
 elif p=='PREP':parts=[fold(st[0])];tag='prep. + '+CASE.get(e['codes'][0],'').rstrip('.')
 else:parts=[fold(st[0])];tag={'ADV':'adv.','CONJ':'conj.','INTERJ':'interj.'}[p]
 parts=[x for x in parts if x]
 out=[];[out.append(x) for x in parts if x not in out]
 return ', '.join(out) or fold(st[0]),tag
# uniques
def udesc(c):
 p=c[0] if c else ''
 try:
  if p=='V':return 'v. \u2014 '+' '.join(x for x in [TENSE[c[3]],VOICE[c[4]],MOOD[c[5]],PERS[c[6]],NUMB[c[7]]] if x)
  if p in('N','ADJ','PRON','NUM'):return {'N':'n.','ADJ':'adj.','PRON':'pron.','NUM':'num.'}[p]+' \u2014 '+' '.join(x for x in [CASE[c[3]],NUMB[c[4]],GN.get(c[5],'')] if x)
 except (KeyError,IndexError):pass
 return {'ADV':'adv.','CONJ':'conj.','INTERJ':'interj.','PREP':'prep.'}.get(p,p.lower()+'.')
u=[l.rstrip('\r') for l in (a.src/'UNIQUES.LAT').read_text('latin-1').splitlines()]
i=0
while i+2<len(u):
 w,codes,meaning=u[i].strip(),u[i+1].split(),u[i+2].strip();i+=3
 if not w or w.startswith('--'):continue
 eid=len(entries);entries.append(dict(pos=10,p='UNIQUE',which=0,var=0,gender=0,comp=0,freq=0,stems=[w,'','',''],codes=codes,meaning=meaning,head=(fold(w),udesc(codes))))
 addstem(w,eid,0)
text=bytearray();tdedup={}
erec=bytearray()
for e in entries:
 hw,tag=e.get('head') or headword(e)
 s=f"{hw}\0{tag}\0{e['meaning']}\0".encode()
 off=tdedup.get(s)
 if off is None:off=len(text);tdedup[s]=off;text.extend(s)
 erec.extend(struct.pack('<BBBBBBHI',e['pos'],e['which'],e['var'],e['gender'],e['comp'],e['freq'],0,off))
dtext=bytearray();doff=[]
for d,_ in sorted(descs.items(),key=lambda x:x[1]):doff.append(len(dtext));dtext.extend(d.encode()+b'\0')
irec=bytearray()
for (ip,which,var,key,gender,comp,rank,e,di,p,codes) in sorted(infl,key=lambda r:(r[6],)):
 irec.extend(struct.pack('<BBBBBBBB8sI',ip,which,var,key,gender,comp,rank,len(e),e.encode().ljust(8,b'\0'),doff[di]))
keys=bytearray();refs=bytearray();sidx=bytearray()
for k,rs in sorted(stems.items(),key=lambda x:x[0].encode()):
 kb=k.encode();assert len(kb)<64 and len(rs)<65536
 sidx.extend(struct.pack('<IHHI',len(keys),len(kb),len(rs),len(refs)));keys.extend(kb);refs.extend(struct.pack('<'+'I'*len(rs),*rs))
H=64
o=[H];o.append(o[-1]+len(sidx));o.append(o[-1]+len(keys));o.append(o[-1]+len(refs));o.append(o[-1]+len(erec));o.append(o[-1]+len(irec));o.append(o[-1]+len(dtext));end=o[-1]+len(text)
hdr=struct.pack('<8sIIIIIIIIIIIIII',b'ZRLA1001',len(stems),len(entries),len(infl),o[0],o[1],o[2],o[3],o[4],o[5],o[6],end,0,0,0)
blob=hdr+sidx+keys+refs+erec+irec+dtext+text
assert len(hdr)==H and len(blob)==end
a.output.write_bytes(blob)
print(f'Whitaker WORDS: {len(entries):,} entries, {len(stems):,} stems, {len(infl):,} endings; {len(blob):,} bytes ({len(blob)/1024**2:.2f} MiB)')
for f in('DICTLINE.GEN','INFLECTS.LAT','UNIQUES.LAT'):print(f,'sha256',hashlib.sha256((a.src/f).read_bytes()).hexdigest())
print('output sha256',hashlib.sha256(blob).hexdigest())
