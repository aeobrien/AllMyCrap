import sys,socket,time,json,hashlib,uuid,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT))
from tools.inventory_session.mailbox import Mailbox,Server
from tools.inventory_session.client import Client
OUT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'reports/inventory-foreground-reads/candidate-hashes-02.json').read_text())|json.loads((ROOT/'reports/inventory-foreground-reads/unchanged-reader-models.json').read_text())
def hashes():return {p:{'expected':h,'actual':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for p,h in manifest.items()}
before=hashes();assert all(x['expected']==x['actual'] for x in before.values());rows=[]
def check(case,ok,detail=None):rows.append({'case':case,'pass':bool(ok),'detail':detail})
for label,prefix,drip in [('silent before request line',b'',False),('original incomplete headers',b'POST /client/hello HTTP/1.1\r\n',False),('continuous header progress',b'POST /client/hello HTTP/1.1\r\nX-Canary: ',True),('continuous body progress',b'POST /client/hello HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 10000\r\nAuthorization: Bearer synthetic-client\r\n\r\n',True)]:
 ids={k:str(uuid.uuid4()) for k in ('device','store','client')};m=Mailbox(**ids,client_token='synthetic-client',worker_token='synthetic-worker',clock=lambda:1.)
 binding=dict(ids,scope=str(uuid.uuid4()));m.dispatch('/worker/hello',binding,'Bearer synthetic-worker');s=Server(m);held=[];senders=[];stop=threading.Event()
 def trickle(x):
  while not stop.wait(.03):
   try:x.sendall(b' ')
   except OSError:return
 try:
  c=Client(s.url,'synthetic-client');check(label+' initial normal read',c.post('hello',{})==binding)
  start=time.monotonic()
  for _ in range(8):
   x=socket.create_connection(('127.0.0.1',s.http.server_port),timeout=1);x.sendall(prefix);held.append(x)
   if drip:
    t=threading.Thread(target=trickle,args=(x,),daemon=True);t.start();senders.append(t)
  until=time.monotonic()+1
  while s.http.slots._value and time.monotonic()<until:time.sleep(.01)
  check(label+' all slots occupied',s.http.slots._value==0)
  time.sleep(max(0,3.5-(time.monotonic()-start)))
  check(label+' slots recovered by whole deadline',s.http.slots._value==8,{'elapsed':time.monotonic()-start,'slots':s.http.slots._value})
  check(label+' subsequent authenticated read works',c.post('hello',{},timeout=1)==binding)
  check(label+' no partial request retained',m.rows=={})
 finally:
  stop.set()
  for x in held:x.close()
  for t in senders:t.join(timeout=1)
  s.close()
after=hashes();check('all24 frozen inputs stable',before==after)
(OUT/'http-budget-results-02.json').write_text(json.dumps({'checks':rows,'hashes_before':before,'hashes_after':after,'synthetic_loopback_only':True},indent=2)+'\n');print(json.dumps({'checks':len(rows),'passed':sum(x['pass'] for x in rows),'failures':[x for x in rows if not x['pass']]}));assert all(x['pass'] for x in rows)
