# Native x64 MSVC build. Run from PowerShell 7 with Git, Rust MSVC, VS C++ and Strawberry Perl.
[CmdletBinding()]
param([string]$SourceDir = '', [string]$OutputDir = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$Root = Split-Path $PSScriptRoot -Parent
if (!$SourceDir) { $SourceDir = Join-Path $Root 'wezterm-windows-src' }
if (!$OutputDir) { $OutputDir = Join-Path $Root 'dist-windows' }
$Pin = 'e68a8ec27727fbbda15e07f0a0737cd5e16481f6'
$FontPin = '86aced91de05cd4f96a06838124cca45be337b2b'
$Revision = (git -C $Root rev-parse HEAD).Trim()
# Do not touch the Linux worktree, or reuse an unknown/dirty source directory.
if (Test-Path $SourceDir) { throw "SourceDir already exists; use a new empty path: $SourceDir" }
if (Test-Path $OutputDir) { throw "OutputDir already exists; use a new empty path: $OutputDir" }
git clone --no-checkout https://github.com/wezterm/wezterm.git $SourceDir
git -C $SourceDir checkout --detach $Pin
git -C $SourceDir submodule update --init --recursive
foreach ($Patch in (Get-ChildItem "$Root/patches/*.patch" | Sort-Object Name)) {
    git -C $SourceDir apply --check $Patch.FullName
    git -C $SourceDir apply $Patch.FullName
}
if ((git -C $SourceDir rev-parse HEAD).Trim() -ne $Pin) { throw 'Upstream pin mismatch' }
$VsWhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$Vs = (& $VsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
if (!$Vs) { throw 'Install Visual Studio C++ x64 build tools' }
$DevCmd = Join-Path $Vs 'Common7/Tools/VsDevCmd.bat'
cmd /s /c "`"$DevCmd`" -arch=x64 -host_arch=x64 >nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') }
}
$env:PATH = "C:\Strawberry\perl\bin;$env:PATH"
perl -v
rustup toolchain install stable --profile minimal --target x86_64-pc-windows-msvc
$env:RUSTUP_TOOLCHAIN = 'stable-x86_64-pc-windows-msvc'
$env:CARGO_INCREMENTAL = '0'
# This matches the native upstream workflow, NOT Linux's wayland/distro-defaults flags.
Push-Location $SourceDir
try {
    cargo build --locked --release -p wezterm -p wezterm-gui -p wezterm-mux-server -p strip-ansi-escapes
    cargo test --locked --release -p wezterm-bidi -p wezterm-surface --lib
} finally { Pop-Location }
$Name = 'rtlTerminal-windows-x64-' + $Revision.Substring(0, 12)
$Package = Join-Path $OutputDir $Name
New-Item -ItemType Directory -Force "$Package/mesa", "$Package/fonts", "$Package/licenses" | Out-Null
# Exact upstream ci/deploy.sh Windows portable payload (including debugging symbols).
foreach ($File in @('wezterm.exe','wezterm-gui.exe','wezterm-mux-server.exe','strip-ansi-escapes.exe','wezterm.pdb')) {
    Copy-Item "$SourceDir/target/release/$File" $Package
}
foreach ($File in @('conpty.dll','OpenConsole.exe')) { Copy-Item "$SourceDir/assets/windows/conhost/$File" $Package }
foreach ($File in @('libEGL.dll','libGLESv2.dll')) { Copy-Item "$SourceDir/assets/windows/angle/$File" $Package }
Copy-Item "$SourceDir/assets/windows/mesa/opengl32.dll" "$Package/mesa/"
Copy-Item "$SourceDir/assets/fonts/JetBrainsMono-Regular.ttf" "$Package/fonts/"
Copy-Item "$SourceDir/assets/fonts/LICENSE_OFL.txt" "$Package/licenses/upstream-fonts-OFL.txt"
Copy-Item "$SourceDir/assets/fonts/LICENSE_POWERLINE_EXTRA.txt" "$Package/licenses/"
Copy-Item "$SourceDir/LICENSE.md" "$Package/licenses/WezTerm-MIT.md"
Copy-Item "$SourceDir/licenses/*" "$Package/licenses/"
Copy-Item "$SourceDir/assets/windows/conhost/README.md" "$Package/licenses/Microsoft-console-provenance.md"
Copy-Item "$SourceDir/assets/windows/mesa/README.md" "$Package/licenses/Mesa-provenance.md"
Invoke-WebRequest "https://raw.githubusercontent.com/google/fonts/$FontPin/ofl/vazirmatn/Vazirmatn%5Bwght%5D.ttf" -OutFile "$Package/fonts/Vazirmatn.ttf"
Invoke-WebRequest "https://raw.githubusercontent.com/google/fonts/$FontPin/ofl/vazirmatn/OFL.txt" -OutFile "$Package/licenses/Vazirmatn-OFL.txt"
Invoke-WebRequest 'https://raw.githubusercontent.com/microsoft/terminal/v1.22.10352.0/LICENSE' -OutFile "$Package/licenses/Microsoft-terminal-MIT.txt"
Invoke-WebRequest 'https://docs.mesa3d.org/license.html' -OutFile "$Package/licenses/Mesa-license.html"
Copy-Item "$Root/windows/*" $Package
# Windows PowerShell 5.1 interprets BOM-less UTF-8 as the legacy ANSI codepage.
[IO.File]::WriteAllText("$Package/demo.ps1", [IO.File]::ReadAllText("$Root/windows/demo.ps1"), [Text.UTF8Encoding]::new($true))
@{ rtlTerminal_commit=$Revision; upstream_commit=$Pin; font_commit=$FontPin; rustc=(rustc -V); gui_tested=$false } | ConvertTo-Json | Set-Content "$Package/build-info.json" -Encoding utf8
# Check x64 PE headers and resolve ordinary import tables for every bundled binary.
$Report = [System.Collections.Generic.List[string]]::new()
foreach ($Binary in (Get-ChildItem $Package -Recurse -File | Where-Object Extension -in '.exe','.dll')) {
    $Bytes = [IO.File]::ReadAllBytes($Binary.FullName)
    $Pe = [BitConverter]::ToInt32($Bytes, 60)
    if ([BitConverter]::ToUInt32($Bytes, $Pe) -ne 0x4550 -or [BitConverter]::ToUInt16($Bytes, $Pe+4) -ne 0x8664) { throw "Not x64 PE: $Binary" }
    $Imports = (& dumpbin /nologo /dependents $Binary.FullName) -join "`n"
    $Report.Add("=== $($Binary.Name) ===`n$Imports")
    foreach ($Match in [regex]::Matches($Imports, '(?im)^\s+([a-z0-9_.-]+\.dll)\s*$')) {
        $Dll = $Match.Groups[1].Value
        if ($Dll -match '^(api-ms-|ext-ms-)') { continue }
        if ((Test-Path "$Package/$Dll") -or (Test-Path "$($Binary.DirectoryName)/$Dll")) { continue }
        # The project links its CRT statically. Bundled upstream support DLLs may need the VC redistributable.
        if ($Dll -match '^(msvcp|vcruntime|concrt)') {
            $Runtime = Get-ChildItem "$Vs/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT/$Dll" | Select-Object -Last 1
            if (!$Runtime) { throw "Missing redistributable $Dll" }
            Copy-Item $Runtime.FullName "$Package/$Dll"
        } elseif (!(Test-Path "$env:SystemRoot/System32/$Dll")) { throw "Unresolved runtime dependency $Dll for $Binary" }
    }
}
$Report | Set-Content "$Package/runtime-dependencies.txt"
# Smoke native execution and config/font loading without creating a GUI or modifying user config.
foreach ($Exe in @('wezterm.exe','wezterm-gui.exe','wezterm-mux-server.exe')) {
    & "$Package/$Exe" --version
    if ($LASTEXITCODE -ne 0) { throw "$Exe --version failed: $LASTEXITCODE" }
}
& "$Package/wezterm.exe" --config-file "$Package/rtl-test.lua" ls-fonts | Set-Content "$Package/font-smoke.txt"
if ($LASTEXITCODE -ne 0) { throw 'Portable Lua config/font smoke failed' }
$Manifest = Get-ChildItem $Package -Recurse -File | Sort-Object FullName | ForEach-Object {
    @{ path=$_.FullName.Substring($Package.Length+1).Replace('\','/'); bytes=$_.Length; sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower() }
}
$Manifest | ConvertTo-Json -Depth 3 | Set-Content "$Package/manifest.json"
Compress-Archive -Path $Package -DestinationPath "$OutputDir/$Name.zip" -CompressionLevel Optimal
Get-FileHash "$OutputDir/$Name.zip" -Algorithm SHA256 | Format-List
Write-Output "Portable test ZIP: $OutputDir/$Name.zip"
