#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,os,time,json
R=Path(__file__).resolve().parent.parent
MU=R.parent/'mupdf-1.28.6-source'
subprocess.run([str(R.parent/'zig/zig'),'cc','-target','x86_64-linux-musl','-O2','-I',str(R/'src'),'-I',str(MU/'include'),str(R/'tests/platform07_probe.c'),str(R/'src/render.c'),str(MU/'build/hostmusl-release/libmupdf.a'),str(MU/'build/hostmusl-release/libmupdf-third.a'),'-static','-lpthread','-lm','-o',str(R/'out/platform07-probe')],check=True)
with tempfile.TemporaryDirectory(prefix='zr07-platform-') as t:
 d=Path(t);bin=d/'bin';bin.mkdir();log=d/'calls';state=d/'state';state.write_text('active')
 def script(n,s):
  p=bin/n;p.write_text('#!/bin/sh\n'+s);p.chmod(0o755)
 script('lipc-get-prop',f'''case "$3" in flIntensity) echo 14;; currentAmberLevel) echo 18;; state) cat '{state}';; esac\n''')
 script('lipc-set-prop',f'''printf '%s\\n' "$*" >> '{log}'
if [ "${{ZREADER_TEST_FAIL:-0}}" = 1 ]; then exit 1; fi
if [ "$3" = powerButton ]; then echo screenSaver > '{state}'; fi
''')
 script('lipc-wait-event',"printf '%s\\n' 'com.lab126.powerd goingToScreenSaver 2' 'com.lab126.powerd readyToSuspend 0' 'com.lab126.powerd wakeupFromSuspend 0'\nexec sleep 20\n")
 env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'])
 subprocess.run([str(R/'out/platform07-probe'),'device'],check=True,env=env,timeout=15)
 calls=log.read_text().splitlines();assert sum(' flIntensity ' in x for x in calls)==1,calls
 assert sum(' currentAmberLevel ' in x for x in calls)==1,calls
 assert any(x.endswith('flIntensity 24') for x in calls);assert any(x.endswith('currentAmberLevel 0') for x in calls)
 assert any('powerButton 1' in x for x in calls)
 assert not any('sysfs' in x or 'grayscale' in x for x in calls)
 subprocess.run([str(R/'out/platform07-probe'),'early-exit'],check=True,env=env,timeout=10)
 assert 'flIntensity 19' in log.read_text() and 'currentAmberLevel 7' in log.read_text()
 subprocess.run([str(R/'out/platform07-probe'),'failure'],check=True,env=dict(env,ZREADER_TEST_FAIL='1'),timeout=10)
 subprocess.run([str(R/'out/platform07-probe'),'timeout'],check=True,timeout=3)
 data=d/'data';thumbs=data/'thumbs';thumbs.mkdir(parents=True)
 for i in range(900):(thumbs/f'{i:016x}.zrt').write_bytes(bytes([255])*12288)
 outside=d/'private';outside.write_text('keep');(thumbs/'ffffffffffffffff.zrt').symlink_to(outside)
 subprocess.run([str(R/'out/platform07-probe'),'thumb',str(data),str(R.parent/'testbooks/digital-big.pdf')],check=True,timeout=18)
 assert sum(p.stat().st_size for p in thumbs.glob('*.zrt') if not p.is_symlink())<=10*1024*1024
 assert outside.read_text()=='keep' and (thumbs/'ffffffffffffffff.zrt').is_symlink()
 print('PASS cache <=10 MiB after eviction; symlink target preserved; real image-heavy PDF cover path')
 for n in ['killall','start','restart','lipc-set-prop']:
  script(n,f"printf '%s %s\\n' '{n}' \"$*\" >> '{log}'\n")
 subprocess.run(['sh',str(R/'zreader-maintenance.sh'),'restore-ui'],check=True,env=dict(env,ZREADER_US=str(d)),timeout=15)
 text=log.read_text()
 for n in ['awesome','volumd','blanket','Xorg']:assert f'killall -CONT {n}' in text
 assert 'restart pillow' in text and 'restart statusbar' in text and 'preventScreenSaver 0' in text
 print('PASS independent restore-ui sandbox resumes exact pause list, pillow/statusbar, inhibitor; no device touched')
