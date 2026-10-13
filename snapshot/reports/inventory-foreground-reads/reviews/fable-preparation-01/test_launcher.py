"""No external calls: fake price/invoke exercise cost guard and one-shot behavior."""
import importlib.util,json,tempfile,unittest,hashlib
from pathlib import Path
from types import SimpleNamespace
spec=importlib.util.spec_from_file_location('held_review',Path(__file__).with_name('send_review.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class LauncherTests(unittest.TestCase):
 def setup_package(self,root):
  payload=b'Synthetic source';(root/'payload.txt').write_bytes(payload);review=root/'astra.md';review.write_text('PASS synthetic independent test fixture')
  d={'bytes':len(payload),'payload_sha256':hashlib.sha256(payload).hexdigest(),'model':'fixture/not-real','files':{},'max_tokens':12000,'budget_usd':3,'request_timeout_seconds':180};(root/'disclosure.json').write_text(json.dumps(d))
  return {'verdict':'PASS','payload_sha256':d['payload_sha256'],'astra_review_path':str(review),'astra_review_sha256':hashlib.sha256(review.read_bytes()).hexdigest()}
 def test_only_one_call_with_output_allowance_and_no_retries(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);release=self.setup_package(root);calls=[]
   def factory(model,**kwargs):
    self.assertEqual(kwargs,dict(max_tokens=12000,timeout=180,retries=1))
    def invoke(payload):calls.append(payload);return SimpleNamespace(ok=True,agent_message='PASS synthetic only',raw_output='{}',backend='fixture',cost_usd=.01,duration_seconds=.01)
    return invoke
   receipt=m.perform(root,release,lambda _:dict(prompt='0.000001',completion='0.000001'),factory,lambda:None);self.assertTrue(receipt['visible_review']);self.assertEqual(len(calls),1)
   with self.assertRaises(FileExistsError):m.perform(root,release,lambda _:self.fail('No repeat price lookup'),factory,lambda:None)
 def test_budget_fails_before_key_or_source_send_and_retains_marker(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);release=self.setup_package(root)
   with self.assertRaises(ValueError):m.perform(root,release,lambda _:dict(prompt='1',completion='1'),lambda *a,**k:self.fail('No send'),lambda:self.fail('No key load'))
   self.assertTrue((root/'attempt.json').exists());self.assertTrue((root/'failure.json').exists())
 def test_requires_astra_pass_and_unchanged_report(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);release=self.setup_package(root);release['verdict']='BLOCK'
   with self.assertRaises(ValueError):m.perform(root,release,lambda _:self.fail('No network'),None,None)
   self.assertFalse((root/'attempt.json').exists())
 def test_transport_mechanism_drift_stops_before_network(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);release=self.setup_package(root);mechanism=root/'mechanism.py';mechanism.write_text('synthetic version')
   d=json.loads((root/'disclosure.json').read_text());d['mechanism_hashes']={str(mechanism):'wrong'};(root/'disclosure.json').write_text(json.dumps(d))
   with self.assertRaises(ValueError):m.perform(root,release,lambda _:self.fail('No network'),None,None)
   self.assertFalse((root/'attempt.json').exists())
 def test_invalid_or_missing_prices_are_rejected(self):
  d={'bytes':100,'max_tokens':12000,'budget_usd':3}
  for prices in ({'prompt':'nan','completion':'1'},{'prompt':'-1','completion':'0'},{'prompt':'0'}):
   with self.assertRaises((KeyError,ValueError)):m.ceiling(d,prices)
 def test_maintained_backend_uses_low_reasoning_and_rejects_truncation(self):
  calls=[]
  def transport(model,messages,max_tokens,**kwargs):
   calls.append(model);self.assertEqual(max_tokens,12000);self.assertEqual(kwargs['extra'],{'reasoning':{'effort':'low'}})
   return 'PASS visible review',.01,{'prompt_tokens':10,'completion_tokens':20},{'choices':[{'finish_reason':'stop'}]}
  result=m.make_invoke('fixture/model',max_tokens=12000,retries=1,chat=transport)('Synthetic only');self.assertTrue(result.ok);self.assertEqual(len(calls),1)
  def truncated(*args,**kwargs):return 'partial',.01,{}, {'choices':[{'finish_reason':'length'}]}
  with self.assertRaises(Exception):m.make_invoke('fixture/model',max_tokens=12000,retries=1,chat=truncated)('Synthetic only')
if __name__=='__main__':unittest.main()
