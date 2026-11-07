#!/usr/bin/env bash
# Clone upstream WezTerm at the pinned commit, apply our patches, build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM=https://github.com/wezterm/wezterm.git
PIN=e68a8ec   # upstream commit the patches were made against
DIR="$ROOT/wezterm-src"

if [ ! -d "$DIR/.git" ]; then
  git clone "$UPSTREAM" "$DIR"
fi
git -C "$DIR" checkout -q "$PIN"
git -C "$DIR" submodule update --init --recursive
git -C "$DIR" checkout -q -B rtl-fork
for p in "$ROOT"/patches/*.patch; do
  git -C "$DIR" apply --check "$p" 2>/dev/null && git -C "$DIR" apply "$p" || echo "skip (already applied?): $p"
done
cd "$DIR"
cargo build --release -p wezterm-gui --no-default-features --features wayland,distro-defaults
echo "built: $DIR/target/release/wezterm-gui"
