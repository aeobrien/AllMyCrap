"""Build actual read adapter with unchanged models; use only a temporary store."""
import hashlib,json,os,platform,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
names=['Location.swift','Item.swift','Tag.swift','ReviewHistory.swift','DuplicateExclusion.swift']
if (root/'AllMyCrap/InventoryReadAdapter.swift').exists():names.append('InventoryReadAdapter.swift')
with tempfile.TemporaryDirectory(prefix='inventory-reader-') as td:
 path=Path(td);files=[];hashes={}
 for name in names:
  raw=(root/'AllMyCrap'/name).read_bytes();hashes[name]=hashlib.sha256(raw).hexdigest();target=path/name;target.write_bytes(raw);files.append(str(target))
 harness=path/'ReadTests.swift';harness.write_bytes(Path(__file__).with_suffix('.swift').read_bytes());binary=path/'read-tests'
 command=['xcrun','swiftc','-swift-version','5','-target',platform.machine()+'-apple-macos14.0','-module-cache-path',str(path/'cache'),*files,str(harness),'-o',str(binary)]
 result=subprocess.run(command,capture_output=True,text=True,timeout=90)
 if result.returncode:print(result.stdout[-30000:]);print(result.stderr[-30000:]);raise SystemExit(result.returncode)
 result=subprocess.run([str(binary)],env=dict(os.environ,INVENTORY_READ_STORE=str(path/'fixture.store')),capture_output=True,text=True,timeout=45)
 if result.returncode:print(result.stdout[-30000:]);print(result.stderr[-30000:]);raise SystemExit(result.returncode)
 markers=[s.removeprefix('READ_RESULT=') for s in result.stdout.splitlines() if s.startswith('READ_RESULT=')];assert len(markers)==1
 report=json.loads(markers[0]);assert report['passed']>=10;report['source_sha256']=hashes;report['scope']='isolated actual SwiftData models and read adapter; no app/default store/backup/network';print(json.dumps(report,sort_keys=True))
