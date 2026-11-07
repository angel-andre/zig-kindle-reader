# v0.9.1 Wi-Fi upload (host only): upload, bad names/types, free-space refusal, server stops on leaving the screen.
from pathlib import Path
import subprocess,tempfile,time,socket,http.client,urllib.parse,shutil,re
R=Path(__file__).resolve().parent.parent
EPUB=R/'tests/fixture.epub';PDF=R/'tests/tall-view-fixture.pdf'
PORT=18091
SCRIPT='wait 1500\ntap 1010 262\nwait 800\ntap 636 1485\nwait 7000\ntap 1127 85\nwait 8000\nquit\n'
def start(d,extra=()):
 s=d/'s.sim';s.write_text(SCRIPT)
 return subprocess.Popen([str(R/'out/zreader-host'),'--data',str(d/'data'),'--books',str(d/'books'),'--sim',str(s),'--shots',str(d/'shots'),'--idle-min','0','--upload-port',str(PORT),*extra,'--log',str(d/'log.txt')])
def wait_port(t=6):
 end=time.time()+t
 while time.time()<end:
  try:socket.create_connection(('127.0.0.1',PORT),0.3).close();return True
  except OSError:time.sleep(0.1)
 return False
def post(name,data):
 c=http.client.HTTPConnection('127.0.0.1',PORT,timeout=10);c.request('POST','/upload?name='+urllib.parse.quote(name,safe=''),body=data,headers={'Content-Length':str(len(data))})
 r=c.getresponse();b=r.read().decode();c.close();return r.status,b
def port_open():
 try:socket.create_connection(('127.0.0.1',PORT),0.5).close();return True
 except OSError:return False
with tempfile.TemporaryDirectory(dir=R/'tests',prefix='up091-') as t:
 d=Path(t);(d/'books').mkdir();(d/'data').mkdir();shutil.copy(EPUB,d/'books/existing.epub')
 assert not port_open(),'port already in use before the screen opens'
 p=start(d);time.sleep(1.2);assert not port_open(),'server must not run before the Upload screen is opened'
 assert wait_port(),'server did not start on the Upload screen'
 c=http.client.HTTPConnection('127.0.0.1',PORT,timeout=5);c.request('GET','/');r=c.getresponse();page=r.read().decode();assert r.status==200 and 'Send books' in page
 ok=[post('New Book.epub',EPUB.read_bytes()),post('scan.PDF',PDF.read_bytes()),post('existing.epub',EPUB.read_bytes())]
 assert all(s==200 for s,_ in ok),ok
 bad={n:post(n,b'x'*100) for n in ['../evil.epub','..%2Fevil.epub','sub/dir.pdf','.hidden.epub','notes.txt','book.exe','run.sh','book.epub.exe','a\\b.pdf','nul\x01.pdf','']}
 assert all(s in (400,404) for s,_ in bad.values()),bad
 end=time.time()+20
 while port_open() and time.time()<end:time.sleep(0.1)
 assert not port_open() and p.poll() is None,'server must stop when the screen closes, while the app keeps running'
 p.wait(timeout=30);out=(d/'log.txt').read_text();(R/'tests/up091-upload.log').write_text(out.replace(str(d),'TMP'))
 files=sorted(x.name for x in (d/'books').iterdir())
 assert files==['New Book.epub','existing (2).epub','existing.epub','scan.PDF'],files
 assert not any(x.name.startswith('.') for x in d.rglob('*')),'temp file left behind'
 assert not (d.parent/'evil.epub').exists() and not (d/'evil.epub').exists()
 assert 'upload server: stopped; 3 book(s) received' in out and re.findall(r'library: (\d+) books',out)[-1]=='4',out[-800:]
 print('PASS upload: page served, 2 books saved, a duplicate saved as "existing (2).epub" (never overwritten), library rescanned to 4 books')
 print('PASS rejected', len(bad), 'bad names/types (path traversal, hidden, subfolders, non-PDF/EPUB, control chars, empty) with no file written')
 print('PASS server not listening before the screen opens or after Close')
 # free-space floor: ask for an impossible minimum -> refused, nothing written
 shutil.rmtree(d/'books');(d/'books').mkdir()
 p=start(d,('--upload-min-free-mib',str(1<<40)));assert wait_port(4)
 s,b=post('big.epub',EPUB.read_bytes());assert s==507 and 'free space' in b,(s,b)
 end=time.time()+20
 while port_open() and time.time()<end:time.sleep(0.1)
 assert not port_open() and p.poll() is None
 p.wait(timeout=30);assert list((d/'books').iterdir())==[]
 print('PASS free-space floor: upload refused (507) when it would leave less than the minimum; nothing written')
