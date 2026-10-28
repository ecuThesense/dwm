# ~/.bashrc

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# Load Noctalia terminal colors
# [[ -f ~/.cache/terminal-sequences ]] && cat ~/.cache/terminal-sequences

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

# set variable identifying the chroot you work in
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# ==================
# CUSTOM BASH PROMPT
# ==================
__gnome_accent_rgb() {
  local name
  name=$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null)
  case "${name//\'/}" in
  teal) echo "33 144 164" ;;
  green) echo "58 148 74" ;;
  yellow) echo "200 136 0" ;;
  orange) echo "237 91 0" ;;
  red) echo "230 45 66" ;;
  pink) echo "213 97 153" ;;
  purple) echo "145 65 172" ;;
  slate) echo "111 131 150" ;;
  *) echo "53 132 228" ;;
  esac
}

__pl_rgb_to_hex() {
  local r g b
  IFS=';' read -r r g b <<<"$1"
  printf '#%02x%02x%02x' "$r" "$g" "$b"
}

__pl_update_palette() {
  local r g b
  read -r r g b <<<"$(__gnome_accent_rgb)"

  # Darker shades: 40%, 60%, 80% of the accent RGB
  local c1r=$((r * 40 / 100))
  local c1g=$((g * 40 / 100))
  local c1b=$((b * 40 / 100))

  local c2r=$((r * 60 / 100))
  local c2g=$((g * 60 / 100))
  local c2b=$((b * 60 / 100))

  local c3r=$((r * 80 / 100))
  local c3g=$((g * 80 / 100))
  local c3b=$((b * 80 / 100))

  # Main accent
  __PL_C4="${r};${g};${b}"

  # Lighter shades: blend the accent with white
  local c5r=$((r + (255 - r) * 40 / 100))
  local c5g=$((g + (255 - g) * 40 / 100))
  local c5b=$((b + (255 - b) * 40 / 100))

  local c6r=$((r + (255 - r) * 55 / 100))
  local c6g=$((g + (255 - g) * 55 / 100))
  local c6b=$((b + (255 - b) * 55 / 100))

  __PL_C1="${c1r};${c1g};${c1b}"
  __PL_C2="${c2r};${c2g};${c2b}"
  __PL_C3="${c3r};${c3g};${c3b}"
  __PL_C5="${c5r};${c5g};${c5b}"
  __PL_C6="${c6r};${c6g};${c6b}"

  # Keep the Git status foreground in sync with the lightest shade
  __PL_FG_C6="38;2;${__PL_C6}"

  # Change only fzf's selected-row background
  # local accent
  # accent=$(__pl_rgb_to_hex "$__PL_C4")
  #
  # FZF_DEFAULT_OPTS="${__FZF_BASE_OPTS:+$__FZF_BASE_OPTS }--color=bg+:${accent}"
  # export FZF_DEFAULT_OPTS

  # Export the current GNOME accent for custom scripts
  FZF_ACCENT=$(__pl_rgb_to_hex "$__PL_C4")
  export FZF_ACCENT

  FZF_DEFAULT_OPTS="${__FZF_BASE_OPTS:+$__FZF_BASE_OPTS }--color=bg+:${FZF_ACCENT}"
  export FZF_DEFAULT_OPTS
}

# __apply_accent() {
#     [[ -t 1 ]] || return
#     local r g b
#     read -r r g b <<< "$(__gnome_accent_rgb)"
#     local lr=$(( r + (255 - r) * 35 / 100 ))
#     local lg=$(( g + (255 - g) * 35 / 100 ))
#     local lb=$(( b + (255 - b) * 35 / 100 ))
#     printf '\e]4;4;rgb:%02x/%02x/%02x\a'  "$r" "$g" "$b"      # slot 4  = accent
#     printf '\e]4;12;rgb:%02x/%02x/%02x\a' "$lr" "$lg" "$lb"   # slot 12 = lighter accent
#     printf '\e]12;rgb:%02x/%02x/%02x\a'   "$r" "$g" "$b"      # cursor
# }

__apply_accent() {
  [[ -t 1 ]] || return
  local r g b
  read -r r g b <<<"$(__gnome_accent_rgb)"
  local lr=$((r + (255 - r) * 35 / 100))
  local lg=$((g + (255 - g) * 35 / 100))
  local lb=$((b + (255 - b) * 35 / 100))

  local s
  for s in 4 6; do # normal slots  -> accent
    printf '\e]4;%d;rgb:%02x/%02x/%02x\a' "$s" "$r" "$g" "$b"
  done
  for s in 12 14; do # bright slots  -> lighter accent
    printf '\e]4;%d;rgb:%02x/%02x/%02x\a' "$s" "$lr" "$lg" "$lb"
  done
  printf '\e]12;rgb:%02x/%02x/%02x\a' "$r" "$g" "$b" # cursor
}

# ------------------------------------------------------------------------------
# Starship-style "accent" powerline prompt (needs a Nerd Font in the terminal)
#   user > dir > git branch/status > docker > time > duration + status
# Segments without content (git, docker, duration) are skipped and the
# separators re-chain automatically. Requires bash 5+ (EPOCHREALTIME).
# ------------------------------------------------------------------------------

# Palette c1..c6 as "r;g;b"
__PL_C1="13;57;65"    # #0d3941
__PL_C2="19;86;98"    # #135662
__PL_C3="26;115;131"  # #1a7383
__PL_C4="33;144;164"  # #2190a4
__PL_C5="121;188;200" # #79bcc8
__PL_C6="155;205;214" # #9bcdd6

# Text colors (SGR parameters)
__PL_FG_DEF="39"
__PL_FG_WHITE="38;2;255;255;255"
__PL_FG_BLACK="38;2;0;0;0"
__PL_FG_C6="38;2;${__PL_C6}"

# Powerline shapes + Nerd Font icons (change the codepoints if you prefer others)
# (written as raw UTF-8 bytes so they work in any locale and never collide with
#  PS1's own \u escape)
# Powerline separators and Nerd Font icons
__PL_CAP_L=''
__PL_SEP=''

__PL_I_USER=''
__PL_I_DIR=''
__PL_I_BRANCH=''
__PL_I_DOCKER=''
__PL_I_TIME=''

__PL_I_OK=''
__PL_I_ERR=''

# Append one segment to __ps.  usage: __pl_add "<bg r;g;b>" "<fg SGR>" "<text>"
# Text may contain prompt escapes (\u, \A) and ${var} references, which bash
# expands when the prompt is drawn (safe for branch names etc.).
__pl_add() {
  local bg=$1 fg=$2 text=$3
  if [[ -z $__pl_prev ]]; then
    __ps+="\[\e[0m\e[38;2;${bg}m\]${__PL_CAP_L}"
  elif [[ $__pl_prev != "$bg" ]]; then
    __ps+="\[\e[38;2;${__pl_prev}m\e[48;2;${bg}m\]${__PL_SEP}"
  fi
  __ps+="\[\e[48;2;${bg}m\e[${fg}m\]${text}"
  __pl_prev=$bg
}

# Command duration: remember the start time of every command.
__pl_preexec() {
  [[ -n ${COMP_LINE-} ]] && return
  [[ -z ${__pl_start-} ]] && __pl_start=${EPOCHREALTIME//[.,]/}
}
trap '__pl_preexec' DEBUG

# Git branch + status in one call -> __pl_branch, __pl_gst
__pl_git() {
  __pl_branch=""
  __pl_gst=""
  local out line head="" oid="" a b _
  local ahead=0 behind=0 staged=0 modified=0 untracked=0 conflicted=0
  out=$(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null) || return
  while IFS= read -r line; do
    case $line in
    "# branch.head "*) head=${line#"# branch.head "} ;;
    "# branch.oid "*) oid=${line#"# branch.oid "} ;;
    "# branch.ab "*)
      read -r _ _ a b <<<"$line"
      ahead=${a#+}
      behind=${b#-}
      ;;
    "1 "* | "2 "*)
      [[ ${line:2:1} != . ]] && ((staged++))
      [[ ${line:3:1} != . ]] && ((modified++))
      ;;
    "u "*) ((conflicted++)) ;;
    "? "*) ((untracked++)) ;;
    esac
  done <<<"$out"

  [[ $head == "(detached)" ]] && head=${oid:0:7}
  __pl_branch=$head

  local s=""
  ((conflicted)) && s+="="
  ((staged)) && s+="+"
  ((modified)) && s+="!"
  ((untracked)) && s+="?"
  if ((ahead && behind)); then
    s+="⇕"
  elif ((ahead)); then
    s+="⇡"
  elif ((behind)); then
    s+="⇣"
  fi
  __pl_gst=$s
}

__set_custom_prompt() {
  local EXIT_STATUS=$? # must stay the first line

  __pl_update_palette

  # --- command duration ---
  local ms=0
  if [[ -n ${__pl_start-} ]]; then
    ms=$(((${EPOCHREALTIME//[.,]/} - __pl_start) / 1000))
  fi
  unset __pl_start
  __pl_dur=""
  if ((ms >= 500)); then
    if ((ms < 1000)); then
      __pl_dur="${ms}ms"
    else
      local sec=$((ms / 1000)) h m
      h=$((sec / 3600))
      m=$((sec % 3600 / 60))
      sec=$((sec % 60))
      ((h)) && __pl_dur+="${h}h"
      ((m)) && __pl_dur+="${m}m"
      ((sec)) && __pl_dur+="${sec}s"
    fi
  fi

  # --- directory (~ for $HOME, keep the last 3 components) ---
  local d=${PWD/#"$HOME"/\~}
  local t=${d//[^\/]/}
  ((${#t} > 3)) && d="…/${d#"${d%/*/*/*}/"}"
  __pl_dir=$d

  # --- git ---
  __pl_git

  # --- docker context (only next to a Dockerfile / compose file) ---
  __pl_dock=""
  if [[ -f Dockerfile || -f docker-compose.yml || -f docker-compose.yaml || -f compose.yml || -f compose.yaml ]]; then
    local ctx=${DOCKER_CONTEXT-}
    if [[ -z $ctx && -r ~/.docker/config.json ]]; then
      ctx=$(sed -n 's/.*"currentContext"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' ~/.docker/config.json)
    fi
    [[ -n $ctx && $ctx != default ]] && __pl_dock=$ctx
  fi

  # --- exit status ---
  if ((EXIT_STATUS == 0)); then
    __pl_stat=$__PL_I_OK
  else
    __pl_stat="${__PL_I_ERR} ${EXIT_STATUS}"
  fi

  # --- assemble ---
  __ps=""
  __pl_prev=""

  __pl_add "$__PL_C1" "$__PL_FG_DEF" " ${__PL_I_USER} "'\u '
  __pl_add "$__PL_C2" "$__PL_FG_DEF" " ${__PL_I_DIR} "'${__pl_dir} '

  if [[ -n $__pl_branch ]]; then
    __pl_add "$__PL_C3" "$__PL_FG_WHITE" " ${__PL_I_BRANCH} "'${__pl_branch} '
    [[ -n $__pl_gst ]] && __pl_add "$__PL_C3" "$__PL_FG_C6" '${__pl_gst} '
  fi

  [[ -n $__pl_dock ]] && __pl_add "$__PL_C4" "$__PL_FG_DEF" " ${__PL_I_DOCKER} "'${__pl_dock} '

  __pl_add "$__PL_C5" "$__PL_FG_BLACK" " ${__PL_I_TIME} "'\A '

  [[ -n $__pl_dur ]] && __pl_add "$__PL_C6" "$__PL_FG_BLACK" ' took: ${__pl_dur} '
  __pl_add "$__PL_C6" "$__PL_FG_BLACK" ' ${__pl_stat} '

  # closing cap
  __ps+="\[\e[0m\e[38;2;${__pl_prev}m\]${__PL_SEP}\[\e[0m\] "

  local TITLE=""
  case "$TERM" in
  xterm* | rxvt*)
    TITLE="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]"
    ;;
  esac

  PS1="${TITLE}${__ps}"
}

# One single entry point: the DEBUG trap above must not fire for a second
# command inside PROMPT_COMMAND, or the duration timer would restart too early.
__prompt_command() {
  __set_custom_prompt
  __apply_accent
}
PROMPT_COMMAND=__prompt_command

# ==============================================================================

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
fi

# Your custom aliases
alias update='doas apt update && doas apt upgrade -y && doas apt full-upgrade -y && doas apt autoremove -y'
alias ll='ls -lha --color=auto'
alias ls='ls --color=auto'
alias bin-check='cd ~/.local/bin/'
alias app-picker='~/SourceApps/gnome/app-picker.sh'
alias file-picker='~/SourceApps/gnome/file-picker.sh'
alias wttr='curl wttr.in/Berlin'

alias git-push-all='git add . && git commit -m "fix" && git push'

# bin-import() {
#   find "$(realpath "${1:-.}")" -maxdepth 1 -type f -executable -exec sh -c 'for f; do n=${f##*/}; ln -sfnv "$f" ~/.local/bin/"${n%.[A-Za-z]*}"; done' _ {} +
# }

bin-import() {
  find "$(realpath "${1:-.}")" -maxdepth 1 -type f -executable -exec sh -c '
    for f; do
      n=${f##*/}
      mv -fv "$f" ~/.local/bin/"${n%.[A-Za-z]*}"
    done
  ' _ {} +
}

cmc() {
  "$HOME/SourceApps/gnome/command-run.sh" "$@"
}

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Byobu prompt integration
[ -r ~/.byobu/prompt ] && . ~/.byobu/prompt

# Your custom Auto-run ls when changing directories
cd() {
  builtin cd "$@" && ls -a --color=auto
}

# Preserve existing fzf options before adding dynamic colors
if [[ ! ${__FZF_BASE_OPTS+x} ]]; then
  __FZF_BASE_OPTS=${FZF_DEFAULT_OPTS-}
fi

export EDITOR=nvim
export VISUAL=nvim
export NNN_OPENER=nvim
# ~/SourceApps/starship-accent
# eval "$(starship init bash)"
