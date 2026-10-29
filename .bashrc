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
# 0 	Black
# 1 	Red
# 2 	Green
# 3 	Yellow
# 4 	Blue
# 5 	Magenta
# 6 	Cyan
# 7 	White
PROMPT_COLOR=6

__pl_git() {
  __pl_branch=""
  local out line head="" oid="" dirty=""
  out=$(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null) || return
  while IFS= read -r line; do
    case $line in
    "# branch.head "*) head=${line#"# branch.head "} ;;
    "# branch.oid "*) oid=${line#"# branch.oid "} ;;
    "# "*) ;;
    *) dirty="*" ;;
    esac
  done <<<"$out"
  [[ $head == "(detached)" ]] && head=${oid:0:7}
  __pl_branch="${head}${dirty}"
}

__fzf_accent() {
  [[ ${PROMPT_COLOR-} =~ ^([0-9]|1[0-5])$ ]] || return
  FZF_ACCENT=$PROMPT_COLOR
  export FZF_ACCENT
  FZF_DEFAULT_OPTS="${__FZF_BASE_OPTS:+$__FZF_BASE_OPTS }--color=bg+:${FZF_ACCENT}"
  export FZF_DEFAULT_OPTS
}

__set_custom_prompt() {
  local EXIT_STATUS=$?

  # Цвета (\[ \] обязательны, чтобы bash правильно считал длину строки)
  local c="" r="" b="" sep="" ok="" err="" dim="" gitc=""
  if [[ ${PROMPT_COLOR-} =~ ^([0-9]|1[0-5])$ ]]; then
    c="\[\e[$((PROMPT_COLOR < 8 ? 30 + PROMPT_COLOR : 82 + PROMPT_COLOR))m\]"
  fi
  r="\[\e[0m\]"
  b="\[\e[1m\]"      # жирный
  dim="\[\e[90m\]"   # серый для разделителей
  gitc="\[\e[35m\]"  # magenta для git
  ok="\[\e[1;32m\]"  # жирный зелёный
  err="\[\e[1;31m\]" # жирный красный

  # Короткий путь (последние 3 каталога)
  local d=${PWD/#"$HOME"/\~}
  local t=${d//[^\/]/}
  ((${#t} > 3)) && d=".../${d#"${d%/*/*/*}/"}"
  __pl_dir=$d

  __pl_git

  # Статус: зелёный OK / красный ERR
  if ((EXIT_STATUS == 0)); then
    __pl_stat="${ok}[OK]"
  else
    __pl_stat="${err}[ERR ${EXIT_STATUS}]"
  fi

  local sep=" ${dim}>${r} "

  # user@host > путь > git ветка > [статус]$
  local ps="${b}${c}"'\u@\h'"${r}${sep}${b}"'${__pl_dir}'"${r}"
  [[ -n $__pl_branch ]] && ps+="${sep}${gitc}"'git ${__pl_branch}'"${r}"
  ps+="${sep}${__pl_stat}"'\$'"${r} "

  local TITLE=""
  case "$TERM" in
  xterm* | rxvt*)
    TITLE="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]"
    ;;
  esac

  PS1="${TITLE}${ps}"
}

__prompt_command() {
  __set_custom_prompt
  __fzf_accent
}
PROMPT_COMMAND=__prompt_command
# ==================

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
  "$HOME/dwm/dwm/scripts/command-run.sh" "$@"
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
