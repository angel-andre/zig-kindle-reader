#!/usr/bin/env python3
from pathlib import Path
import tempfile,subprocess,struct
R=Path(__file__).resolve().parent.parent
base=struct.pack('<8sIIIIII',b'ZRWN3001',1,32,48,52,56,61)+struct.pack('<IHHII',0,4,1,0,0)+b'book'+struct.pack('<I',0)+b'XXXXX'
with tempfile.TemporaryDirectory(prefix='dict-format06-',dir=R/'tests') as tmp:
 p=Path(tmp)/'case.zdict'
 def run(blob,mode='invalid'):
  p.write_bytes(blob);r=subprocess.run([str(R/'out/dictionary-probe'),str(p),mode],capture_output=True);assert r.returncode==0,r.stderr.decode()
 run(b'bad');run(b'BADMAGIC'+base[8:]);run(base[:-1]);run(base,'unterminated')
 for off,value in [(8,0),(8,500001),(12,0),(16,0),(20,0),(24,0xffffffff),(28,999),(32,5),(40,8),(44,1),(52,999)]:
  b=bytearray(base);struct.pack_into('<I',b,off,value);run(b)
 b=bytearray(base);struct.pack_into('<H',b,36,255);run(b)
 print('PASS 16 malformed/truncated/header/index/reference cases rejected; unterminated gloss bounded safely')
