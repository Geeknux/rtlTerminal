local wezterm = require 'wezterm'
return {
  bidi_enabled = true,
  bidi_direction = 'AutoLeftToRight',
  font_dirs = { wezterm.config_dir .. '/fonts' },
  font = wezterm.font_with_fallback {
    'JetBrains Mono',
    { family = 'Vazirmatn', scale = 1.2 },
  },
  font_size = 13,
  experimental_pixel_positioning = false,
  check_for_updates = false,
  default_prog = { 'powershell.exe', '-NoLogo', '-NoProfile', '-NoExit',
    '-ExecutionPolicy', 'Bypass', '-File', wezterm.config_dir .. '/demo.ps1' },
}
