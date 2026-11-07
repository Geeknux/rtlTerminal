#!/usr/bin/env bash
# اجرای ترمینال فورک با نمونه‌ها، اسکرین‌شات از پنجره، و بستن آن.
# استفاده: tests/shot.sh <خروجی.png> [اسکریپت نمونه]
set -euo pipefail
P="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?output png}"
SCRIPT="${2:-$P/tests/bidi-samples.sh}"

kill_test() {
  hyprctl clients -j | python3 -c "
import json,sys,os,signal
for c in json.load(sys.stdin):
    if c['class']=='rtltest': os.kill(c['pid'],signal.SIGTERM)"
}
kill_test || true
sleep 1
(setsid "$P/wezterm-src/target/release/wezterm-gui" --config-file "$P/tests/wezterm-test.lua" \
  start --class rtltest -- bash -c "bash $SCRIPT <<< 'سلام'; sleep 60" >/tmp/rtltest.log 2>&1 &)
sleep 6
G=$(hyprctl clients -j | python3 -c "
import json,sys
for c in json.load(sys.stdin):
    if c['class']=='rtltest': print('%d,%d %dx%d'%(c['at'][0],c['at'][1],c['size'][0],c['size'][1]))")
grim -g "$G" "$OUT"
kill_test || true
