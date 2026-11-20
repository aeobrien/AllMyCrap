"""Bounded synthetic protocol/owner compiler proof; never boot the app."""
import pathlib,subprocess,tempfile,os,platform,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES=['InventoryReadProtocol.swift','InventorySessionReads.swift','InventoryMailboxTransport.swift','InventoryForegroundReadWorker.swift']
def registration():
 text=(ROOT/'AllMyCrap.xcodeproj/project.pbxproj').read_text()
 for name in ['InventoryReadAdapter.swift',*FILES]:
  assert text.count('/* '+name+' in Sources */')==2, 'Missing/duplicate app target registration: '+name
if __name__=='__main__':
 registration()
 with tempfile.TemporaryDirectory(prefix='inventory-protocol-') as td:
  p=pathlib.Path(td);names=['Location.swift','Item.swift','Tag.swift','ReviewHistory.swift','DuplicateExclusion.swift','InventoryReadAdapter.swift',*FILES]
  cmd=['xcrun','swiftc','-swift-version','5','-target',platform.machine()+'-apple-macos14.0','-module-cache-path',str(p/'cache'),*[str(ROOT/'AllMyCrap'/n) for n in names],str(ROOT/'tests/inventory_session_protocol.swift'),'-o',str(p/'tests')]
  subprocess.run(cmd,check=True,timeout=100)
  subprocess.run([str(p/'tests')],env=dict(os.environ,INVENTORY_FIXTURE_ROOT=td),check=True,timeout=25)
