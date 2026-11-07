# rtlTerminal

A Linux terminal with RTL / bidi / Persian rendering, built as a patch set on pinned [WezTerm](https://github.com/wezterm/wezterm).

مشابه [RtlTerminal](https://github.com/mirbehnam/RtlTerminal) ویندوز، برای لینوکس.

## Why a WezTerm patch

RTL rendering belongs in the terminal emulator, not in the shell. Logical input, PTY bytes, terminal cell indices and copied text are never reordered.

WezTerm already provides UAX #9 and OpenType shaping. This patch keeps Arabic-script glyphs at their configured size and places RTL glyphs at their natural font advances. **Word spaces are not stretched to consume unused terminal cells.** Each directional/style run still reserves its original cell span; unused width stays at the leading edge of that run. Adjacent LTR runs and terminal column allocations remain on the grid.

## Build

```bash
bash scripts/setup.sh
```

Upstream pin: `e68a8ec27727fbbda15e07f0a0737cd5e16481f6`.
Needs Rust and the usual WezTerm Linux build dependencies (fontconfig, Wayland/X11 libraries and upstream submodules). Setup accepts an exactly applied patch, but fails instead of silently ignoring a conflicted/partially applied patch. It does not reset local edits.

```bash
wezterm-src/target/release/wezterm-gui --config-file tests/wezterm-test.lua
bash tests/paragraph-samples.sh
```

Set `bidi_enabled = true`; upstream defaults to false. The test configuration uses JetBrains Mono with Vazirmatn fallback at scale 1.2. No global font scaling is introduced by the patch.

## Paragraph bidi and display geometry

- Local terminal rendering resolves the **entire retained soft-wrapped paragraph**, including rows outside the viewport. Hard newlines and changes of bidi mode delimit paragraphs. It does not just copy a base-direction hint to each row: embedding levels, bracket pairing, weak types and neutrals are resolved together, then UAX #9 L1/L2 are applied per physical row.
- Resolved runs keep their logical text for HarfBuzz. Style changes split already-resolved runs rather than starting another paragraph.
- Grapheme-to-cell mapping preserves ZWNJ, combining sequences, ligatures and wide cells without counting each codepoint as an extra cell.
- The renderer uses one logical-cell ↔ pixel map for glyph origins, cursor, selection highlighting, mouse selection and hyperlink hit testing. A logical selection can highlight several disjoint visual spans. Ligature cells divide the glyph advance proportionally; font-specific caret tables are not used.
- Shape hashes include paragraph-dependent row runs. An edit in another row can invalidate an unchanged row's layout. Shaping cache keys also distinguish LTR from RTL.
- Rows created by resize/reflow retain bidi flags. Overflow still compresses advances to the available span without down-scaling Arabic glyph bitmaps, and drawing is clipped to the pane boundary.

## Opt-in visual arrows: local Bash / Readline

The shell/application owns the input buffer and cursor. The terminal cannot infer
that buffer from painted output, or move only its painted cursor and still edit
correctly. **There is no global arrow interception in this patch.** Instead, the
supported adapter runs inside Bash's Readline `bind -x` callbacks and updates the
real `READLINE_POINT`; it never rewrites `READLINE_LINE` or reorders input bytes.
Bash exposes this point in **characters**, not Readline's internal byte offsets.

```bash
# setup.sh builds the helper too. For an already-built checkout:
(cd wezterm-src && cargo build --release -p wezterm-surface --example visual-arrow)
RTL_VISUAL_BASH=1 wezterm-src/target/release/wezterm-gui \
  --config-file "$PWD/tests/wezterm-test.lua" start --always-new-process
# Or, inside a terminal already running that exact test config:
bash scripts/visual-bash.sh
```

- Explicitly opted-in, **local Bash 5+**, UTF-8 locale, emacs Readline keymap,
  `AutoLeftToRight`, and the normal renderer are supported (tested on Bash 5.3).
  The launcher uses a separate shell without your `.bashrc` or `.inputrc`; `exit`
  leaves it. Existing shells and their bindings are not modified. Set
  `RTL_VISUAL_ARROWS=0` in this shell for logical arrows again.
- The adapter owns a fixed multiline PS1/PS2 ending in a newline, so each editable
  input region starts at column zero, separate from the prompt's bidi paragraph.
  Both prompt strings are checked before every visual move. Custom inline/color
  prompts are intentionally not guessed. Do not source this adapter into your
  usual interactive startup file.
- The small `visual-arrow` helper uses the **same pinned UBA, grapheme segmenter
  and cell-width implementation** as the terminal: whole-paragraph resolution,
  then line-level reordering at the current `COLUMNS`. Stops are grapheme starts
  plus the logical-end blank, matching block-cursor cell semantics. ZWNJ,
  combining sequences and Arabic ligature cells remain intact. Soft-wrapped
  input and resize are tested. Traversal is screen-row order, left-to-right
  inside each row; crossing an edge visits the adjacent row in that order.
  It is not a dual-affinity insertion-caret/GDEF-caret implementation.
- Only the exact unmodified CSI and SS3 Left/Right sequences are bound, in the
  emacs-standard map. Modified arrows retain native bindings; numeric arguments
  use logical movement. Application-cursor escape encoding is unchanged.
  Launched editors/TUIs, including alternate-screen and non-alternate raw apps,
  receive their original bytes: **Readline callbacks are not running there**.
- Fail-closed logical fallback applies to changed prompts, disabled mode,
  horizontal-scroll mode, non-UTF-8 locale, unavailable/failing helper, control
  characters (including tabs and literal newlines), bidi formatting controls,
  wide/emoji graphemes, invalid positions/width, or input over 64 KiB. This avoids
  guessing when libc/Readline and terminal widths may disagree. Hard multiline
  *buffer contents* fall back; a multiline *prompt* and soft wrapping work.
  Custom redisplay hooks, custom keymaps, remote/tmux sessions, changing bidi
  options at runtime, and arbitrary shell integration are outside this scope.
  No shell-integration escape marker is treated as proof that an arbitrary app
  has a Readline-compatible buffer.

## Tests

```bash
bash tests/check.sh
# Standalone spacing-policy check (no GUI/dependencies beyond rustc):
python3 tests/spacing-repro.py
# Verify patch application against clean files from the upstream pin:
python3 tests/patch-check.py
```

`tests/check.sh` runs bidi (including upstream Unicode conformance), font, GUI, surface and term tests serially, plus the spacing and clean-patch checks. GUI tests shape real Vazirmatn text using an in-memory glyph cache and verify natural advances and logical-cell hit-test round trips. Install Vazirmatn for that font-specific test. Regression cases cover mixed English/Persian, punctuation, digits, ZWNJ/marks, long words, retained offscreen context, hard newlines, repeated resize/reflow and paragraph-dependent cache invalidation. Existing LTR tests remain enabled.

For isolated visual evidence, without touching existing desktop windows:

```bash
bash tests/headless-shot.sh "$PWD/test-results/after"
# Optional second argument selects an older wezterm-gui for comparison.
```

This starts a private headless Weston compositor, runs the sample script, takes a PNG and stops only its own processes. Requires Weston and weston-screenshooter. `tests/shot.sh` remains available for an interactive Hyprland session.

Navigation checks are included in `tests/check.sh`: six helper tests, real
Bash/Readline PTY insertion cases (including RTL, mixed boundaries, ZWNJ/marks,
ligatures, LTR, disabled/fallback modes, modified keys, wrapping and resize),
and byte-preservation checks for child raw/TUI apps with and without the
alternate screen. Fixtures are loaded into Readline, not executed as commands.

```bash
python3 tests/visual-navigation-pty.py
(cd wezterm-src && cargo build --release -p wezterm)
python3 tests/navigation-headless.py
```

The last command exercises the actual opt-in test configuration and launcher in
an isolated GUI, injects keys through its private mux socket, checks actual
Readline contents after insertion, and records screenshots plus logical cursor
positions in `test-results/navigation/headless/results.json`. It also asserts
that the rendered cursor pixels moved left/right as requested, rather than
only checking an isolated reorder map. Requires Python Pillow in addition to
Weston. Logs, PTY transcripts and machine-readable results are under
`test-results/navigation/` (ignored build/test artifacts).

## Limits and tradeoffs

- The allocation grid is unchanged, but RTL ink and the on-screen cursor/selection are proportional **inside a reserved run**. Slack can remain between directional/style runs; this is not a fully proportional terminal or word-aware wrapping engine. Soft wraps still occur at terminal cell boundaries, possibly inside a word.
- Outside the explicitly opted-in Bash adapter above, `Left`/`Right` remain application-controlled and normally logical. A drag selects a logical interval, not an arbitrary visual-order substring. Rectangular selection, application mouse protocols, IME overlays and the optional box-model/experimental pixel-positioning renderer need further interactive testing; the normal renderer with `experimental_pixel_positioning = false` is the supported path here.
- Paragraph context is currently prepared by the local terminal screen. Remote/multiplexed pane implementations that bypass that screen do not yet receive the same paragraph metadata over the wire.
- Only retained scrollback can provide context. Once a paragraph prefix is evicted, its lost embedding state cannot be recovered. Resolution scans complete intersecting retained paragraphs on access, so exceptionally large soft-wrapped paragraphs can cost more CPU; there is no silent 1024-cell truncation in this path.
- Diacritics and font fallback remain font-dependent. Automated geometry tests preserve their cell mapping, but do not prove that every Arabic mark/ligature is typographically perfect; the visual fixture makes such problems visible. Pre-existing compiler deprecation warnings are not addressed by this patch.

## License

MIT, same as upstream WezTerm (see `LICENSE.md`).
