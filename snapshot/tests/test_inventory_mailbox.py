import copy,hashlib,json,sys,threading,time,unittest,uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.inventory_session.mailbox import Mailbox,Fault,canonical,decode,validate_request,REQUEST_LIMIT,RESPONSE_LIMIT
class MailboxTests(unittest.TestCase):
 def setUp(self):
  self.now=[1.];self.ids={k:str(uuid.uuid4()) for k in ('device','store','client')};self.m=Mailbox(**self.ids,client_token='synthetic-client',worker_token='synthetic-worker',clock=lambda:self.now[0]);self.binding=dict(self.ids,scope=str(uuid.uuid4()));self.call('worker','hello',self.binding)
 def call(self,role,op,value):return self.m.dispatch('/'+role+'/'+op,value,'Bearer synthetic-'+role)
 def request(self,arguments=None):
  d=dict(self.binding,version=1,request=str(uuid.uuid4()),arguments=arguments or {'op':'status'});d['digest']=hashlib.sha256(canonical(d)).hexdigest();return d
 def expect(self,code,body):
  with self.assertRaises(Fault) as caught:body()
  self.assertEqual(caught.exception.code,code)
 def selector(self,r):return {k:v for k,v in r.items() if k not in ('version','arguments')}
 def reply(self,r):return dict(self.selector(r),version=1,observed_at='2030-01-01T00:00:00Z',build='synthetic',transactionalSnapshot=False,error=None,result={'counts':{'items':0}})
 def test_roles_and_bindings(self):
  self.expect('unauthorized',lambda:self.m.dispatch('/worker/next',self.binding,'Bearer synthetic-client'))
  self.expect('unauthorized',lambda:self.m.dispatch('/client/hello',{},'Bearer synthetic-worker'))
  for key in ('device','store','client','scope'):
   r=self.request();r[key]=str(uuid.uuid4());self.expect('binding',lambda:self.call('client','submit',r))
 def test_argument_validation_and_digest(self):
  for a in ({'op':'remove'},{'op':'status','file':'/SYNTHETIC'},{'op':'list','kind':'items','archive':'all','size':True,'cursor':None},{'op':'list','kind':'tags','archive':'active','size':1,'cursor':None}):self.expect('arguments',lambda:self.call('client','submit',self.request(a)))
  r=self.request();r['digest']='bad';self.expect('digest',lambda:self.call('client','submit',r));self.assertEqual(self.m.rows,{})
 def test_duplicate_nonfinite_oversized(self):
  for raw in (b'{"x":1,"x":2}',b'{"x":NaN}',b'{"x":Infinity}'):
   with self.assertRaises(Fault):decode(raw,REQUEST_LIMIT)
  self.expect('oversized',lambda:decode(b' '* (REQUEST_LIMIT+1),REQUEST_LIMIT))
 def test_response_numbers_need_not_be_byte_canonical(self):
  self.assertEqual(decode(b'{"date":1.0e+20}',RESPONSE_LIMIT,False),{'date':1e20})
  self.expect('duplicate_key',lambda:decode(b'{"date":1,"date":2}',RESPONSE_LIMIT,False))
 def test_completed_retry_and_conflict(self):
  r=self.request();self.call('client','submit',r);self.assertEqual(self.call('worker','next',self.binding),r);reply=self.reply(r);self.call('worker','result',reply)
  self.now[0]+=5;self.assertEqual(self.call('client','submit',r),{'state':'complete'});self.assertEqual(self.call('client','result',self.selector(r))['response'],reply)
  altered=dict(r,arguments={'op':'show','kind':'items','id':str(uuid.uuid4())});altered['digest']=hashlib.sha256(canonical({k:v for k,v in altered.items() if k!='digest'})).hexdigest();self.expect('request_conflict',lambda:self.call('client','submit',altered))
 def test_cancellation_rejects_late_reply(self):
  r=self.request();self.call('client','submit',r);self.call('worker','next',self.binding);self.call('client','cancel',self.selector(r));self.expect('cancelled',lambda:self.call('worker','result',self.reply(r)))
 def test_expiry_keeps_tombstone(self):
  r=self.request();self.call('client','submit',r);self.now[0]+=301;self.call('worker','next',self.binding)
  self.assertEqual(self.call('client','submit',r),{'state':'expired'});self.assertEqual(self.call('worker','next',self.binding),{})
 def test_liveness_and_scope_reset(self):
  r=self.request();self.call('client','submit',r);self.now[0]+=5;self.expect('unavailable',lambda:self.call('client','hello',{}))
  new=dict(self.binding,scope=str(uuid.uuid4()));self.call('worker','hello',new);self.expect('binding',lambda:self.call('worker','result',self.reply(r)))
 def test_finite_custody(self):
  for _ in range(32):self.call('client','submit',self.request())
  self.expect('capacity',lambda:self.call('client','submit',self.request()));self.assertEqual(len(self.m.rows),32)
 def test_response_binding_overflow_and_shape(self):
  r=self.request();self.call('client','submit',r);self.call('worker','next',self.binding);reply=self.reply(r)
  wrong=dict(reply,digest='bad');self.expect('request',lambda:self.call('worker','result',wrong))
  wrong=dict(reply,result={'large':'x'*RESPONSE_LIMIT});self.expect('oversized',lambda:self.call('worker','result',wrong))
  wrong=dict(reply,error='invented');self.expect('invalid_result',lambda:self.call('worker','result',wrong))
  self.assertEqual(self.m.rows[r['request']]['state'],'claimed')
 def test_unhashable_request_is_typed_refusal(self):
  r=self.request();self.call('client','submit',r);selector=self.selector(r);selector['request']=[]
  self.expect('identity',lambda:self.call('client','result',selector))
  reply=self.reply(r);reply['request']=[];self.expect('identity',lambda:self.call('worker','result',reply))
if __name__=='__main__':unittest.main()
