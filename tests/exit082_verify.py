# v0.8.2: fast paging / page turning can never trigger the exit gesture; the documented gesture still quits.
from pathlib import Path
import subprocess,tempfile,re,shutil
R=Path(__file__).resolve().parent.parent
PDF=R.parent/'testbooks/digital-small1.pdf';EPUB=R/'tests/fixture.epub'
GEST='exit gesture'
def run(data,books,script,name):
 s=Path(data).parent/'s.sim';s.write_text(script+'wait 500\nquit\n')
 p=subprocess.run([str(R/'out/zreader-host'),'--data',str(data),'--books',str(books),'--sim',str(s),'--idle-min','0'],capture_output=True,timeout=120,check=True)
 log=p.stderr.decode();(R/f'tests/{name}.log').write_text(log);return log
def burst(x,y,n=10,gap=40):return ''.join(f'tap {x} {y}\nwait {gap}\n' for _ in range(n))
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='exit082-') as t:
 d=Path(t);books=d/'books';books.mkdir();data=d/'data';data.mkdir()
 for i in range(1,61):shutil.copy(PDF if i%2==0 else EPUB,books/f'book{i:02}.{"pdf" if i%2==0 else "epub"}')
 # library: 10 rapid Next (incl. the reported spot and the extreme corner of the button), then 10 rapid Prev
 lib='wait 2000\n'+burst(1052,1655)+burst(1195,1650,5)+'wait 1500\n'+burst(200,1606)+burst(75,1650,5)+'wait 1500\n'
 log=run(data,books,lib,'exit082-library')
 pages=[int(m) for m in re.findall(r'library page: (\d+)',log)]
 assert GEST not in log and 'corner triple tap' not in log,log[-2000:]
 assert max(pages)>=3 and pages[-1]==1,pages
 print('PASS library: 15 rapid Next + 15 rapid Prev taps (bottom corners) page normally, never quit; pages seen',pages)
 for name,book in (('epub','book01.epub'),('pdf','book02.pdf')):
  # open the book via the library row, then 10 rapid taps in every corner and both turn zones
  idx=0 if name=='epub' else 1
  sc='wait 2000\n'+f'tap 600 {330+75+idx*150}\nwait 3000\n'
  for x,y in ((1220,50),(1220,1650),(50,1650),(50,50),(1100,850),(150,850)):sc+=burst(x,y)+'wait 600\n'
  log=run(data,books,sc,f'exit082-reader-{name}')
  assert GEST not in log and 'corner triple tap' not in log,log[-2000:]
  assert f'books/{book}' in log,log[:2000]
  turns=int(re.search(r'session: turns=(\d+)',log)[1])
  assert turns>=50,turns
  print(f'PASS reader {name}: 60 rapid taps in all four corners and both turn zones -> {turns} page turns, never quit')
 # documented gesture still quits: three taps in the library's top-left corner
 log=run(data,books,'wait 2000\n'+burst(60,60,3,150)+'wait 3000\n'+burst(1052,1655,3),'exit082-gesture')
 assert GEST in log,log[-2000:]
 after=log.split(GEST,1)[1]
 assert 'library page: 1' not in after,after
 print('PASS exit gesture: 3 taps in top-left corner of the library quits (and nothing after it ran)')
 # a handled tap between corner taps resets the count
 log=run(data,books,'wait 2000\n'+burst(60,60,2,150)+burst(1052,1655,1)+burst(60,60,2,150)+'wait 1500\n','exit082-reset')
 assert GEST not in log,log[-2000:]
 print('PASS reset: corner, corner, Next, corner, corner does not quit')
