import hashlib,json,os,platform,subprocess,tempfile
from pathlib import Path
repo=Path(__file__).resolve().parents[2]
source=repo/'AllMyCrap'
names=['Location.swift','Item.swift','Tag.swift','ReviewHistory.swift','DuplicateExclusion.swift','InventoryMutations.swift']
print(json.dumps({'source_sha256':{n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in names}}),flush=True)
with tempfile.TemporaryDirectory(prefix='inventory-astra-') as d:
    p=Path(d)
    subprocess.run(['xcrun','swiftc','-swift-version','5','-target',platform.machine()+'-apple-macos14.0','-module-cache-path',str(p/'cache'),*[str(source/n) for n in names],str(Path(__file__).with_suffix('.swift')),'-o',str(p/'checks')],check=True,timeout=90)
    subprocess.run([str(p/'checks')],env=dict(os.environ,INVENTORY_AUDIT_STORE=str(p/'fixture.store')),check=True,timeout=30)
