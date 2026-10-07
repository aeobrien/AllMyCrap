"""Submit only the fixed, hash-checked source review package."""
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, '/Users/aidan/.claude/lib')
from openrouter_client import OpenRouterClient

base = Path(__file__).resolve().parent
package = json.loads((base / 'fable-package.json').read_text())
payload = (base / 'fable-payload.txt').read_text()
assert hashlib.sha256(payload.encode()).hexdigest() == package['sha256']
out = base / 'fable-02'
out.mkdir(exist_ok=False)
r = OpenRouterClient(logs_dir=out / 'raw', budget_usd=2.30).call(
    model='anthropic/claude-fable-5.1',
    system='Independently review all supplied source for blocking faults within stated scope. Return a concise final PASS or BLOCK verdict, file and line citations for actual blockers, and separate optional suggestions. Limit visible response to 500 words; do not spend the answer narrating each check. Finish the complete review.',
    user=payload, max_tokens=16000, reasoning={'effort': 'low'}, temperature=0,
    read_timeout_s=180)
(out / 'review.md').write_text(r.response_text + '\n')
(out / 'receipt.json').write_text(json.dumps({**package, 'sent': True,
    'attempt_budget_usd': 2.30, 'prior_attempt_cost_usd': 0.67989, 'executed_tests': False, 'visible_review': bool(r.response_text.strip())}, indent=2))
print(r.response_text or 'INCOMPLETE: no visible review')
