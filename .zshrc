#!/bin/zsh

# ZSH configuration

# History                                                              {{{1
# format of command execution timestamp in history output
HIST_STAMPS="yyyy-mm-dd"

# Modules                                                              {{{1
# zpty used by vim plugin zchee/deoplete-zsh
zmodload zsh/files zsh/zutil zsh/zpty

# Plugins                                                              {{{1
plugins=(
    adb             \
    chucknorris     \
    fasd            \
    git             \
    colored-man     \
    colorize        \
    cpanm           \
    debian          \
    dircycle        \
    github          \
    npm             \
    perl            \
    ruby            \
    rvm             \
    themes          \
    tmux            \
    tmuxinator      \
    vi-mode         \
    vim-interaction \
)

# Completion                                                           {{{1
autoload -U +X compinit && compinit -u
# use bash completion scripts
# (but they don't work in babun/cygwin)
if [ "${OSTYPE}" != 'cygwin' ] ; then
    autoload -U +X bashcompinit && bashcompinit
    if [ -f /etc/bash_completion ] ; then
        source /etc/bash_completion 2>/dev/null
    fi
    if [ -d /etc/bash_completion.d ] ; then
        for file in /etc/bash_completion.d/* ; do
            source $file 2>/dev/null
        done
    fi
fi

# Vi keymap support                                                    {{{1
# help                                                                 {{{2
bindkey -M vicmd 'H'   run-help
bindkey -M vicmd '^[h' run-help
bindkey -M viins '^[h' run-help
# history searching                                                    {{{2
autoload -Uz narrow-to-region
function _history-incremental-preserve-pattern-search-backward {
    local state
    MARK=CURSOR  # magick, else multiple ^R don't work
    narrow-to-region -p "$LBUFFER${BUFFER:+>>}" \
        -P "${BUFFER:+<<}$RBUFFER" -S state
    zle end-of-history
    zle history-incremental-pattern-search-backward
    narrow-to-region -R state
}
zle -N _history-incremental-preserve-pattern-search-backward
bindkey -M vicmd   '/'    _history-incremental-preserve-pattern-search-backward
bindkey -M vicmd   '?'    history-incremental-pattern-search-forward
bindkey -M viins   '^R'   _history-incremental-preserve-pattern-search-backward
bindkey -M isearch '^R'   history-incremental-pattern-search-backward
bindkey -M viins   '^S'   history-incremental-pattern-search-forward
# special keys                                                         {{{2
# note: to get key sequence for a key, do either of these in terminal:
#       Ctrl-v [press key]
#       cat >/dev/null [press key]
#       [thanks to <http://zshwiki.org/home/zle/bindkeys> for tip]
# - home key
#   default: invokes run-help on first token in line
bindkey -M viins   '^[[H' vi-beginning-of-line
# - end key
#   default: after pressing <home>, <end> stops working
bindkey -M viins   '^[[F' end-of-line
# - delete key
#   default: change case of next three characters and enter normal mode
bindkey -M viins   '^[[3~' vi-delete-char

# Mimetype support                                                     {{{1
autoload -Uz zsh-mime-setup
zsh-mime-setup

# Renaming                                                             {{{1
autoload -Uz zmv
alias zmv='noglob zmv'
alias zcp='noglob zmv -C'
alias zln='noglob zmv -Ls'

# Pager uses vim                                                       {{{1
vimpager="$HOME/.cache/dein/repos/github.com/rkitover/vimpager/vimpager"
if [ -f "$vimpager" ] ; then
    export PAGER="$vimpager"
    alias less=$PAGER
    alias zless=$PAGER
fi
# Disable flow control (Ctrl-s, Ctrl-q)                                {{{1
# tip from http://www.reddit.com/r/commandline/comments/1dhame/tmux_and_konsole_have_something_called_flow/
stty stop  undef
stty start undef

# Functions                                                            {{{1
# setup                                                                {{{2
my_fpath="$HOME/.zsh/functions"
fpath=($my_fpath $fpath)
function autoload_my_fns {
    local fn
    while (($#)) ; do
        fn="$1"
        if [ -f "$my_fpath/$fn" ] ; then
            autoload "$fn"
        else
            echo "Error: could not find function '$my_fpath/$fn'"
        fi
        shift
    done
}
# weather three day forecasts                                          {{{2
autoload_my_fns weatherdarwin weathersydney weathermelbourne weatherbrisbane
# extract any archive ('ex <archive>')                                 {{{2
autoload_my_fns extract_archive
if type -f extract_archive &>/dev/null ; then
    alias ex=extract_archive
    compdef '_files -g "*.gz *.tgz *.bz2 *.tbz *.zip *.rar *.tar *.lha"' \
        extract_archive
fi
# execute 'git status' if empty enter in git-managed directory         {{{2
autoload_my_fns magic-enter
if type -f magic-enter &>/dev/null ; then
    zle -N magic-enter
    bindkey -M viins   '^M'  magic-enter
fi
# tmux help                                                            {{{2
autoload_my_fns helptmux
# git aliases                                                          {{{2
autoload_my_fns git-add-all
if type -f git-add-all &>/dev/null ; then
    alias gaa=git-add-all
fi
# ansi colours                                                         {{{2
# - provides variables: RED, GREEN, YELLOW, BLUE, MAGENTA,
#   CYAN, BLACK, WHITE, the same colours as BOLD_*, and RESET
autoload colors && colors
for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
    eval export $COLOR='$fg_no_bold[${(L)COLOR}]'
    eval export BOLD_$COLOR='$fg_bold[${(L)COLOR}]'
done
eval RESET='$reset_color'
# dictionary and thesaurus                                             {{{2
# - uses WordNet v3.0
wordnet='/usr/local/WordNet-3.0'
if [ "${OSTYPE}" = 'cygwin' -a -f "${wordnet}/bin/wn.exe" ] ; then
    autoload_my_fns dict
fi
# man pages open in vim                                                {{{2
vman() {
    vim -c "SuperMan $*"
    [[ "$?" == '0' ]] || echo "No manual entry for $*"
}
compdef vman='man'
# google search                                                        {{{2
# - from http://stackoverflow.com/a/187853
function url_encode {    # percent encodes *all* characters
    setopt extended_glob
    echo "${${(j: :)@}//(#b)(?)/%$[[##16]##${match[1]}]}"
    setopt local_options
}
function google {    # look up search terms in google
    local ARGS="$(url_encode "${(j: :)@}")"
    /usr/bin/links2 "http://www.google.com/search?q=$ARGS"
}
# file navigation                                                      {{{2
# - this solution from jeroen janssens at http://jeroenjanssens.com/2013/08/16/quickly-navigate-your-filesystem-from-the-command-line.html>
# - changed terminology to mirror apparix: 'mark'->'bm', 'jump'->'to'
export MARKPATH=$HOME/.marks
function to {
    cd -P "$MARKPATH/$1" 2>/dev/null || echo "No such mark: $1"
}
function bm {
    mkdir -p "$MARKPATH"; ln -s "$(pwd)" "$MARKPATH/$1"
}
function unbm {
    rm -i "$MARKPATH/$1"
}
function bms {
    ls -l "$MARKPATH" | sed 's/  / /g' | cut -d' ' -f9- \
        | sed 's/ -/\t-/g' && echo
}
function _completebms {
  reply=($(ls $MARKPATH))
}
compctl -K _completebms to
compctl -K _completebms unbm

# Variables                                                            {{{1
# paths                                                                {{{2
# - base PATH                                                          {{{3
PATH='/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/games'
# - executables (local)                                                {{{3
local_bin="${HOME}/.local/bin"
[[ -d "${local_bin}" ]] && PATH="${local_bin}:${PATH}"
unset local_bin
# - go                                                                 {{{3
go_dir="/usr/local/lib/go"
[[ -d "${go_dir}" ]] && GOPATH="${go_dir}"
unset go_dir
go_bin="/usr/local/lib/go/bin"
[[ -d "${go_bin}" ]] && PATH="${PATH}:${go_bin}"
unset go_bin
# - haskell-installed binaries on cygwin                               {{{3
hask_bin='/cygdrive/c/dtn/AppData/Roaming/cabal/bin'
[[ -d "${hask_bin}" ]] && PATH="${PATH}:${hask_bin}"
unset hask_bin
# - node.js-installed binaries on cygwin                               {{{3
node_js="/cygdrive/c/Program\ Files/nodejs"
[[ -d "${node_js}" ]] && PATH="${PATH}:${node_js}"
unset node_js
# - npm-installedpps                                                   {{{3
#   . in ~/.npmrc is configured with prefix of ~/.local
npm_mod="${HOME}/.local/lib/node_modules"
NODE_PATH="${NODE_PATH}${NODE_PATH+:}${npm_mod}"
unset npm_mod
npm_man="${HOME}/.local/share/man"
manpath="${manpath}${manpath+:}${npm_man}"
unset npm_man
# - perl5 local::lib                                                   {{{3
#   . 2016-03-13: discovered that PERL5LIB and PERL_LOCAL_LIB_ROOT
#     are set to their desired values before reaching this point,
#     so check value of vars before adding to them
PATH="${HOME}/perl5/bin${PATH+:}${PATH}";
perl5_lib="${HOME}/perl5/lib/perl5"
[[ "${PERL5LIB}" != "${perl5_lib}" ]] && \
    PERL5LIB="${perl5_lib}${PERL5LIB+:}${PERL5LIB}"
unset perl5_lib
perl5_root="${HOME}/perl5"
[[ "${PERL_LOCAL_LIB_ROOT}" != "${perl5_root}" ]] && \
    PERL_LOCAL_LIB_ROOT="${perl5_root}${PERL_LOCAL_LIB_ROOT+:}${PERL_LOCAL_LIB_ROOT}"
PERL_MB_OPT="--install_base \"${perl5_root}\""
PERL_MM_OPT="INSTALL_BASE=${perl5_root}"
unset perl5_root
perl5_man="${HOME}/perl5/man"
manpath="${perl5_man}${manpath+:}${manpath}"
unset perl5_man
# - perl6 rakudobrew                                                   {{{3
rakudo_bin="${HOME}/.rakudobrew/bin"
[[ -d "${rakudo_bin}" ]] && PATH="${rakudo_bin}:${PATH}"
unset rakudo_bin
# - wordnet                                                            {{{3
PATH="${PATH}:${wordnet}/bin"
WNHOME="${wordnet}"
unset wordnet
# - export paths                                                       {{{3
export PATH
export PERL5LIB
export PERL_LOCAL_LIB_ROOT
export PERL_MB_OPT
export PERL_MM_OPT
export manpath
export WNHOME
export NODE_PATH
# editor                                                               {{{2
export EDITOR='vim'
export USE_EDITOR="$EDITOR"
export VISUAL="$EDITOR"

                                                                     # }}}1

# Oh My Zsh configuration

# Install location                                                     {{{1
export ZSH="$HOME/.oh-my-zsh"

# Theme                                                                {{{1
# see ~/.oh-my-zsh/themes/
#ZSH_THEME='robbyrussell'
#ZSH_THEME='juanghurtado'
#ZSH_THEME='josh'
ZSH_THEME='miloshadzic'

# Setup                                                                {{{1
source $ZSH/oh-my-zsh.sh

# Options                                                              {{{1
# type 'dir' instead of 'cd dir'                                       {{{2
# - set by plugin
setopt auto_cd
# automatically push old directory into directory stack                {{{2
# - set by plugin
setopt auto_pushd
# no multiples on directory stack                                      {{{2
# - set by plugin
setopt pushd_ignore_dups
# swap '+' and '-' meanings for stack directory                        {{{2
# - set by plugin
setopt pushd_minus
# silence pushd messages                                               {{{2
setopt pushd_silent
# can try to expand cd var by prepending '~'                           {{{2
# - set by plugin
setopt cdable_vars
# move to end of word on completion                                    {{{2
# - set by plugin
setopt always_to_end
# complete from both ends of word                                      {{{2
# - set by plugin
setopt complete_in_word
# history saves command timestamp and duration                         {{{2
# - set by plugin
setopt extended_history
# expire duplicate commands first                                      {{{2
# - set by plugin
setopt hist_expire_dups_first
# do not add duplicate command to history                              {{{2
# - set by plugin
setopt hist_ignore_dups
# remove history command if starts with space                          {{{2
# - set by plugin
setopt hist_ignore_space
# if enter history line, reload in edit buffer                         {{{2
# - set by plugin
setopt hist_verify
# add commands to history immediately                                  {{{2
# - set by plugin
setopt inc_append_history
# import new commands from history                                     {{{2
# - set by plugin
setopt share_history
# disable ctrl-s/ctrl-q flow control                                   {{{2
# - set by plugin
setopt no_flow_control
# list jobs in long format                                             {{{2
# - set by plugin
setopt long_list_jobs
# do expansions in prompt                                              {{{2
# - set by plugin
setopt prompt_subst
# expand globs                                                         {{{2
setopt glob_complete
# sort numeric file names numerically                                  {{{2
setopt numeric_glob_sort
# parameter interpolation                                              {{{2
# - xx=(a b c); foo${xx}bar => fooabar foobbar foocbar
setopt rc_expand_param
# 10 second wait before global deletion                                {{{2
setopt rm_star_wait
# correct spelling                                                     {{{2
setopt correct
# allow comments in interactive shells                                 {{{2
setopt interactive_comments

# Preserve tmux's automatic title renaming                             {{{1
# - prevent OMZ from overriding tmux's automatic rename setting
export DISABLE_AUTO_TITLE='true'
                                                                     # }}}1

# Aliases (must come last to override aliases set up by modules)

# ls                                                                   {{{1
alias ls='ls -l --almost-all --color=auto'
# mp3info2 must use only tags, no deducing from file name              {{{1
alias mp3info2='mp3info2 -C autoinfo=ID3v2,ID3v1'
# reload zshrc                                                         {{{1
alias reload=". ~/.zshrc && echo 'ZSH config reloaded from ~/.zshrc'"
# dictionary and thesaurus                                             {{{1
alias thes='dict -h localhost -d moby-thesaurus'
# ag alias                                                             {{{1
# - set automatically by oh-my-zsh
# - remove alias if ag binary exists
if [ -f '/usr/bin/ag' ] ; then
    if [ $(alias 'ag' >/dev/null ; echo $?) -eq 0 ] ; then
        unalias 'ag'
    fi
fi                                                                    # }}}1

# Initial apps

# Fortune                                                              {{{1
if which fortune &>/dev/null ; then
    echo "${RED}Fortune for today:${RESET}"
    echo
    fortune
    echo
fi

# Chuck Norris cow                                                     {{{1
if which chuck_cow &>/dev/null ; then
    echo "${RED}Cow has a Chuck Norris fact:${RESET}"
    chuck_cow
    echo
fi                                                                   # }}}1

# vim:fdm=marker:
