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

## Status

Early. Done: joined shaping for RTL runs, no down-scaling of Arabic-script glyphs, Vazirmatn at scale 1.2 as the recommended Persian fallback font (see `tests/wezterm-test.lua`). Open: cursor placement while editing a line, wrapped RTL lines.

Known: the upstream unit tests (`shapecache.rs`, k9 snapshots in `harfbuzz.rs`) need updating for the new `is_space` / `is_rtl_script` fields before `cargo test` passes.

## License

MIT, same as upstream WezTerm (see `LICENSE.md`).
