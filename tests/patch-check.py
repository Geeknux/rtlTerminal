#!/usr/bin/env python3
"""Apply the patchset to clean upstream files and compare every result.

No worktree reset, branch switch, git staging, submodule update or network
operation is performed. Fresh files live only in TMPDIR.
"""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
repo = root / 'wezterm-src'
pin = 'e68a8ec27727fbbda15e07f0a0737cd5e16481f6'
patches = sorted((root / 'patches').glob('*.patch'))
paths = sorted({line[6:] for patch in patches for line in patch.read_text().splitlines()
                if line.startswith('+++ b/')})
assert paths and patches, 'empty patchset'
with tempfile.TemporaryDirectory(prefix='rtl-clean-patch-', dir=os.environ.get('TMPDIR')) as d:
    clean = Path(d)
    for path in paths:
        original = subprocess.run(['git', '-C', str(repo), 'show', f'{pin}:{path}'], capture_output=True)
        target = clean / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if original.returncode == 0:
            target.write_bytes(original.stdout)
        else:
            assert not subprocess.check_output(['git', '-C', str(repo), 'ls-tree', pin, '--', path]), path
    for patch in patches:
        subprocess.run(['git', 'apply', '--check', str(patch)], cwd=clean, check=True)
        subprocess.run(['git', 'apply', str(patch)], cwd=clean, check=True)
        subprocess.run(['git', 'apply', '--reverse', '--check', str(patch)], cwd=clean, check=True)
    for path in paths:
        assert (clean / path).read_bytes() == (repo / path).read_bytes(), f'patch/source mismatch: {path}'
print(f'PASS: {len(patches)} patch(es), {len(paths)} files; clean pin -> exact working source; reverse check passed')
