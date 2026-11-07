-- اجرا: wezterm --config-file ~/Projects/rtlTerminal/tests/wezterm-test.lua
-- سپس: bash ~/Projects/rtlTerminal/tests/bidi-samples.sh
local wezterm = require 'wezterm'

return {
  bidi_enabled = true,
  -- LeftToRight | RightToLeft | AutoLeftToRight | AutoRightToLeft
  bidi_direction = 'AutoLeftToRight',

  font = wezterm.font_with_fallback {
    'JetBrains Mono',
    'Noto Naskh Arabic',
  },
  font_size = 13,

  -- آزمایش ۱: با true هم امتحان کنید و تفاوت را گزارش دهید
  experimental_pixel_positioning = false,

  -- آزمایش ۲: لیگچر/کشیده‌شدن حروف را خاموش نکنید؛ اگر حروف تکراری عجیب
  -- دیدید این را امتحان کنید:
  -- harfbuzz_features = { 'calt=0', 'liga=0' },
}
