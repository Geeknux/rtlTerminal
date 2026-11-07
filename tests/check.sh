#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${RTL_TEST_OUT:-$ROOT/test-results}"
mkdir -p "$OUT"
python3 "$ROOT/tests/spacing-repro.py" | tee "$OUT/spacing.log"
python3 "$ROOT/tests/patch-check.py" | tee "$OUT/patch-check.log"
cd "$ROOT/wezterm-src"
cargo test -p wezterm-surface --example visual-arrow 2>&1 | tee "$OUT/navigation-helper-tests.log"
cargo build --release -p wezterm-surface --example visual-arrow 2>&1 | tee "$OUT/navigation-helper-build.log"
python3 "$ROOT/tests/visual-navigation-pty.py" | tee "$OUT/navigation-pty.log"
cargo test -p wezterm-bidi -p wezterm-font -p wezterm-gui -p wezterm-surface -p wezterm-term \
  --no-default-features --features wezterm-gui/wayland,wezterm-gui/distro-defaults \
  -- --test-threads=1 2>&1 | tee "$OUT/all-crates.log"
