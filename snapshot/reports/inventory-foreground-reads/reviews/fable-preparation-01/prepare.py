"""Offline package creation only. Never imports a provider client or loads credentials."""
import ast,hashlib,json,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
R=ROOT/'reports/inventory-foreground-reads'
manifest=json.loads((R/'candidate-hashes-02.json').read_text())
context=json.loads((R/'unchanged-reader-models.json').read_text())
assert len(manifest)==18 and len(context)==6
for path,expected in (manifest|context).items():assert sha((ROOT/path).read_bytes())==expected,path
baseline='57d255ce04a0ac0734753dc80ff0e6f0540467c0'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==baseline
prompt='''Review the actual candidate02 automatic foreground inventory-read implementation below independently for concrete blocking defects. You have only these inlined sources, plan and reported receipts; you cannot execute tests, open files or inspect a live app. Cite supplied file:line locations for each finding. Do not claim execution or adopt the author's conclusions.

The approved deliverable is a LOCAL automatic foreground prototype: synthetic session client -> authenticated disposable loopback mailbox -> actual URLSession Swift worker -> app-owned retained reader/explicit context -> request-bound reply. The app target must register and compose the reader and worker correctly, but remains unconfigured until future production pairing is implemented. The unchanged reader/model sources are context, not new schema/mutation work. Physical iOS runtime, production hosting/deployment/pairing, real possessions, backup reads, session discovery and mutations are explicitly outside this slice. Do not block just because an excluded future feature is absent.

Review the entire included implementation, in particular:
1. App source membership, same-container injection, main-actor/store ownership, retained reader and paging, lifecycle cancellation/owner release, late-response scope binding.
2. Typed read operations, canonical request/digest agreement across languages, exact identity/auth roles, unsupported keys/operations, errors versus empty results, pending edits/no read mutations.
3. Actual URLSession and Python HTTP clients: target/redirect/proxy behavior, body and time bounds, authentication disclosure, request/reply binding, cancellation and retry semantics.
4. Mailbox finite capacity/retention, incomplete request lines/headers and trickling bodies, handler-slot recovery, deadline timer lifetime and shutdown; examine the actual new deadline code and tests rather than assuming the repair works.
5. Evidence quality: real success path versus mocks, scope of the compiled Swift fixtures versus actual unsigned app build, actual remaining unproved delivery. Results shown are local receipts, not something you executed.

Return a concise PASS or BLOCK for the stated source scope, followed by any blocking findings with severity, exact file:line citations, trigger, user-visible effect and smallest correction. Separate optional improvements from blockers. Do not require gold-plating or invent environmental facts. A source-review PASS does not assert deployment, user acceptance, test execution by you or completion of the original build gates.
'''
(HERE/'review-prompt.txt').write_text(prompt)
parts=[prompt];files={}
ordered=['docs/BUILD-INVENTORY-FOREGROUND-READS.md','docs/INVENTORY-FOREGROUND-READS.md',*[p for p in manifest if not p.startswith('docs/')],*context]
for name in ordered:
 path=ROOT/name;raw=path.read_bytes();lines=raw.decode().splitlines()
 if name=='AllMyCrap.xcodeproj/project.pbxproj':
  representation=subprocess.check_output(['git','diff','--no-ext-diff','--unified=10',baseline,'--',name],cwd=ROOT,text=True)
  parts.append('\n## '+name+' — exact baseline-to-candidate project-registration diff\n'+representation+'\n')
  files[str(path)]={'bytes':len(raw),'sha256':sha(raw),'included_ranges':[],'representation':'Exact git diff against baseline '+baseline+', 10 context lines; unrelated target/build settings omitted.'}
 else:
  parts.append('\n## '+name+'\n'+''.join(f'{n}: {line}\n' for n,line in enumerate(lines,1)))
  files[str(path)]={'bytes':len(raw),'sha256':sha(raw),'included_ranges':[[1,len(lines)]],'representation':'Complete source, line-numbered.'}
# Include original app diff so same-store composition can be checked against actual prior code.
parts.append('\n## Original app composition delta\n'+subprocess.check_output(['git','diff','--no-ext-diff','--unified=8',baseline,'--','AllMyCrap/AllMyCrapApp.swift'],cwd=ROOT,text=True)+'\n')
receipts={}
for run in ['http-budget-red-01','http-budget-green-01','roundtrip-08','protocol-05','ios-build-02']:
 path=R/run/'cli-run-result.json';value=json.loads(path.read_text())
 receipts[run]={k:value[k] for k in ['ok','exit_code','timed_out','duration_s']}
 files[str(path)]={'bytes':len(path.read_bytes()),'sha256':sha(path.read_bytes()),'included_ranges':[],'representation':'Projection only: ok, exit_code, timed_out, duration_s; no logs or raw response bodies.'}
parts.append('\n## Actual local Understudy receipt fields (author-supplied evidence, not reviewer execution)\n'+json.dumps(receipts,indent=2)+'\nGreen Python17 cases; roundtrip25 assertions; protocol30 assertions; unsigned generic iOS Simulator target compiled, no app/simulator launch. Native and app inputs unchanged by candidate02 HTTP-only repair. Original failing deadline tests preserved.\n')
payload=''.join(parts).encode();(HERE/'payload.txt').write_bytes(payload)
backend=Path('/Users/aidan/Dev/Understudy/src/understudy/openrouter_judge.py')
module=ast.parse(backend.read_text())
preface=next(ast.literal_eval(n.value) for n in module.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='NO_SHELL_PREFACE' for t in n.targets))
message=(preface+payload.decode()).encode()
model='anthropic/claude-fable-5.1'
body=json.dumps({'model':model,'messages':[{'role':'user','content':message.decode()}],'max_tokens':12000,'temperature':0.0,'usage':{'include':True},'reasoning':{'effort':'low'}}).encode()
# This is the exact prospective POST JSON body, with no authorization header/key.
(HERE/'request-body-preview.json').write_bytes(body)
disclosure={'candidate':'candidate02','model':model,'destination':'https://openrouter.ai/api/v1/chat/completions','bytes':len(payload),'payload_sha256':sha(payload),'preface_bytes':len(preface.encode()),'user_message_bytes':len(message),'user_message_sha256':sha(message),'request_body_bytes':len(body),'request_body_sha256':sha(body),'budget_usd':3,'max_tokens':12000,'reasoning_effort':'low','maximum_calls':1,'retries':0,'request_timeout_seconds':180,'total_launcher_bound_seconds':230,'baseline':baseline,'files':files,'frozen_candidate_inputs':manifest,'unchanged_reader_models':context,'candidate_manifest_sha256':sha((R/'candidate-hashes-02.json').read_bytes()),'scope':'Private application source, project-registration diff, exact read adapter/model context, full approved plan and synthetic tests; local paths and source metadata are present. No real inventory, backups, credentials, private records or data bodies. Bearer values in tests are synthetic fixtures only.','transport':'Maintained Understudy.openrouter_judge.make_invoke retries=1, prepends NO_SHELL_PREFACE; aijudge performs one OpenRouter POST with low reasoning and 12000 output tokens.','budget_note':'Conservative preflight at then-reported public model rates: source bytes plus preface plus4096 allowance as input tokens, maximum output and request fee; refuses if estimate exceeds$3. This is a local preflight bound, not a provider-side hard billing cap.','held':True,'reason':'Local preparation only. Root controls independent Astra release and normal source-transfer approval; no key loading, price lookup, network or launch performed.'}
(HERE/'disclosure.json').write_text(json.dumps(disclosure,indent=2)+'\n')
mechanism={str(p):sha(p.read_bytes()) for p in [backend,backend.with_name('aijudge.py')]}
disclosure['mechanism_hashes']=mechanism
(HERE/'disclosure.json').write_text(json.dumps(disclosure,indent=2)+'\n')
(HERE/'mechanism-hashes.json').write_text(json.dumps(mechanism,indent=2)+'\n')
print(json.dumps({k:disclosure[k] for k in ['bytes','payload_sha256','user_message_bytes','user_message_sha256','request_body_bytes','request_body_sha256','candidate_manifest_sha256']},indent=2))
