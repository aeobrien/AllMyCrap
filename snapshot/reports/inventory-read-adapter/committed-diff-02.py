from pathlib import Path
import sys
sys.path.insert(0,"/Users/aidan/Dev/Understudy/src")
from understudy import diffjudge,codex
r=diffjudge.judge_diff(Path("/Users/aidan/Dev/AllMyCrap-read-adapter"),"3337ecaeba0c6a0bec733201f190443d21e56b42","5ddf901",run_id="diffjudge-5ddf901e-authorized-review-02",network_allowlist=["openrouter.ai"],invoke_fn=codex.invoke)
print(r.verdict.overall_lane.value)
print(r.verdict.summary)
raise SystemExit(1 if r.verdict.overall_lane.value=="Block" else 0)
