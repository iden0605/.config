# -------------------------------
# Basic Aliases
# -------------------------------

alias reload-zsh="source ~/.zshrc"
alias edit-zsh="nvim ~/.zshrc"
alias python="python3"

# Custom Short Aliases
alias zell="zellij"
alias zd="zoxide"
alias lz="eza"

# -------------------------------
# Powerlevel10k Theme
# -------------------------------

source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# -------------------------------
# History Configuration
# -------------------------------

HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999

setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# Arrow key history search
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# -------------------------------
# PATH Exports
# -------------------------------

export PATH="$HOME/.rbenv/shims:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# -------------------------------
# FZF Setup
# -------------------------------

# Load fzf
eval "$(fzf --zsh)"

# Use fd for searching
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# FZF Theme
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# Preview behavior
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'" "$@" ;;
    ssh)          fzf --preview 'dig {}' "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

# -------------------------------
# Bat (Better Cat)
# -------------------------------

export BAT_THEME=tokyonight_night

# -------------------------------
# Eza (Better LS)
# -------------------------------

alias ls="eza --icons=always"

# -------------------------------
# Yazi File Manager
# -------------------------------

export EDITOR="nvim"

function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# -------------------------------
# NVM (Node Version Manager)
# -------------------------------

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# -------------------------------
# ZSH Plugins (Load Last)
# -------------------------------

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Tab accepts autosuggestions
bindkey '^I' autosuggest-accept
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/.antigravity/antigravity/bin"
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Secrets (SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, SPOTIFY_REFRESH_TOKEN, ...) live outside the repo
[ -f ~/.zshrc.secrets ] && source ~/.zshrc.secrets

function _spotify_get_token() {
    curl -s -X POST "https://accounts.spotify.com/api/token" -H "Content-Type: application/x-www-form-urlencoded" -u "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" -d "grant_type=refresh_token&refresh_token=$SPOTIFY_REFRESH_TOKEN" | jq -r '.access_token'
}

# Start sesh
function start() {
    local dir="${1:-.}"
    dir=$(realpath "$dir")
    nohup ~/.local/bin/ncspot-autostart.sh > /dev/null 2>&1 &
    disown
    cd "$dir" && ZELLIJ_DEFAULT_CWD="$dir" zellij --layout ~/.config/zellij/layouts/dev.kdl
}
# Kill sesh
function stop() {
    zellij kill-session --yes 2>/dev/null || zellij kill-all-sessions --yes 2>/dev/null
}

# Terminal spotify functions
function sp() {
    local sock="/tmp/ncspot-$(id -u)/ncspot.sock"
    local cmd=$1
    local arg=$2

    if [ ! -S "$sock" ]; then
        echo "ncspot is not running"
        return 1
    fi

    case $cmd in
        next)
            echo 'next' | nc -U "$sock" > /dev/null
            echo "Skipped to next track"
            ;;
        prev)
            echo 'previous' | nc -U "$sock" > /dev/null
            echo "Going to previous track"
            ;;
        toggle)
            echo 'playpause' | nc -U "$sock" > /dev/null
            echo "Toggled playback"
            ;;
        up)
            local amount=${arg:-10}
            echo "volup $amount" | nc -U "$sock" > /dev/null
            echo "Volume +$amount"
            ;;
        down)
            local amount=${arg:-10}
            echo "voldown $amount" | nc -U "$sock" > /dev/null
            echo "Volume -$amount"
            ;;
        shuffle)
            echo 'shuffle' | nc -U "$sock" > /dev/null
            echo "Toggled shuffle"
            ;;
        status)
            echo 'status' | nc -U "$sock" | jq '{title: .playable.title, artist: .playable.artists[0], mode: .mode}'
            ;;
        *)
            echo "Usage: sp <next|prev|toggle|up|down|shuffle|status> [amount]"
            ;;
    esac
}

function _spotify_play_chillin() {
    local token=$(_spotify_get_token)

    # find Chillin playlist id
    local playlist_id
    playlist_id=$(curl -s -G "https://api.spotify.com/v1/me/playlists" \
        -H "Authorization: Bearer $token" \
        --data-urlencode "limit=50" \
        | jq -r '.items[] | select(.name == "Chillin") | .id')

    if [ -z "$playlist_id" ]; then
        echo "Could not find playlist Chillin"
        return 1
    fi

    # get active device
    local device_id
    device_id=$(curl -s "https://api.spotify.com/v1/me/player/devices" \
        -H "Authorization: Bearer $token" \
        | jq -r '.devices[0].id')

    if [ -z "$device_id" ] || [ "$device_id" = "null" ]; then
        echo "No active Spotify device found"
        return 1
    fi

    # enable shuffle via API
    curl -s -X PUT "https://api.spotify.com/v1/me/player/shuffle?state=true&device_id=$device_id" \
        -H "Authorization: Bearer $token" > /dev/null

    # start Chillin playlist
    curl -s -X PUT "https://api.spotify.com/v1/me/player/play?device_id=$device_id" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{\"context_uri\":\"spotify:playlist:$playlist_id\"}" > /dev/null

    echo "Playing Chillin on Spotify"
}

code() {
    open -a "Visual Studio Code" "$1"
}

# Unity CLI
[ -f "$HOME/.unity/env" ] && . "$HOME/.unity/env"

# -------------------------------
# Zoxide (Better CD)
# -------------------------------

eval "$(zoxide init zsh)"
alias cd="z"
