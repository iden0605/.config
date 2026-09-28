#!/usr/bin/env bash
# Bootstraps a macOS machine from this repo. Safe to re-run.
# Usage: ~/.config/install.sh [--no-apps]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
NO_APPS=0
[[ "${1:-}" == "--no-apps" ]] && NO_APPS=1

log() { printf '\n==> %s\n' "$*"; }

# Symlinks src -> dest, backing up anything already at dest
link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then return; fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP"
    mv "$dest" "$BACKUP/"
    echo "backed up $dest -> $BACKUP/"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "linked $dest"
}

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This script targets macOS. On Linux, see README.md for the manual steps." >&2
  exit 1
fi

log "Xcode command line tools"
xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "Re-run once the CLT install finishes."; exit 1; }

log "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

log "Brew bundle"
if [[ $NO_APPS -eq 1 ]]; then
  # CLI tools, fonts and global npm/go packages only
  tmp="$(mktemp)"
  grep -v '^cask "' "$REPO/Brewfile" > "$tmp"
  brew bundle --file="$tmp" || true
  rm -f "$tmp"
  brew install --cask font-meslo-lg-nerd-font wezterm || true
else
  brew bundle --file="$REPO/Brewfile" || echo "Some Brewfile entries failed; see output above."
fi

log "Dotfiles"
for f in "$REPO"/home/.[!.]*; do
  link "$f" "$HOME/$(basename "$f")"
done
link "$REPO/local-bin/ncspot-autostart.sh" "$HOME/.local/bin/ncspot-autostart.sh"

VSCODE_USER="$HOME/Library/Application Support/Code/User"
link "$REPO/vscode/settings.json" "$VSCODE_USER/settings.json"
link "$REPO/vscode/keybindings.json" "$VSCODE_USER/keybindings.json"

log "ncspot config"
if [[ ! -f "$REPO/ncspot/config.toml" ]]; then
  cp "$REPO/ncspot/config.example.toml" "$REPO/ncspot/config.toml"
fi

log "Secrets"
if [[ ! -f "$HOME/.zshrc.secrets" ]]; then
  cat > "$HOME/.zshrc.secrets" <<'EOF'
# Not tracked. Fill in from the Spotify developer dashboard.
SPOTIFY_CLIENT_ID=""
SPOTIFY_CLIENT_SECRET=""
SPOTIFY_REFRESH_TOKEN=""
EOF
  chmod 600 "$HOME/.zshrc.secrets"
  echo "created ~/.zshrc.secrets template, fill it in"
fi

log "VS Code extensions"
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [[ -x "$CODE_BIN" ]]; then
  while read -r ext; do
    [[ -n "$ext" ]] && "$CODE_BIN" --install-extension "$ext" --force >/dev/null || true
  done < "$REPO/vscode/extensions.txt"
else
  echo "VS Code not installed, skipping"
fi

log "Neovim plugins"
command -v nvim >/dev/null && nvim --headless "+Lazy! sync" +qa || true

log "Default shell"
[[ "$SHELL" == */zsh ]] || chsh -s /bin/zsh

log "Done. Open a new terminal (WezTerm) to load everything."
