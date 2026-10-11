"""Single explicit source-review transmission; never retries or prints credentials."""
import hashlib,json,sys,time
from pathlib import Path
import requests
sys.path.insert(0,'/Users/aidan/.claude/lib')
from openrouter_client import _load_api_key
root=Path(__file__).resolve().parents[4]
out=Path(__file__).resolve().parent
meta=json.loads((out/'disclosure.json').read_text()); raw=(out/'payload.json').read_bytes()
assert hashlib.sha256(raw).hexdigest()==meta['sha256']
assert all(hashlib.sha256((root/p).read_bytes()).hexdigest()==h for p,h in meta['source_hashes'].items())
assert meta['conservative_token_bound_usd'] < meta['remaining_total_budget_usd']
assert meta['prior_spend_usd']+meta['remaining_total_budget_usd']==meta['budget_usd']==3
pricing_response=requests.get('https://openrouter.ai/api/v1/models',timeout=(10,20),allow_redirects=False)
pricing_response.raise_for_status()
model=next(x for x in pricing_response.json()['data'] if x['id']==meta['model'])
pricing=model['pricing']
bound=(len(raw)+4096)*float(pricing['prompt'])+meta['max_tokens']*float(pricing['completion'])+float(pricing.get('request',0))
assert bound<=meta['budget_usd'], 'fresh price exceeds cap'
(out/'pricing.json').write_text(json.dumps({'model':meta['model'],'pricing':pricing,'conservative_bound_usd':bound},indent=2)+'\n')
key=_load_api_key()
with (out/'attempt.json').open('x') as f: json.dump({'started_at':time.time(),'payload_sha256':meta['sha256'],'single_submission':True,'maximum_budget_usd':3},f)
try:
 response=requests.post(meta['destination'],data=raw,headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'},timeout=(20,220),allow_redirects=False)
except Exception as exc:
 (out/'failure.json').write_text(json.dumps({'exception_class':type(exc).__name__,'outcome':'unknown; no automatic retry'}));raise SystemExit(2)
(out/'response.json').write_text(response.text)
if response.status_code!=200:
 (out/'failure.json').write_text(json.dumps({'http_status':response.status_code}));raise SystemExit(2)
data=response.json();content=data.get('choices',[{}])[0].get('message',{}).get('content') or ''
(out/'review.md').write_text(content+'\n')
(out/'receipt.json').write_text(json.dumps({'model':meta['model'],'payload_sha256':meta['sha256'],'usage':data.get('usage'),'visible_review':bool(content.strip()),'executed_tests':False},indent=2)+'\n')
print(content or 'INCOMPLETE: no visible verdict')
