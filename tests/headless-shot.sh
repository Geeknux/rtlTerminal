#!/usr/bin/env bash
# Isolated Weston headless session: no access to existing terminals/windows.
# Usage: tests/headless-shot.sh /absolute/output-dir [wezterm-gui binary]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?absolute output directory}"
BIN="${2:-$ROOT/wezterm-src/target/release/wezterm-gui}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
RUNTIME="$(mktemp -d "${TMPDIR:?}/rtl-weston.XXXXXX")"
chmod 700 "$RUNTIME"
cleanup() {
  if [[ -n "${APP_PID:-}" ]]; then kill "$APP_PID" 2>/dev/null || true; wait "$APP_PID" 2>/dev/null || true; fi
  if [[ -n "${WESTON_PID:-}" ]]; then kill "$WESTON_PID" 2>/dev/null || true; wait "$WESTON_PID" 2>/dev/null || true; fi
  rm -rf "$RUNTIME"
}
trap cleanup EXIT
export XDG_RUNTIME_DIR="$RUNTIME" WAYLAND_DISPLAY=rtl-headless
unset DISPLAY WEZTERM_UNIX_SOCKET WEZTERM_PANE
weston --backend=headless --renderer=pixman --width=1200 --height=800 \
  --socket="$WAYLAND_DISPLAY" --no-config --idle-time=0 --debug \
  --log="$OUT/weston.log" >"$OUT/weston-stdio.log" 2>&1 &
WESTON_PID=$!
for _ in {1..100}; do [[ -S "$RUNTIME/$WAYLAND_DISPLAY" ]] && break; sleep 0.1; done
[[ -S "$RUNTIME/$WAYLAND_DISPLAY" ]]
"$BIN" --config-file "$ROOT/tests/wezterm-test.lua" \
  --config enable_tab_bar=false --config initial_cols=90 --config initial_rows=22 \
  start --always-new-process --class rtl-headless-test -- bash -c \
  'sleep 1; printf "\033[2J\033[H"; bash "$1"; sleep 20' bash "$ROOT/tests/paragraph-samples.sh" \
  >"$OUT/gui.log" 2>&1 &
APP_PID=$!
sleep 5
kill -0 "$APP_PID"
(cd "$OUT" && XDG_PICTURES_DIR="$OUT" weston-screenshooter --verbose) >"$OUT/screenshooter.log" 2>&1
shopt -s nullglob
SHOTS=("$OUT"/wayland-screenshot-*.png)
[[ ${#SHOTS[@]} -gt 0 ]] || { echo 'capture produced no PNG in output directory' >&2; exit 1; }
printf 'screenshots in %s\n' "$OUT"
