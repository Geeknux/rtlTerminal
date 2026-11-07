#!/usr/bin/env python3
"""Isolated real GUI + Bash/Readline PTY; CLI injection, screenshots and edit proof.

No desktop, user config or existing mux socket is used. Weston headless only.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results' / 'navigation' / 'headless'
OUT.mkdir(parents=True, exist_ok=True)
BIN = ROOT / 'wezterm-src' / 'target' / 'release'


def main():
    with tempfile.TemporaryDirectory(prefix='rtl-navigation-', dir=os.environ['TMPDIR']) as d:
        d = Path(d)
        runtime = d / 'runtime'
        runtime.mkdir(mode=0o700)
        rc, result = d / 'rc', d / 'edited'
        rc.write_text(f'source {ROOT}/shell/visual-arrows.bash\n'
                      "_rtl_fixture() { READLINE_LINE='سلام'; READLINE_POINT=0; }\n"
                      "_mixed_fixture() { READLINE_LINE='ab اب cd'; READLINE_POINT=3; }\n"
                      "_wrap_fixture() { READLINE_LINE='ابجد هوز ابجد هوز ابجد هوز ابجد هوز ابجد هوز ابجد هوز'; READLINE_POINT=0; }\n"
                      + f'_dump_fixture() {{ printf "%s\\n%s\\n" "$READLINE_POINT" "$READLINE_LINE" > {result}; }}\n'
                      + "bind -x '\"\\e[15~\": _rtl_fixture'\n"
                      + "bind -x '\"\\e[18~\": _mixed_fixture'\n"
                      + "bind -x '\"\\e[19~\": _wrap_fixture'\n"
                      + "bind -x '\"\\e[17~\": _dump_fixture'\n")
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), WAYLAND_DISPLAY='rtl-navigation',
                   XDG_PICTURES_DIR=str(OUT), RTL_VISUAL_BASH='1', INPUTRC='/dev/null', LC_ALL='C.UTF-8')
        for key in ['DISPLAY', 'WEZTERM_UNIX_SOCKET', 'WEZTERM_PANE']:
            env.pop(key, None)
        weston_log = (OUT / 'weston-stdio.log').open('w')
        gui_log = (OUT / 'gui.log').open('w')
        weston = subprocess.Popen(['weston', '--backend=headless', '--renderer=pixman', '--width=1200', '--height=800',
                                   '--socket=rtl-navigation', '--no-config', '--idle-time=0', '--debug', f'--log={OUT}/weston.log'],
                                  env=env, stdout=weston_log, stderr=subprocess.STDOUT)
        gui = None
        try:
            for _ in range(100):
                if (runtime / 'rtl-navigation').exists(): break
                time.sleep(.1)
            assert (runtime / 'rtl-navigation').exists()
            gui = subprocess.Popen([str(BIN / 'wezterm-gui'), '--config-file', str(ROOT / 'tests/wezterm-test.lua'),
                                    '--config', 'enable_tab_bar=false', '--config', 'initial_cols=40', '--config', 'initial_rows=18',
                                    '--config', 'cursor_blink_rate=0', 'start', '--always-new-process', '--class', 'rtl-navigation'], env=env, stdout=gui_log, stderr=subprocess.STDOUT)
            cli = [str(BIN / 'wezterm'), '--config-file', str(ROOT / 'tests/wezterm-test.lua'), 'cli', '--no-auto-start', '--class', 'rtl-navigation']
            pane = None
            for _ in range(100):
                sockets = list((runtime / 'wezterm').glob('gui-sock-*'))
                if sockets:
                    assert len(sockets) == 1
                    env['WEZTERM_UNIX_SOCKET'] = str(sockets[0])
                listed = subprocess.run(cli + ['list', '--format', 'json'], env=env, capture_output=True)
                if listed.returncode == 0:
                    panes = json.loads(listed.stdout)
                    if panes:
                        pane = str(panes[0]['pane_id'])
                        break
                time.sleep(.1)
            (OUT / 'cli-discovery.log').write_bytes(listed.stdout + listed.stderr)
            (OUT / 'runtime-files.json').write_text(json.dumps([str(p.relative_to(runtime)) for p in runtime.rglob('*')]))
            assert pane is not None, 'isolated GUI pane not found'
            time.sleep(1)
            records = []
            cursor_boxes = {}
            def send(data):
                subprocess.run(cli + ['send-text', '--pane-id', pane, '--no-paste'], input=data, env=env, check=True, capture_output=True)
                time.sleep(.4)
            def capture(label):
                before = set(OUT.glob('wayland-screenshot-*.png'))
                subprocess.run(['weston-screenshooter'], cwd=OUT, env=env, check=True, capture_output=True)
                new = set(OUT.glob('wayland-screenshot-*.png')) - before
                assert len(new) == 1, new
                shot = OUT / f'{label}.png'
                shutil.move(str(new.pop()), shot)
                screen = subprocess.check_output(cli + ['get-text', '--pane-id', pane], env=env)
                (OUT / f'{label}.txt').write_bytes(screen)
                state = json.loads(subprocess.check_output(cli + ['list', '--format', 'json'], env=env))
                image = Image.open(shot).convert('RGB')
                pixels = image.tobytes()
                green = [(i % image.width, i // image.width) for i, (r, g, b) in enumerate(zip(pixels[::3], pixels[1::3], pixels[2::3]))
                         if g > 80 and g > r * 1.3 and g > b * 1.3]
                assert green, f'no rendered cursor in {shot}'
                box = [min(x for x, y in green), min(y for x, y in green), max(x for x, y in green), max(y for x, y in green)]
                cursor_boxes[label] = box
                records.append(dict(stage=label, screenshot=str(shot.relative_to(ROOT)), cursor_pixel_box=box, panes=state))
            send(f'[[ $_RTL_VISUAL_SESSION == 1 ]] && source {rc}\n'.encode())
            send(b'\x0c')
            send(b'\x1b[15~')
            capture('rtl-before')
            send(b'\x1b[D')
            capture('rtl-after-left')
            send(b'X\x1b[17~')
            capture('rtl-edited')
            edited = result.read_text().partition('\n')[2].removesuffix('\n')
            assert edited == 'سXلام', edited
            records.append(dict(case='rtl', edited=edited, verified=True))
            send(b'\x1b[18~')
            capture('mixed-before')
            send(b'\x1b[C')
            capture('mixed-after-right')
            send(b'X\x1b[17~')
            capture('mixed-edited')
            edited = result.read_text().partition('\n')[2].removesuffix('\n')
            assert edited == 'ab ابX cd', edited
            records.append(dict(case='mixed-boundary', edited=edited, verified=True))
            send(b'\x1b[19~')
            capture('wrapped-before')
            send(b'\x1b[D')
            capture('wrapped-after-left')
            send(b'X\x1b[17~')
            edited = result.read_text().partition('\n')[2].removesuffix('\n')
            assert edited == 'اXبجد هوز ابجد هوز ابجد هوز ابجد هوز ابجد هوز ابجد هوز', edited
            capture('wrapped-edited')
            records.append(dict(case='wrapped', edited=edited, verified=True))
            for before, after, right in [('rtl-before', 'rtl-after-left', False),
                                         ('mixed-before', 'mixed-after-right', True),
                                         ('wrapped-before', 'wrapped-after-left', False)]:
                a, b = cursor_boxes[before], cursor_boxes[after]
                assert a[1] == b[1] and ((b[0] > a[0]) if right else (b[0] < a[0])), (before, a, after, b)
            (OUT / 'results.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
            print('PASS: real GUI/Bash PTY, 3 verified edits, 9 headless screenshots')
        finally:
            if gui:
                gui.terminate()
                try: gui.wait(timeout=5)
                except subprocess.TimeoutExpired: gui.kill(); gui.wait()
            weston.terminate()
            weston.wait(timeout=5)
            weston_log.close()
            gui_log.close()


if __name__ == '__main__':
    main()
