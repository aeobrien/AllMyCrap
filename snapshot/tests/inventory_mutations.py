"""Compile the original five SwiftData models and test only a temporary store."""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1] / 'AllMyCrap'
names = ['Location.swift', 'Item.swift', 'Tag.swift', 'ReviewHistory.swift', 'DuplicateExclusion.swift']
if (source/'InventoryMutations.swift').exists(): names.append('InventoryMutations.swift')
hashes = {n: hashlib.sha256((source/n).read_bytes()).hexdigest() for n in names}
with tempfile.TemporaryDirectory(prefix='possessions-session-audit-') as tmp:
    root = Path(tmp)
    files = []
    for name in names:
        target = root/name
        target.write_bytes((source/name).read_bytes())
        files.append(str(target))
    harness = root/'Audit.swift'
    harness.write_bytes(Path(__file__).with_suffix('.swift').read_bytes())
    binary = root/'audit'
    compile_result = subprocess.run([
        'xcrun', 'swiftc', '-swift-version', '5', '-target', platform.machine()+'-apple-macos14.0',
        '-module-cache-path', str(root/'cache'), *files, str(harness), '-o', str(binary)
    ], capture_output=True, text=True, timeout=90)
    if compile_result.returncode:
        print(compile_result.stderr)
        raise SystemExit(compile_result.returncode)
    run = subprocess.run([str(binary)], env=dict(os.environ, INVENTORY_AUDIT_STORE=str(root/'fixture.store')),
                         capture_output=True, text=True, timeout=30)
    if run.returncode:
        print(run.stdout)
        print(run.stderr)
        raise SystemExit(run.returncode)
    markers = [line.removeprefix('AUDIT_RESULT=') for line in run.stdout.splitlines() if line.startswith('AUDIT_RESULT=')]
    assert len(markers) == 1
    result = json.loads(markers[0])
    result['source_sha256'] = hashes
    result['scope'] = 'Unmodified SwiftData models, temporary disk store, CloudKit disabled; no app, backup manager, UI, phone or real records accessed'
    print(json.dumps(result, sort_keys=True))
