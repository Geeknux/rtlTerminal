#!/usr/bin/env bash
# Clone upstream WezTerm at the pinned commit, apply our patches, build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM=https://github.com/wezterm/wezterm.git
PIN=e68a8ec27727fbbda15e07f0a0737cd5e16481f6
DIR="$ROOT/wezterm-src"

if [ ! -d "$DIR/.git" ]; then
  git clone "$UPSTREAM" "$DIR"
fi
git -C "$DIR" checkout -q "$PIN"
git -C "$DIR" submodule update --init --recursive
git -C "$DIR" checkout -q -B rtl-fork
for p in "$ROOT"/patches/*.patch; do
  if git -C "$DIR" apply --check "$p"; then
    git -C "$DIR" apply "$p"
  elif git -C "$DIR" apply --reverse --check "$p" 2>/dev/null; then
    echo "already applied: $p"
  else
    echo "patch does not apply cleanly: $p (refusing to skip a conflicting patch)" >&2
    exit 1
  fi
done
cd "$DIR"
cargo build --release -p wezterm-gui --no-default-features --features wayland,distro-defaults
cargo build --release -p wezterm-surface --example visual-arrow
echo "built: $DIR/target/release/wezterm-gui and target/release/examples/visual-arrow"
