"""Real loopback session→URLSession worker→temporary SwiftData→reply proof."""
import sys,os,json,pathlib,subprocess,tempfile,platform,time,uuid,secrets,threading
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from tools.inventory_session.mailbox import Mailbox,Server,canonical,Fault
from tools.inventory_session.client import Client
from tests.inventory_session_protocol import registration,FILES

def main():
 registration()
 # A fixture host is necessary; compiling library classes alone is not delivery.
 assert (ROOT/'tests/inventory_session_worker.swift').exists(),'Automatic worker consumer not implemented'
 passed=[]
 def check(name,value):
  assert value,name;passed.append(name)
 with tempfile.TemporaryDirectory(prefix='inventory-roundtrip-') as td:
  p=pathlib.Path(td);ids={k:str(uuid.uuid4()) for k in ('device','store','client')};tokens={k:secrets.token_urlsafe(32) for k in ('client','worker')}
  mailbox=Mailbox(**ids,client_token=tokens['client'],worker_token=tokens['worker']);server=Server(mailbox);client=Client(server.url,tokens['client']);proc=None
  try:
   try:client.post('hello',{});raise AssertionError('unexpected ready')
   except Fault as e:check('inactive is unavailable',e.code=='unavailable')
   names=['Location.swift','Item.swift','Tag.swift','ReviewHistory.swift','DuplicateExclusion.swift','InventoryReadAdapter.swift',*FILES]
   command=['xcrun','swiftc','-swift-version','5','-target',platform.machine()+'-apple-macos14.0','-module-cache-path',str(p/'cache'),*[str(ROOT/'AllMyCrap'/n) for n in names],str(ROOT/'tests/inventory_session_worker.swift'),'-o',str(p/'worker')]
   subprocess.run(command,check=True,timeout=100)
   cfg=dict(ids,endpoint=server.url,token=tokens['worker']);(p/'config.json').write_bytes(canonical(cfg));os.chmod(p/'config.json',0o600)
   log=(p/'worker.log').open('w');proc=subprocess.Popen([str(p/'worker'),str(p)],stdout=log,stderr=log)
   def waitfor(path,timeout=10):
    until=time.monotonic()+timeout
    while not path.exists():
     if proc.poll() is not None:raise AssertionError('worker exited: '+(p/'worker.log').read_text()[-2000:])
     if time.monotonic()>until:raise AssertionError('fixture readiness timeout')
     time.sleep(.02)
    return json.loads(path.read_text())
   ready=waitfor(p/'ready.json');binding=None
   until=time.monotonic()+6
   while binding is None:
    try:binding=client.post('hello',{})
    except Fault:
     if time.monotonic()>until:raise
     time.sleep(.05)
   def read(args):return client.read(client.prepare(args),timeout=8)
   status=read({'op':'status'});check('real worker status',status['result']['counts']['items']==3 and status['transactionalSnapshot'] is False)
   args={'op':'list','kind':'items','archive':'all','size':2,'cursor':None}
   first=read(args);args['cursor']=first['result']['next'];second=read(args)
   records=first['result']['records']+second['result']['records'];found=sorted(r['item']['_0']['id'].lower() for r in records)
   check('actual items and stable page cursor',found==sorted(ready['items']) and second['result']['complete'])
   for kind,key in [('locations','locations'),('tags','tags')]:check('real '+kind+' list',read({'op':'list','kind':kind,'archive':'all','size':10,'cursor':None})['result']['total']==1)
   show=read({'op':'show','kind':'items','id':ready['items'][0]});check('exact show',show['result']['record']['item']['_0']['id'].lower()==ready['items'][0])
   check('not found remains error',read({'op':'show','kind':'items','id':str(uuid.uuid4())})['error']=='notFound')
   request=client.prepare({'op':'status'});original=client.read(request,timeout=8);check('completed retry identical',client.read(request,timeout=8)==original)
   changed=dict(request,arguments={'op':'show','kind':'items','id':ready['items'][0]});import hashlib;changed['digest']=hashlib.sha256(canonical({k:v for k,v in changed.items() if k!='digest'})).hexdigest()
   try:client.post('submit',changed);raise AssertionError('conflict allowed')
   except Fault as e:check('changed retry refused',e.code=='request_conflict')
   sequence=0
   def control(action):
    nonlocal sequence
    sequence+=1;tmp=p/'control.tmp';tmp.write_bytes(canonical({'sequence':sequence,'action':action}));tmp.replace(p/'control.json');return waitfor(p/f'control-{sequence}.json')
   control('edit');check('pending caller edits preserved',read({'op':'status'})['error']=='pendingEdits')
   check('fixture confirms edit remains',control('save')['pending_before_save'])
   check('changed store stales prior cursor',read(args)['error']=='staleCursor')
   control('inactive');count=len(mailbox.events);time.sleep(1.3);check('inactive stops polling',len(mailbox.events)==count)
   control('active');time.sleep(.25);newbinding=client.post('hello',{});check('new activation changes scope',newbinding['scope']!=binding['scope'])
   check('previous cursor rejected after restart',read(args)['error']=='invalidCursor')
   cancelled=client.prepare({'op':'status'});flag=threading.Event();flag.set()
   try:client.read(cancelled,timeout=8,cancel=flag);raise AssertionError('cancel failed')
   except Fault as e:check('explicit cancellation',e.code=='cancelled')
   control('inactive');delayed=client.prepare({'op':'status'})
   try:client.read(delayed,timeout=.2);raise AssertionError('timeout failed')
   except Fault as e:check('bounded pending deadline',e.code=='deadline')
   control('active');time.sleep(.25)
   try:client.post('result',{k:v for k,v in delayed.items() if k not in ('version','arguments')});raise AssertionError('late scope accepted')
   except Fault as e:check('late result cannot change session',e.code=='binding')
   check('no fixture mutation from reads',control('inspect')['item_count']==3)
   control('stop');proc.wait(timeout=5);check('owned worker stopped',proc.returncode==0)
   trace=[x['path'] for x in mailbox.events];check('actual HTTP claim and publish',mailbox.counts.get('/worker/result',0)>=11 and mailbox.counts.get('/worker/next',0)>=12)
   from tests.inventory_transport_probes import run
   passed.extend(run(p/'worker',p,ids,tokens['worker']))
  finally:
   if proc is not None and proc.poll() is None:
    proc.terminate()
    try:proc.wait(timeout=3)
    except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=3)
   server.close()
   print(json.dumps({'partial_assertions':passed,'http_counts':mailbox.counts,'worker_events':[e for e in mailbox.events if e['path'].startswith('/worker/')],'worker_terminal':proc is None or proc.poll() is not None}))
  print(json.dumps({'passed':len(passed),'assertions':passed,'real_loopback':True,'temporary_SwiftData':True,'real_inventory':False}));assert len(passed)==25
if __name__=='__main__':main()
