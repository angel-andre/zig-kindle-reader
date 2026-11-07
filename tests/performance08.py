from pathlib import Path
import subprocess,tempfile,time,json,re,os
R=Path(__file__).resolve().parent.parent
cases=[R.parent/'diag/scan-d.pdf',R.parent/'testbooks/digital-big.pdf',R.parent/'testbooks/digital-small1.pdf',R/'tests/large08.epub']
results=[]
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='perf08-') as t:
 d=Path(t);(d/'empty').mkdir();script=d/'open.sim';script.write_text('wait 1800\nquit\n')
 for book in cases:
  for label,exe in [('v07',R/'tests/v07-baseline/zreader-host'),('v08',R/'out/zreader-host')]:
   data=d/(label+book.stem);data.mkdir()
   for iteration in range(2 if label=='v08' else 1):
    script.write_text(('wait 6000\nquit\n') if label=='v07' and book.suffix=='.epub' else 'wait 1800\nquit\n')
    a=time.monotonic();p=subprocess.Popen([str(exe),'--data',str(data),'--books',str(d/'empty'),'--sim',str(script),'--shots',str(R/'shots'),'--idle-min','0',str(book)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
    lines=[];first=None;opened=None
    for line in p.stderr:
     lines.append(line)
     if opened is None and line.startswith('opened '):opened=(time.monotonic()-a)*1000
     if first is None and 'page refresh:' in line:first=(time.monotonic()-a)*1000
    assert p.wait(timeout=30)==0
    log=''.join(lines);(R/'tests'/f'perf08-{label}-{book.stem}-{iteration}.log').write_text(log)
    results.append(dict(book=book.name,version=label,cache='warm' if iteration else 'cold app cache',first_submit_ms=round(first,3) if first is not None else None,no_frame_lower_bound_ms=round(opened+6000,3) if first is None else None,profile=re.findall(r'open profile:.*',log)))
 # Independently time page-one cover path: only the first spine item is laid out in v08.
 for label,exe in [('v07',R/'tests/v07-baseline/zreader-host'),('v08',R/'out/zreader-host')]:
  a=time.monotonic()
  for i in range(7):subprocess.run([str(exe),'--make-thumb',str(cases[-1]),str(d/f'{label}{i}.raw')],check=True,timeout=20,capture_output=True)
  results.append(dict(book='7 large EPUB covers (serial cold generation)',version=label,milliseconds=round((time.monotonic()-a)*1000,3)))
(R/'tests/performance08.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
