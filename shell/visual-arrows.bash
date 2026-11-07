# Sourced only by the isolated, explicitly requested visual Bash session.
# No GUI/terminal key interception: these callbacks exist only while Readline runs.
[[ $- == *i* && ${_RTL_VISUAL_SESSION:-} == 1 && ${BASH_VERSINFO[0]} -ge 5 ]] || return 0
_RTL_VISUAL_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
_RTL_VISUAL_HELPER="$_RTL_VISUAL_ROOT/wezterm-src/target/release/examples/visual-arrow"
_RTL_VISUAL_PROMPT=$'rtlTerminal visual Bash\n'
PS1=$_RTL_VISUAL_PROMPT
PS2=$_RTL_VISUAL_PROMPT
set -o emacs
shopt -s checkwinsize

_rtl_logical_arrow() {
    # Native UTF-8 codepoint fallback, used for unsupported content/prompt/helper.
    local p=$READLINE_POINT n=${#READLINE_LINE} count=${READLINE_ARGUMENT:-1}
    if [[ $1 == left ]]; then
        (( p -= count ))
    else
        (( p += count ))
    fi
    (( p < 0 )) && p=0
    (( p > n )) && p=$n
    READLINE_POINT=$p
}

_rtl_visual_arrow() {
    local target settings
    settings=$(bind -v 2>/dev/null)
    if [[ $PS1 == "$_RTL_VISUAL_PROMPT" && $PS2 == "$_RTL_VISUAL_PROMPT" \
          && $settings == *'set horizontal-scroll-mode off'* \
          && ${READLINE_ARGUMENT:-1} == 1 \
          && ${RTL_VISUAL_ARROWS:-1} == 1 && -x $_RTL_VISUAL_HELPER ]] \
       && [[ $(locale charmap 2>/dev/null) == UTF-8 ]] \
       && target=$(printf %s "$READLINE_LINE" | "$_RTL_VISUAL_HELPER" "$READLINE_POINT" "$1" "${COLUMNS:-80}" 2>/dev/null) \
       && [[ $target =~ ^[0-9]+$ ]]; then
        READLINE_POINT=$target
    else
        _rtl_logical_arrow "$1"
    fi
}

# Only unmodified normal/application cursor arrows, only the emacs Readline map.
# Modified keys, vi mode, and programs launched from this shell remain untouched.
bind -m emacs-standard -x '"\e[D": _rtl_visual_arrow left'
bind -m emacs-standard -x '"\e[C": _rtl_visual_arrow right'
bind -m emacs-standard -x '"\eOD": _rtl_visual_arrow left'
bind -m emacs-standard -x '"\eOC": _rtl_visual_arrow right'
