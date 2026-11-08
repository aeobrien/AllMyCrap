"""Explicit-config local prototype session client; never discovers real inventory."""
import argparse,hashlib,json,time,uuid,urllib.parse,http.client,socket
from pathlib import Path
try:from .mailbox import canonical,decode,validate_request,RESPONSE_LIMIT,Fault
except ImportError:from mailbox import canonical,decode,validate_request,RESPONSE_LIMIT,Fault
class Client:
 def __init__(self,endpoint,token):
  u=urllib.parse.urlsplit(endpoint)
  if u.scheme!='http' or u.hostname!='127.0.0.1' or u.username or u.password or u.path not in ('','/') or u.query or u.fragment or not u.port:raise ValueError('Explicit loopback prototype endpoint required')
  if not isinstance(token,str) or not 0<len(token)<=512 or any(not c.isascii() or c.isspace() for c in token):raise ValueError('Opaque credential required')
  self.endpoint=endpoint.rstrip('/');self.token=token;self.port=u.port
 def post(self,path,value,timeout=3):
  if path not in ('hello','submit','result','cancel'):raise ValueError('Unknown client operation')
  raw=canonical(value)
  if len(raw)>16*1024:raise Fault(413,'oversized')
  deadline=time.monotonic()+min(3,timeout)
  conn=http.client.HTTPConnection('127.0.0.1',self.port,timeout=max(.001,min(3,timeout)))
  try:
   conn.request('POST','/client/'+path,body=raw,headers={'Authorization':'Bearer '+self.token,'Content-Type':'application/json'})
   if conn.sock is not None:conn.sock.settimeout(max(.001,deadline-time.monotonic()))
   response=conn.getresponse();data=bytearray();limit=RESPONSE_LIMIT if response.status==200 else 1024
   # HTTPConnection does not follow redirects or inherit proxy configuration.
   while True:
    remaining=deadline-time.monotonic()
    if remaining<=0:raise Fault(408,'deadline')
    # Keep a wall-clock budget even when a peer trickles body bytes.
    if response.fp is not None:
     response.fp.raw._sock.settimeout(remaining)
    chunk=response.read1(min(65536,limit+1-len(data)))
    if not chunk:break
    data.extend(chunk)
    if len(data)>limit:raise Fault(413,'oversized')
   if response.status!=200:
    try:code=json.loads(data)['error']
    except (ValueError,KeyError,TypeError):code='transport'
    raise Fault(response.status,code)
   return decode(bytes(data),RESPONSE_LIMIT,require_canonical=False)
  except (socket.timeout,TimeoutError):raise Fault(408,'deadline') from None
  except (OSError,http.client.HTTPException):raise Fault(503,'transport') from None
  finally:conn.close()
 def prepare(self,arguments,request_id=None):
  binding=self.post('hello',{});value=dict(binding,version=1,request=request_id or str(uuid.uuid4()),arguments=arguments)
  value['digest']=hashlib.sha256(canonical(value)).hexdigest();validate_request(value,binding);return value
 def read(self,request,timeout=30,cancel=None):
  if not 0<timeout<=30:raise ValueError('Bounded wait required')
  deadline=time.monotonic()+timeout
  self.post('submit',request,timeout=timeout);selector={k:v for k,v in request.items() if k not in ('version','arguments')}
  while True:
   remaining=deadline-time.monotonic()
   if remaining<=0:raise Fault(408,'deadline')
   if cancel is not None and cancel.is_set():self.post('cancel',selector,timeout=remaining);raise Fault(409,'cancelled')
   value=self.post('result',selector,timeout=remaining)
   if value['state']=='complete':
    result=value['response']
    if any(result.get(k)!=v for k,v in selector.items()):raise Fault(409,'response_binding')
    return result
   if value['state'] not in ('queued','claimed'):raise Fault(409,value['state'])
   if time.monotonic()>=deadline:raise Fault(408,'deadline')
   time.sleep(.05)
def main():
 p=argparse.ArgumentParser();p.add_argument('--endpoint',required=True);p.add_argument('--token-file',required=True);p.add_argument('--request-file',required=True);a=p.parse_args()
 c=Client(a.endpoint,Path(a.token_file).read_text().strip());print(json.dumps(c.read(c.prepare(json.loads(Path(a.request_file).read_text())))))
if __name__=='__main__':main()
