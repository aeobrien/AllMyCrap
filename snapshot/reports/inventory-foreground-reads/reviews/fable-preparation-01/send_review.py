"""One-shot held source review. No execution until root supplies Astra release."""
import argparse,hashlib,json,math,os,signal,sys
from pathlib import Path
import urllib.request
from understudy.openrouter_judge import make_invoke,NO_SHELL_PREFACE
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sha=lambda b:hashlib.sha256(b).hexdigest()
def ceiling(disclosure,pricing):
 values={k:float(pricing[k]) for k in ('prompt','completion')};values['request']=float(pricing.get('request',0))
 if not all(math.isfinite(v) and v>=0 for v in values.values()):raise ValueError('Invalid pricing')
 total=(disclosure['bytes']+len(NO_SHELL_PREFACE.encode())+4096)*values['prompt']+disclosure['max_tokens']*values['completion']+values['request']
 if not math.isfinite(total) or total>disclosure['budget_usd']:raise ValueError('Conservative single-request cost exceeds budget; no source sent')
 return total

def perform(directory,release,price_provider,invoke_factory,key_loader):
 d=json.loads((directory/'disclosure.json').read_text());raw=(directory/'payload.txt').read_bytes();payload=raw.decode()
 for p,h in d.get('mechanism_hashes',{}).items():
  if sha(Path(p).read_bytes())!=h:raise ValueError('Maintained review mechanism drift')
 if 'user_message_sha256' in d and sha((NO_SHELL_PREFACE+payload).encode())!=d['user_message_sha256']:raise ValueError('Exact provider message drift')
 if len(raw)!=d['bytes'] or sha(raw)!=d['payload_sha256']:raise ValueError('Frozen payload drift')
 if any(sha(Path(p).read_bytes())!=x['sha256'] for p,x in d['files'].items()):raise ValueError('Frozen source drift')
 if release['verdict']!='PASS' or release['payload_sha256']!=d['payload_sha256']:raise ValueError('Missing root-reviewed Astra pass for this payload')
 if sha(Path(release['astra_review_path']).read_bytes())!=release['astra_review_sha256']:raise ValueError('Astra report drift')
 # Exclusive marker is created before even the public price lookup. It survives all failures.
 with (directory/'attempt.json').open('x') as f:json.dump({'phase':'preflight','model':d['model'],'payload_sha256':d['payload_sha256'],'maximum_calls':1,'astra_review_sha256':release['astra_review_sha256']},f,indent=2)
 try:
  pricing=price_provider(d['model']);bound=ceiling(d,pricing);key_loader()
  (directory/'attempt.json').write_text(json.dumps({'phase':'one_request_authorized_by_local_preconditions','model':d['model'],'payload_sha256':d['payload_sha256'],'pricing':pricing,'conservative_maximum_usd':bound,'maximum_calls':1,'reasoning_effort':'low','max_tokens':d['max_tokens']},indent=2)+'\n')
  result=invoke_factory(d['model'],max_tokens=d['max_tokens'],timeout=d['request_timeout_seconds'],retries=1)(payload)
  (directory/'raw-response.json').write_text(result.raw_output+'\n');(directory/'review.md').write_text((result.agent_message or 'INCOMPLETE: no visible review')+'\n')
  receipt={'transport_completed':result.ok,'visible_review':bool(result.agent_message),'model':d['model'],'backend':result.backend,'cost_usd':result.cost_usd,'duration_seconds':result.duration_seconds,'conservative_maximum_usd':bound,'maximum_calls':1,'reasoning_effort':'low','max_tokens':d['max_tokens'],'payload_sha256':d['payload_sha256'],'executed_tests':False,'verdict_requires_reading':True}
  (directory/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');return receipt
 except Exception as e:
  # Never log credentials or request headers; keep failure type and one-shot marker.
  (directory/'failure.json').write_text(json.dumps({'error_type':type(e).__name__,'no_retry':True,'payload_sha256':d['payload_sha256']},indent=2)+'\n');raise

def pricing(model):
 class NoRedirect(urllib.request.HTTPRedirectHandler):
  def redirect_request(self,*args,**kwargs):raise ValueError('Unexpected pricing redirect')
 with urllib.request.build_opener(NoRedirect).open('https://openrouter.ai/api/v1/models',timeout=20) as response:data=json.loads(response.read())
 return next(x['pricing'] for x in data['data'] if x['id']==model)
def key_loader():
 if not os.environ.get('OPENROUTER_API_KEY'):
  sys.path.insert(0,'/Users/aidan/.claude/lib');from openrouter_client import _load_api_key
  os.environ['OPENROUTER_API_KEY']=_load_api_key()
def main():
 p=argparse.ArgumentParser();p.add_argument('--astra-release',required=True);a=p.parse_args();release=json.loads(Path(a.astra_release).read_text())
 def expired(*args):raise TimeoutError('Bounded source review launcher expired')
 signal.signal(signal.SIGALRM,expired);signal.alarm(230)
 try:
  receipt=perform(HERE,release,pricing,make_invoke,key_loader);print(json.dumps(receipt));return 0 if receipt['transport_completed'] and receipt['visible_review'] else 1
 except Exception as e:print(json.dumps({'status':'stopped','error_type':type(e).__name__,'no_retry':True}));return 1
 finally:signal.alarm(0)
if __name__=='__main__':raise SystemExit(main())
