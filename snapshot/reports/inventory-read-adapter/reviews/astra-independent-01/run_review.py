from pathlib import Path
import dataclasses,hashlib,json,os,sys,time
sys.path.insert(0,"/Users/aidan/Dev/Understudy/src")
from understudy import codex
out=Path(__file__).resolve().parent
root=out.parents[3]
m=json.loads((out/"disclosure.json").read_text())
for rel,h in m["source_hashes"].items():
    assert hashlib.sha256((root/rel).read_bytes()).hexdigest()==h,rel
raw=(out/"prompt.txt").read_bytes()
assert len(raw)==m["prompt_bytes"] and hashlib.sha256(raw).hexdigest()==m["prompt_sha256"]
with (out/"attempt.json").open("x") as f: json.dump({"started_at":time.time(),"model":m["model"],"attempts":1},f)
os.chdir(out)
try:
    r=codex.invoke(raw.decode(),model="gpt-6-astra",timeout_seconds=300)
except Exception as e:
    (out/"failure.json").write_text(json.dumps({"type":type(e).__name__,"error":str(e)}));raise
(out/"raw.jsonl").write_text(r.raw_output)
(out/"review.md").write_text(r.agent_message or "INCOMPLETE: no visible reviewer message.\n")
(out/"receipt.json").write_text(json.dumps({"ok":r.ok,"exit_code":r.exit_code,"model":"gpt-6-astra","duration_seconds":r.duration_seconds,"usage":dataclasses.asdict(r.usage),"executed_tests":False},indent=2)+"\n")
print(json.dumps({"ok":r.ok,"duration_seconds":r.duration_seconds,"visible_review":bool(r.agent_message)}))
sys.exit(0 if r.ok else 1)
