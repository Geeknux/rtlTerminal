#!/usr/bin/env python3
"""Compile and exercise the renderer's real spacing policy without a GPU.

The original RED version compiled the pre-fix renderer block and observed
55px added to a space. After refactoring, this executes its shared helper;
the GUI crate also tests actual Vazirmatn glyph advances and hit testing.
"""
from pathlib import Path
import subprocess
import tempfile
import os

root = Path(__file__).resolve().parents[1]
source = (root / 'wezterm-src/wezterm-gui/src/termwindow/render/cell_layout.rs').read_text()
start = source.index('pub(super) fn rtl_run_metrics(')
end = source.index('\n}', start) + 2
policy = source[start:end].replace('pub(super) ', '')
code = policy + '''
fn main() {
 assert_eq!(rtl_run_metrics(120.0, 65.0), (55.0, 1.0));
 assert_eq!(rtl_run_metrics(120.0, 240.0), (0.0, 0.5));
 assert_eq!(rtl_run_metrics(0.0, 0.0), (0.0, 1.0));
 assert_eq!(rtl_run_metrics(120.0, 120.0), (0.0, 1.0));
}
'''
with tempfile.TemporaryDirectory(prefix='rtl-spacing-', dir=os.environ.get('TMPDIR')) as d:
    p = Path(d)
    (p / 'main.rs').write_text(code)
    subprocess.run(['rustc', '--edition=2021', str(p / 'main.rs'), '-o', str(p / 'repro')], check=True)
    subprocess.run([str(p / 'repro')], check=True)
print('PASS: natural advances, leading slack, overflow, empty and exact-fit runs')
