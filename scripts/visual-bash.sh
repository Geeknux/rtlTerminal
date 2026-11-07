#!/usr/bin/env bash
# Explicit opt-in, no user's bashrc/inputrc or bindings are changed.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
HELPER="$ROOT/wezterm-src/target/release/examples/visual-arrow"
[[ -x $HELPER ]] || { printf 'Build first: cd %q/wezterm-src && cargo build --release -p wezterm-surface --example visual-arrow\n' "$ROOT" >&2; exit 1; }
[[ $(locale charmap 2>/dev/null) == UTF-8 ]] || { printf 'Visual Bash requires a UTF-8 locale.\n' >&2; exit 1; }
(( BASH_VERSINFO[0] >= 5 )) || { printf 'Visual Bash requires Bash 5 or later.\n' >&2; exit 1; }
export _RTL_VISUAL_SESSION=1
export INPUTRC=/dev/null
exec bash --noprofile --rcfile "$ROOT/shell/visual-arrows.bash" -i
