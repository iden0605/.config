#!/usr/bin/env bash
# Bootstraps a macOS machine from this repo. Safe to re-run.
# Usage: ~/.config/install.sh [--no-apps]
#    or: bash -c "$(curl -fsSL https://raw.githubusercontent.com/iden0605/.config/main/install.sh)"
set -uo pipefail

REPO_URL="https://github.com/iden0605/.config.git"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
NO_APPS=0
FAILED=()

for arg in "$@"; do
  case "$arg" in
    --no-apps) NO_APPS=1 ;;
    -h|--help) echo "Usage: install.sh [--no-apps]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# When piped from curl there is no checkout yet, so the repo goes to ~/.config
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" && -f "$(dirname "$SELF")/Brewfile" ]]; then
  REPO="$(cd "$(dirname "$SELF")" && pwd)"
else
  REPO="$HOME/.config"
fi

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }

# Runs a step, recording a failure instead of aborting the whole install
step() {
  local name="$1"
  shift
  log "$name"
  if ! "$@"; then
    FAILED+=("$name")
    echo "!! $name failed, continuing" >&2
  fi
}

# Moves an existing file out of the way, keeping its path relative to $HOME
backup() {
  local path="$1" rel
  rel="${path#"$HOME"/}"
  mkdir -p "$BACKUP/$(dirname "$rel")"
  mv "$path" "$BACKUP/$rel"
  echo "backed up $path -> $BACKUP/$rel"
}

# Symlinks src -> dest, backing up anything already at dest
link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then return 0; fi
  if [[ -e "$dest" || -L "$dest" ]]; then backup "$dest"; fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest" && echo "linked $dest"
}

have_clt() { xcode-select -p >/dev/null 2>&1 && xcrun --find git >/dev/null 2>&1; }

install_clt() {
  have_clt && return 0
  # Same headless route the Homebrew installer uses
  local flag=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress label
  touch "$flag"
  label="$(softwareupdate -l 2>/dev/null | sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | sort -V | tail -n1)"
  [[ -n "$label" ]] && sudo softwareupdate -i "$label"
  rm -f "$flag"
  have_clt && return 0
  xcode-select --install >/dev/null 2>&1
  echo "Click Install in the dialog that just opened. Waiting for it to finish..."
  until have_clt; do sleep 5; done
}

install_rosetta() {
  [[ "$(uname -m)" == "arm64" ]] || return 0
  pgrep -q oahd && return 0
  sudo softwareupdate --install-rosetta --agree-to-license
}

brew_bin() {
  local p
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$p" ]] && { echo "$p"; return 0; }
  done
  return 1
}

install_homebrew() {
  brew_bin >/dev/null && return 0
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

# Puts the repo at ~/.config, keeping whatever other apps already wrote there
fetch_repo() {
  [[ -d "$REPO/.git" ]] && return 0
  if [[ ! -e "$REPO" || -z "$(ls -A "$REPO")" ]]; then
    git clone "$REPO_URL" "$REPO"
    return
  fi
  local tmp name
  tmp="$(mktemp -d)"
  git clone "$REPO_URL" "$tmp/repo" || return 1
  for name in $(git -C "$tmp/repo" ls-tree --name-only HEAD); do
    if [[ -e "$REPO/$name" || -L "$REPO/$name" ]]; then backup "$REPO/$name"; fi
  done
  mv "$tmp/repo/.git" "$REPO/.git" && git -C "$REPO" reset -q --hard
  rm -rf "$tmp"
}

brew_bundle() {
  if [[ $NO_APPS -eq 1 ]]; then
    # CLI tools, the font, the terminal and global npm/go packages only
    local tmp rc=0
    tmp="$(mktemp)"
    grep -v '^cask "' "$REPO/Brewfile" > "$tmp"
    echo 'cask "font-meslo-lg-nerd-font"' >> "$tmp"
    echo 'cask "wezterm"' >> "$tmp"
    brew bundle --file="$tmp" || rc=1
    rm -f "$tmp"
    return $rc
  fi
  brew bundle --file="$REPO/Brewfile"
}

link_dotfiles() {
  local f rc=0
  for f in "$REPO"/home/.[!.]*; do
    link "$f" "$HOME/$(basename "$f")" || rc=1
  done
  link "$REPO/local-bin/ncspot-autostart.sh" "$HOME/.local/bin/ncspot-autostart.sh" || rc=1

  local vscode_user="$HOME/Library/Application Support/Code/User"
  link "$REPO/vscode/settings.json" "$vscode_user/settings.json" || rc=1
  link "$REPO/vscode/keybindings.json" "$vscode_user/keybindings.json" || rc=1
  return $rc
}

local_files() {
  if [[ ! -f "$REPO/ncspot/config.toml" ]]; then
    cp "$REPO/ncspot/config.example.toml" "$REPO/ncspot/config.toml" || return 1
  fi
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
}

install_claude() {
  if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then return 0; fi
  curl -fsSL https://claude.ai/install.sh | bash
}

vscode_extensions() {
  local code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ext rc=0
  [[ -x "$code_bin" ]] || code_bin="$(command -v code || true)"
  if [[ -z "$code_bin" ]]; then
    echo "VS Code not installed, skipping"
    return 0
  fi
  while read -r ext; do
    [[ -z "$ext" ]] && continue
    if ! "$code_bin" --install-extension "$ext" --force >/dev/null 2>&1 </dev/null; then
      echo "could not install $ext" >&2
      rc=1
    fi
  done < "$REPO/vscode/extensions.txt"
  return $rc
}

setup_nvim() {
  if ! command -v nvim >/dev/null 2>&1; then
    echo "nvim not installed, skipping"
    return 0
  fi
  local lock="$REPO/nvim/lazy-lock.json" tmp rc=0
  tmp="$(mktemp -d)"

  # The first pass bootstraps lazy.nvim and rewrites the lockfile, so put it
  # back and restore again to land every plugin on the pinned commit
  cp "$lock" "$tmp/lazy-lock.json"
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1
  cp "$tmp/lazy-lock.json" "$lock"
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || rc=1

  # mason-lspconfig skips ensure_installed when headless, so install its servers here
  cat > "$tmp/mason.lua" <<'EOF'
local map = require("mason-lspconfig").get_mappings().lspconfig_to_package
local reg = require("mason-registry")
local function missing()
  local pkgs = {}
  for _, server in ipairs(require("mason-lspconfig.settings").current.ensure_installed) do
    local name = map[server]
    if name and not reg.is_installed(name) then table.insert(pkgs, name) end
  end
  return pkgs
end
local pkgs = missing()
if #pkgs > 0 then pcall(vim.cmd, "MasonInstall " .. table.concat(pkgs, " ")) end
pkgs = missing()
if #pkgs > 0 then
  io.stderr:write("mason could not install: " .. table.concat(pkgs, " ") .. "\n")
  vim.cmd("cquit")
end
EOF
  nvim --headless "+MasonToolsInstallSync" "+luafile $tmp/mason.lua" +qa || rc=1

  nvim --headless "+Lazy! load nvim-treesitter" \
    "+lua require('nvim-treesitter.install').ensure_installed_sync(require('nvim-treesitter.configs').get_ensure_installed_parsers())" \
    +qa || rc=1
  echo
  rm -rf "$tmp"
  return $rc
}

extras() {
  local rc=0
  if command -v uv >/dev/null 2>&1; then
    uv python install 3.12 || rc=1
  fi
  if command -v dotnet >/dev/null 2>&1 && ! dotnet tool list -g 2>/dev/null | grep -q '^dotnet-ef'; then
    dotnet tool install -g dotnet-ef || rc=1
  fi
  return $rc
}

default_shell() {
  [[ "$SHELL" == */zsh ]] || sudo chsh -s /bin/zsh "$USER"
}

[[ "$(uname)" == "Darwin" ]] || die "This script targets macOS."
[[ $EUID -ne 0 ]] || die "Run as your normal user, not with sudo."

echo "Your password is needed once, for Homebrew and app installers."
sudo -v || die "sudo access is required."
( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null' EXIT

log "Xcode command line tools"
install_clt || die "Could not install the Xcode command line tools."

log "Repo"
fetch_repo || die "Could not set up the repo at $REPO."
[[ "$REPO" == "$HOME/.config" ]] || echo "warning: repo is at $REPO; nvim, zellij and ncspot only read it from ~/.config" >&2

[[ $NO_APPS -eq 1 ]] || step "Rosetta" install_rosetta

log "Homebrew"
install_homebrew
BREW="$(brew_bin)" || die "Homebrew is not installed."
eval "$("$BREW" shellenv)"

step "Brew bundle" brew_bundle
step "Dotfiles" link_dotfiles
step "Local config and secrets" local_files
step "Claude Code" install_claude
[[ $NO_APPS -eq 1 ]] || step "VS Code extensions" vscode_extensions
step "Neovim plugins, LSP servers and parsers" setup_nvim
step "Extra toolchains" extras
step "Default shell" default_shell

if [[ ${#FAILED[@]} -gt 0 ]]; then
  log "Finished with problems in:"
  printf '  - %s\n' "${FAILED[@]}"
  echo "Fix what the output above points at and re-run $REPO/install.sh; finished steps are skipped."
  exit 1
fi

log "Done. Open WezTerm to load everything, then see 'After the script' in $REPO/README.md."
