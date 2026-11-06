from pathlib import Path
import sys
sys.path.insert(0,"/Users/aidan/Dev/Understudy/src")
from understudy import diffjudge,codex
annotation="""
Factual trace clarification to verify against supplied committed source (not a requested verdict): reports/inventory-read-adapter/reviews/astra-independent-01/run_review.py imports understudy.codex then calls codex.invoke. It has no requests call or literal HTTP host; it uses the maintained native Codex backend. No internal Codex host is asserted or added to the allowlist. reports/inventory-read-adapter/reviews/fable-01/send_once.py directly calls requests.get public OpenRouter model pricing and requests.post the disclosure destination https://openrouter.ai/api/v1/chat/completions. The declared openrouter.ai allowance covers those actual Fable HTTP calls only. Trace these separately and cite accurately. Both are review tooling, not runtime adapter networking. Leave every rubric requirement and verdict rule unchanged; return a verification gap/block if source cannot substantiate a required claim, never invent a host or grant permission.
"""
def invoke(prompt,**kwargs):
    return codex.invoke(prompt+annotation,**kwargs)
r=diffjudge.judge_diff(Path("/Users/aidan/Dev/AllMyCrap-read-adapter"),"3337ecaeba0c6a0bec733201f190443d21e56b42","5ddf901",run_id="diffjudge-5ddf901e-factual-trace-03",network_allowlist=["openrouter.ai"],invoke_fn=invoke)
print(r.verdict.overall_lane.value)
print(r.verdict.summary)
raise SystemExit(1 if r.verdict.overall_lane.value=="Block" else 0)
