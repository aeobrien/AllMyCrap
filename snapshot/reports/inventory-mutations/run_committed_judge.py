"""Run the installed committed-diff gate without exposing its credential."""
import os
import subprocess
import sys

sys.path.insert(0, '/Users/aidan/.claude/lib')
from openrouter_client import _load_api_key

env = dict(os.environ)
env['OPENROUTER_API_KEY'] = _load_api_key()
raise SystemExit(subprocess.call([
    '/Users/aidan/.pyenv/shims/understudy', 'judge-diff',
    '--base', '875ba89', '--head', 'd657b7aec0587ab4487784d93aedaa296ab6d17e',
    '-C', '/Users/aidan/Dev/AllMyCrap', '--backend', 'openrouter',
    '--allow-net', 'openrouter.ai'], env=env))
