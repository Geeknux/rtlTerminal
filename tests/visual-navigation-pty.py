#!/usr/bin/env python3
"""Real Bash/Readline PTY edits. Never execute the fixture input as shell code."""
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shlex
import signal
import struct
import subprocess
import tempfile
import time
import termios

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results' / 'navigation'
OUT.mkdir(parents=True, exist_ok=True)


def case(name, text, point, arrow, expected, enabled=True, cols=40, setup='', resize=None, edit=b'X'):
    with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as d:
        d = Path(d)
        result = d / 'result'
        rc = d / 'rc'
        # The optional source deliberately lets this test reproduce stock behavior RED.
        integration = ROOT / 'shell' / 'visual-arrows.bash'
        rc.write_text("PS1=$'visual-test\\n'; PS2='> '; set -o emacs\n"
                      + (f"source {integration}\n" if enabled and integration.exists() else '')
                      + setup + '\n'
                      + f'_load() {{ READLINE_LINE={shlex.quote(text)}; READLINE_POINT={point}; }}\n'
                      + "bind -x '\"\\e[15~\": _load'\n"
                      + f'_dump() {{ printf "%s\\n%s\\n" "$READLINE_POINT" "$READLINE_LINE" > {result}; }}\n'
                      + "bind -x '\"\\e[17~\": _dump'\n")
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, cols, 0, 0))
        env = dict(os.environ, TERM='xterm-256color', INPUTRC='/dev/null', LC_ALL='C.UTF-8', _RTL_VISUAL_SESSION='1')
        proc = subprocess.Popen(['bash', '--noprofile', '--rcfile', str(rc), '-i'], stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True)
        os.close(slave)
        transcript = bytearray()
        def drain(seconds=.2):
            deadline = time.monotonic() + seconds
            while time.monotonic() < deadline:
                if select.select([master], [], [], .02)[0]:
                    try:
                        transcript.extend(os.read(master, 65536))
                    except OSError:
                        break
        try:
            drain(.3)
            for index, data in enumerate([b'\x1b[15~', arrow, edit, b'\x1b[17~']):
                if index == 1 and resize:
                    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', 24, resize, 0, 0))
                    proc.send_signal(signal.SIGWINCH)
                    drain(.3)
                os.write(master, data)
                drain()
            got = result.read_text().partition('\n')[2].removesuffix('\n') if result.exists() else '<no Readline result>'
            (OUT / f'{name}.pty').write_bytes(transcript)
            assert got == expected, f'{name}: expected {expected!r}, got {got!r}'
            return dict(name=name, input=text, point=point, arrow=arrow.hex(), edit=edit.hex(), edited=got, cols=cols, resized_cols=resize)
        finally:
            proc.kill()
            proc.wait(timeout=5)
            os.close(master)


def tui_case(alternate):
    """A real child raw-mode application owns input, not the parent's Readline."""
    expected = b'\x1b[D\x1b[C\x1bOD\x1bOC\x1b[1;5D\x1b[1;2C'
    with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as d:
        d = Path(d)
        rc, app, ready, result = (d / n for n in ['rc', 'app.py', 'ready', 'result'])
        rc.write_text(f'source {ROOT}/shell/visual-arrows.bash\n')
        app.write_text('import os,sys,termios,tty\nfrom pathlib import Path\n'
                       'old=termios.tcgetattr(0)\ntty.setraw(0)\n'
                       + ("os.write(1,b'\\x1b[?1049h')\n" if alternate else '')
                       + f'Path({str(ready)!r}).touch()\ndata=b""\n'
                       + f'while len(data)<{len(expected)}: data+=os.read(0,1024)\n'
                       + f'Path({str(result)!r}).write_bytes(data)\n'
                       + ("os.write(1,b'\\x1b[?1049l')\n" if alternate else '')
                       + 'termios.tcsetattr(0,termios.TCSANOW,old)\n')
        master, slave = pty.openpty()
        proc = subprocess.Popen(['bash', '--noprofile', '--rcfile', str(rc), '-i'], stdin=slave, stdout=slave, stderr=slave,
                                env=dict(os.environ, TERM='xterm-256color', INPUTRC='/dev/null', _RTL_VISUAL_SESSION='1'), start_new_session=True)
        os.close(slave)
        try:
            time.sleep(.2)
            os.write(master, f'python3 {app}\n'.encode())
            deadline = time.monotonic() + 5
            while not ready.exists() and time.monotonic() < deadline:
                if select.select([master], [], [], .02)[0]: os.read(master, 65536)
            assert ready.exists(), 'raw app did not start'
            os.write(master, expected)
            while not result.exists() and time.monotonic() < deadline: time.sleep(.02)
            got = result.read_bytes()
            assert got == expected, (got.hex(), expected.hex())
            return dict(name='alternate-screen' if alternate else 'raw-tui', input_hex=got.hex(), unchanged=True)
        finally:
            proc.kill()
            proc.wait(timeout=5)
            os.close(master)


def main():
    results = [
        case('rtl-left', 'سلام', 0, b'\x1b[D', 'سXلام'),
        case('rtl-right', 'سلام', 4, b'\x1b[C', 'سلاXم'),
        case('rtl-delete-after-left', 'سلام', 0, b'\x1b[D', 'لام', edit=b'\x7f'),
        case('mixed-delete-after-right', 'ab اب cd', 3, b'\x1b[C', 'ab ا cd', edit=b'\x7f'),
        case('rtl-app-left', 'سلام', 0, b'\x1bOD', 'سXلام'),
        case('rtl-app-right', 'سلام', 4, b'\x1bOC', 'سلاXم'),
        case('mixed-boundary-right', 'ab اب cd', 3, b'\x1b[C', 'ab ابX cd'),
        case('mixed-boundary-left', 'ab اب cd', 5, b'\x1b[D', 'ab Xاب cd'),
        case('ltr-left', 'abcd', 2, b'\x1b[D', 'aXbcd'),
        case('ltr-right', 'abcd', 2, b'\x1b[C', 'abcXd'),
        case('disabled-unbound', 'سلام', 0, b'\x1b[D', 'Xسلام', enabled=False),
        case('disabled-toggle', 'سلام', 0, b'\x1b[D', 'Xسلام', setup='RTL_VISUAL_ARROWS=0'),
        case('changed-prompt', 'سلام', 0, b'\x1b[D', 'Xسلام', setup="PS1='custom> '"),
        case('horizontal-scroll-fallback', 'سلام', 0, b'\x1b[D', 'Xسلام', setup="bind 'set horizontal-scroll-mode on'"),
        case('missing-helper', 'سلام', 0, b'\x1b[D', 'Xسلام', setup='_RTL_VISUAL_HELPER=/nonexistent'),
        case('zwnj', 'می‌خواهم', 1, b'\x1b[D', 'می‌Xخواهم'),
        case('combining', 'سَلام', 0, b'\x1b[D', 'سَXلام'),
        case('ligature', 'لا', 0, b'\x1b[D', 'لXا'),
        case('wrapped-rtl', 'ابجد هوز ابجد هوز ابجد هوز', 0, b'\x1b[D', 'اXبجد هوز ابجد هوز ابجد هوز', cols=12),
        case('wrapped-ltr', 'abcdefghijklmnop', 12, b'\x1b[D', 'abcdefghijkXlmnop', cols=12),
        case('wrapped-rtl-second-row', 'ابجد هوز ابجد هوز', 12, b'\x1b[D', 'ابجد هوز ابجدX هوز', cols=12),
        case('resize-rtl', 'ابجد هوز ابجد هوز', 11, b'\x1b[D', 'ابجد هوز ابXجد هوز', resize=12),
        case('wide-fallback', 'a界b', 2, b'\x1b[D', 'aX界b'),
        case('combining-inside', 'سَلام', 1, b'\x1b[D', 'سَXلام'),
        case('digits-punctuation', 'اب 12!', 3, b'\x1b[D', 'اب 12X!'),
        case('modified-ctrl-right', 'one two', 0, b'\x1b[1;5C', 'oneX two'),
        case('numeric-argument', 'abcdef', 5, b'\x1b3\x1b[D', 'abXcdef'),
        case('hard-newline-fallback', 'ab\ncd', 4, b'\x1b[D', 'ab\nXcd'),
    ]
    safety = [tui_case(False), tui_case(True)]
    (OUT / 'pty-results.json').write_text(json.dumps(dict(edits=results, safety=safety), ensure_ascii=False, indent=2) + '\n')
    print(f'PASS: {len(results)} real Bash/Readline PTY edits; {len(safety)} raw/TUI byte-preservation checks')


if __name__ == '__main__':
    main()
