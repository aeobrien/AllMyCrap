import sys,socket,time,json,hashlib,uuid,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT))
from tools.inventory_session.mailbox import Mailbox,Server,Fault
from tools.inventory_session.client import Client
OUT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'reports/inventory-foreground-reads/candidate-hashes-01.json').read_text())|json.loads((ROOT/'reports/inventory-foreground-reads/unchanged-reader-models.json').read_text())
def hashes():return {p:{'expected':h,'actual':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for p,h in manifest.items()}
before=hashes();assert all(x['expected']==x['actual'] for x in before.values())
ids={k:str(uuid.uuid4()) for k in ('device','store','client')};m=Mailbox(**ids,client_token='synthetic-client',worker_token='synthetic-worker',clock=lambda:1.)
binding=dict(ids,scope=str(uuid.uuid4()));m.dispatch('/worker/hello',binding,'Bearer synthetic-worker')
s=Server(m);held=[];rows=[]
try:
 c=Client(s.url,'synthetic-client');rows.append({'case':'healthy initial request','pass':c.post('hello',{})==binding})
 for _ in range(8):
  x=socket.create_connection(('127.0.0.1',s.http.server_port),timeout=1);x.sendall(b'POST /client/hello HTTP/1.1\r\n');held.append(x)
 time.sleep(4.2)
 try:result=c.post('hello',{},timeout=1);available=result==binding;reason=None
 except (Fault,OSError) as exc:available=False;reason=getattr(exc,'code',type(exc).__name__)
 rows.append({'case':'incomplete unauthenticated headers release slots within finite request budget','pass':available,'error':reason,'held_connections':8,'wait_seconds':4.2})
finally:
 for x in held:x.close()
 time.sleep(.1);s.close()
after=hashes();assert before==after
(OUT/'http-stall-results.json').write_text(json.dumps({'checks':rows,'hashes_before':before,'hashes_after':after,'synthetic_loopback_only':True},indent=2)+'\n')
print(json.dumps(rows));assert all(x['pass'] for x in rows),'Eight incomplete HTTP requests permanently occupy all mailbox handlers'
