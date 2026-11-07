# Windows x64 portable rendering test

Download the `rtlTerminal-windows-x64` artifact from the manually dispatched
**Windows portable test build** Actions run. Extract the artifact wrapper, then
extract its `rtlTerminal-windows-x64-<commit>.zip`. Run `Start-rtlTerminal.cmd`.
No Rust, Perl or compiler is required on the test machine. The package includes
an explicit isolated config, Persian PowerShell samples and OFL-licensed fonts.
Visual Bash arrows are **not** supported or enabled in PowerShell.

## Reproduce locally

Use PowerShell 7, Git, the Rust MSVC toolchain, Visual Studio C++ x64 build tools
(with Windows SDK), and Strawberry Perl installed at `C:\Strawberry`.
From a checkout of this repository, run:

```powershell
pwsh -NoProfile -File .\scripts\build-windows.ps1
```

The script requires new `wezterm-windows-src` and `dist-windows` directories;
it refuses to reuse existing paths and does not touch the Linux `wezterm-src`.
Use `-SourceDir` and `-OutputDir` to choose other fresh paths for a retry.
Builds require Internet access and substantial disk space and may take an hour.
The exact upstream commit remains the one in `scripts/setup.sh`.

References at that pin: `.github/workflows/gen_windows.yml` for native default
Cargo features/MSVC/Strawberry Perl, `.cargo/config.toml` for static CRT, and
`ci/deploy.sh` Windows case for the binary/DLL/mesa/PDB package manifest.
The script runs targeted bidi/surface release unit tests, validates x64 PE
headers/import resolution, executes three native `--version` commands and loads
the portable config/fonts via `ls-fonts`. It adds JSON build provenance and a
file SHA256 manifest. Interactive Windows GUI/GPU/IME testing is not claimed.

Official source-build reference: https://wezterm.org/install/source.html
Official Windows install reference: https://wezterm.org/install/windows.html
