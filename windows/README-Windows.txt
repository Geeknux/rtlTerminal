rtlTerminal - unsigned Windows x64 portable rendering TEST build

1. Extract the entire ZIP to a writable folder (not inside the ZIP viewer).
2. Double-click Start-rtlTerminal.cmd. No compiler or installation is needed.
3. Read the Persian/mixed-direction samples. Resize the window, select/copy text,
   and try Persian typing. Report your Windows version, screenshot and build-info.json.
4. Close the window to stop. Delete the folder to uninstall.

The launcher passes rtl-test.lua explicitly and starts a separate process.
It does not overwrite ~/.wezterm.lua, register fonts, or change shell profiles.
PowerShell uses -NoProfile. ExecutionPolicy Bypass applies only to this demo process.
Bundled JetBrains Mono and Vazirmatn fonts are loaded from fonts/ (licenses included).
Windows 10 x64 build 17763+ / Windows 11. This build is not code-signed: inspect
its provenance before allowing a SmartScreen warning; do not disable system security.

Scope: native Windows compilation, unit tests, PE/import inspection, --version
and Lua/font loading are checked on the build runner. Interactive Windows GUI,
GPU rendering, IME, copy/paste, and cursor geometry still need YOUR visual test.
Visual arrow editing is a separate opt-in Bash/Readline experiment, NOT a
PowerShell/PSReadLine feature. No visual-arrow interception is enabled here.

Source and reproducible build: https://github.com/Geeknux/rtlTerminal
See docs/windows-build.md. Upstream pin and source revision: build-info.json.
The portable payload follows pinned upstream ci/deploy.sh, with test config,
fonts, license notices, dependency report, and a per-file SHA256 manifest added.
