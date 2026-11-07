# rtlTerminal

A Linux terminal with proper RTL / bidi / Persian rendering, built as a small patch set on top of [WezTerm](https://github.com/wezterm/wezterm).

مشابه [RtlTerminal](https://github.com/mirbehnam/RtlTerminal) ویندوز، برای لینوکس.

## Why a WezTerm patch

RTL rendering is the terminal emulator's job, not the shell's. WezTerm already implements bidi (UAX #9) and OpenType shaping, but it places every shaped glyph into a fixed-width cell slot. Arabic-script letters have different advances, so cursive joining breaks and letters appear isolated with gaps.

The patch places glyphs of RTL runs using their real advances, while the run still occupies exactly the same number of cells (so cursor, selection and column alignment are unchanged). Spare room is spread over the spaces between words so letters stay joined.

## Build

```bash
scripts/setup.sh     # clones WezTerm at the pinned commit, applies patches/, builds
```

Needs the usual WezTerm Linux build dependencies (Rust, fontconfig, Wayland/X11 libs).

## Try it

```bash
wezterm-src/target/release/wezterm-gui --config-file tests/wezterm-test.lua
bash tests/bidi-samples.sh
```

`bidi_enabled = true` must be set in the config (it is off by default in WezTerm).

## What the patch changes

- **Glyph placement** (`screen_line.rs`): RTL runs use real glyph advances, right-justified in their cell span; spare room goes to the spaces, overflow is compressed so nothing is clipped.
- **No down-scaling** of Arabic-script glyphs (`glyphcache.rs`, `is_rtl_script` flag from the shaper).
- **Resize/rewrap lost bidi** (`term/src/screen.rs`, `wezterm-surface/src/line/line.rs`): rows added or re-wrapped when the window is resized did not inherit the bidi settings, so they were rendered as plain LTR text with each word separate. They now inherit them (upstream `FIXME: borrow bidi mode from line`).

## Status

Working: joined shaping, correct word order (also on wrapped rows), ZWNJ and diacritics, mixed LTR/RTL, numbers, cursor navigation. Unit tests of the touched crates pass.

Open: word-spacing could be tighter (a font with Arabic glyphs closer to the cell width would help), RTL runs and wrapped paragraphs are still reordered row by row (implicit mode), and `Left`/`Right` follow logical order as in any terminal.

## License

MIT, same as upstream WezTerm (see `LICENSE.md`).
