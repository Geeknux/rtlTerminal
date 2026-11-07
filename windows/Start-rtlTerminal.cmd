@echo off
setlocal
cd /d "%~dp0"
"%~dp0wezterm-gui.exe" --config-file "%~dp0rtl-test.lua" start --always-new-process
if errorlevel 1 pause
