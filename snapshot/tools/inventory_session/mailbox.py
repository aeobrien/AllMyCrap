"""Bounded in-memory loopback prototype. No production listener or data store."""
import hashlib,hmac,json,socket,threading,time,uuid
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
REQUEST_LIMIT=16*1024
RESPONSE_LIMIT=2*1024*1024

def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()
def decode(raw,limit,require_canonical=True):
 if len(raw)>limit:raise Fault(413,'oversized')
 def pairs(items):
  result={}
  for key,value in items:
   if key in result:raise Fault(400,'duplicate_key')
   result[key]=value
  return result
 try:
  result=json.loads(raw,object_pairs_hook=pairs,parse_constant=lambda _:(_ for _ in ()).throw(ValueError()))
  if not isinstance(result,dict) or (require_canonical and canonical(result)!=raw):raise ValueError()
  return result
 except (ValueError,TypeError):raise Fault(400,'invalid')
def identity(value):
 try:
  if not isinstance(value,str) or str(uuid.UUID(value))!=value:raise ValueError()
  return value
 except (ValueError,TypeError,AttributeError):raise Fault(400,'identity')
class Fault(Exception):
 def __init__(self,status,code):self.status=status;self.code=code

def validate_request(value,binding):
 if set(value)!={'version','request','digest','device','store','client','scope','arguments'} or type(value['version']) is not int or value['version']!=1:raise Fault(400,'invalid')
 identity(value['request'])
 for key in ('device','store','client','scope'):
  identity(value[key])
  if value[key]!=binding[key]:raise Fault(409,'binding')
 core={k:v for k,v in value.items() if k!='digest'}
 if value['digest']!=hashlib.sha256(canonical(core)).hexdigest():raise Fault(400,'digest')
 a=value['arguments']
 if not isinstance(a,dict):raise Fault(400,'arguments')
 if a.get('op')=='status':valid=set(a)=={'op'}
 elif a.get('op')=='list':
  valid=set(a)=={'op','kind','archive','size','cursor'} and a['kind'] in ('items','locations','tags') and a['archive'] in ('active','archived','all') and (a['kind']=='items' or a['archive']=='all') and type(a['size']) is int and 1<=a['size']<=100 and (a['cursor'] is None or isinstance(a['cursor'],str) and len(a['cursor'].encode())<=2048)
 elif a.get('op')=='show':
  valid=set(a)=={'op','kind','id'} and a['kind'] in ('items','locations','tags');identity(a.get('id'))
 else:valid=False
 if not valid:raise Fault(400,'arguments')

class Mailbox:
 def __init__(self,device,store,client,client_token,worker_token,clock=time.monotonic):
  self.base={k:identity(v) for k,v in dict(device=device,store=store,client=client).items()}
  if not client_token or not worker_token or client_token==worker_token:raise ValueError('Separate fixture credentials required')
  self.tokens={'client':client_token,'worker':worker_token};self.clock=clock;self.lock=threading.RLock();self.binding=None;self.last_seen=0.;self.rows={};self.events=[];self.counts={}
 def event(self,path,code):
  with self.lock:
   known={'/worker/hello','/worker/next','/worker/result','/worker/offline','/client/hello','/client/submit','/client/result','/client/cancel'}
   key=path if path in known else 'unknown'
   self.events.append({'path':key,'code':code});self.events=self.events[-256:]
   self.counts[key]=self.counts.get(key,0)+1
 def active(self):return self.binding is not None and self.clock()-self.last_seen<4
 def prune(self):
  # Tombstones retain ID ownership until session reset: never reexecute an expired ID.
  for row in self.rows.values():
   if self.clock()>=row['expires']:row['state']='expired';row['result']=None
 def dispatch(self,path,value,token):
  with self.lock:
   parts=path.split('/')
   if len(parts)!=3 or parts[0]!='' or parts[1] not in self.tokens:raise Fault(404,'endpoint')
   role,op=parts[1:]
   if not hmac.compare_digest(token,'Bearer '+self.tokens[role]):raise Fault(401,'unauthorized')
   self.prune()
   if role=='worker':
    if op=='hello':
     if set(value)!=set(self.base)|{'scope'} or any(value.get(k)!=v for k,v in self.base.items()):raise Fault(409,'binding')
     identity(value['scope'])
     if self.binding!=value:
      self.rows={};self.binding=dict(value)
     self.last_seen=self.clock();return {}
    if op in ('next','offline'):
     if value!=self.binding:raise Fault(409,'binding')
     if op=='offline':self.last_seen=float('-inf');return {}
     self.last_seen=self.clock()
     for row in self.rows.values():
      if row['state']=='queued':row['state']='claimed';return row['request']
     return {}
    if op=='result':
     required={'version','request','digest','device','store','client','scope','result','error','build','observed_at','transactionalSnapshot'}
     if set(value)!=required or value.get('version')!=1 or type(value.get('version')) is not int or value.get('transactionalSnapshot') is not False or not isinstance(value.get('build'),str) or not isinstance(value.get('observed_at'),str):raise Fault(400,'invalid_result')
     if not self.active() or any(value.get(k)!=v for k,v in self.binding.items()):raise Fault(409,'binding')
     identity(value.get('request'))
     row=self.rows.get(value.get('request'))
     if not row or value.get('digest')!=row['request']['digest']:raise Fault(409,'request')
     if row['state']=='complete':
      if row['result']!=value:raise Fault(409,'result_conflict')
      return {}
     if row['state']!='claimed':raise Fault(409,row['state'])
     if (value['error'] is None)==(value['result'] is None) or (value['result'] is not None and not isinstance(value['result'],dict)):raise Fault(400,'invalid_result')
     if value['error'] is not None and value['error'] not in ('pendingEdits','invalidQuery','notFound','invalidCursor','staleCursor','rowLimit','fieldLimit','projectionLimit','responseLimit','invalidData','unsupportedSchema','readUnavailable'):raise Fault(400,'invalid_error')
     if len(canonical(value))>RESPONSE_LIMIT:raise Fault(413,'oversized')
     row['state']='complete';row['result']=value;return {}
   else:
    if op=='hello':
     if value!={}:raise Fault(400,'invalid')
     if not self.active():raise Fault(503,'unavailable')
     return self.binding
    if op=='submit':
     if self.binding is None:raise Fault(503,'unavailable')
     validate_request(value,self.binding)
     if len(canonical(value))>REQUEST_LIMIT:raise Fault(413,'oversized')
     key=value['request'];row=self.rows.get(key)
     if row:
      if row['request']!=value:raise Fault(409,'request_conflict')
      return {'state':row['state']}
     if not self.active():raise Fault(503,'unavailable')
     if len(self.rows)>=32:raise Fault(429,'capacity')
     self.rows[key]={'request':value,'state':'queued','result':None,'expires':self.clock()+300}
     return {'state':'queued'}
    if op in ('result','cancel'):
     if set(value)!={'request','digest','device','store','client','scope'} or self.binding is None or any(value.get(k)!=v for k,v in self.binding.items()):raise Fault(409,'binding')
     identity(value.get('request'))
     row=self.rows.get(value.get('request'))
     if not row:raise Fault(404,'unknown')
     if row['request']['digest']!=value['digest']:raise Fault(409,'digest')
     if op=='cancel' and row['state'] in ('queued','claimed'):row['state']='cancelled'
     return {'state':row['state'],'response':row['result']}
   raise Fault(404,'endpoint')

class Server:
 def __init__(self,mailbox):
  self.mailbox=mailbox;outer=self
  class Handler(BaseHTTPRequestHandler):
   def log_message(self,*args):pass
   def do_POST(self):
    status=200
    try:
     if self.headers.get('Transfer-Encoding') or self.headers.get('Content-Type')!='application/json':raise Fault(400,'headers')
     limit=RESPONSE_LIMIT if self.path=='/worker/result' else REQUEST_LIMIT
     try:size=int(self.headers.get('Content-Length','-1'))
     except ValueError:raise Fault(400,'length')
     if not 0<=size<=limit:raise Fault(413,'oversized')
     self.connection.settimeout(3)
     body=self.rfile.read(size)
     if len(body)!=size:raise Fault(400,'length')
     value=decode(body,limit,require_canonical=self.path!='/worker/result');result=outer.mailbox.dispatch(self.path,value,self.headers.get('Authorization',''))
    except Fault as e:status=e.status;result={'error':e.code}
    except (OSError,ValueError):status=400;result={'error':'invalid'}
    outer.mailbox.event(self.path,str(status));raw=canonical(result)
    try:
     self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
    except OSError:pass
  class BoundedServer(ThreadingHTTPServer):
   slots=threading.BoundedSemaphore(8)
   def process_request(self,request,address):
    if not self.slots.acquire(blocking=False):self.shutdown_request(request);return
    try:super().process_request(request,address)
    except BaseException:self.slots.release();raise
   def process_request_thread(self,request,address):
    # Start before BaseHTTPRequestHandler reads even the request line. An absolute
    # timer, unlike socket inactivity timeouts, cannot be extended by trickling.
    # Shutdown this owned socket without closing/reusing its descriptor; the
    # handler's normal finally path closes it and releases its capacity slot.
    def expire():
     try:request.shutdown(socket.SHUT_RDWR)
     except OSError:pass
    deadline=threading.Timer(3,expire);deadline.daemon=True;deadline.start()
    try:super().process_request_thread(request,address)
    finally:
     deadline.cancel();self.slots.release()
  self.http=BoundedServer(('127.0.0.1',0),Handler);self.http.daemon_threads=True
  self.thread=threading.Thread(target=self.http.serve_forever,daemon=True);self.thread.start();self.url='http://127.0.0.1:'+str(self.http.server_port)
 def close(self):self.http.shutdown();self.thread.join(timeout=3);self.http.server_close()
