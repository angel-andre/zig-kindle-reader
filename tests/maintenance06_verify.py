#!/usr/bin/env python3
from pathlib import Path
import os,subprocess,tempfile
R=Path(__file__).resolve().parent.parent
subprocess.run(['sh','-n',str(R/'zreader-maintenance.sh')],check=True)
with tempfile.TemporaryDirectory(prefix='maintenance06-',dir=R/'tests') as tmp:
 us=Path(tmp);env=dict(os.environ,ZREADER_US=str(us),ZREADER_DATA=str(us/'zreader'));m=us/'DISABLE_CORE_DUMP'
 def run(cmd,ok=True):
  p=subprocess.run(['sh',str(R/'zreader-maintenance.sh'),cmd],env=env,capture_output=True,text=True)
  assert (p.returncode==0)==ok,(p.returncode,p.stdout,p.stderr)
  return p.stdout
 run('status');run('disable-core-dumps');assert m.is_file() and m.stat().st_size==0
 ino=m.stat().st_ino;run('disable-core-dumps');assert m.stat().st_ino==ino
 run('undo-core-dumps');assert not m.exists();run('undo-core-dumps')
 m.touch();ino=m.stat().st_ino;run('disable-core-dumps');run('undo-core-dumps');assert m.stat().st_ino==ino;m.unlink()
 run('disable-core-dumps');m.write_text('keep me');run('undo-core-dumps',False);assert m.read_text()=='keep me';m.write_bytes(b'');run('undo-core-dumps');assert not m.exists()
 target=us/'keep';target.write_text('target');m.symlink_to(target);run('disable-core-dumps',False);run('undo-core-dumps',False);assert target.read_text()=='target' and m.is_symlink();m.unlink()
 run('disable-core-dumps');old=us/'moved';m.rename(old);m.touch();run('undo-core-dumps',False);assert m.exists() and old.exists()
 print('PASS reversible opt-in core marker: create/idempotence/undo, pre-existing/nonempty/replaced/symlink preservation; box sandbox only')
