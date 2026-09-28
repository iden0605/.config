# .config

My macOS dev setup: apps, CLI tools, shell, terminal, editor and app settings. This repo lives at `~/.config`, the XDG config directory, so tools like nvim, zellij and ncspot read their config straight from it. Files that belong elsewhere in `$HOME` are symlinked in by `install.sh`.

## New machine

```sh
git clone https://github.com/iden0605/.config.git ~/.config   # back up any existing ~/.config first
~/.config/install.sh            # everything
~/.config/install.sh --no-apps  # CLI tools + dotfiles only (VMs, servers)
```

`install.sh` is idempotent. It:

1. Installs the Xcode CLT and Homebrew.
2. Runs `brew bundle` on `Brewfile`. That installs formulae, casks/GUI apps, the Nerd Font, global npm packages and gopls.
3. Symlinks `home/*` into `~` (`.zshrc`, `.zprofile`, `.p10k.zsh`, `.wezterm.lua`, `.gitconfig`, `.bashrc`), `local-bin/*` into `~/.local/bin`, and `vscode/*.json` into VS Code's user dir. Anything it would overwrite goes to `~/.dotfiles-backup/<timestamp>/`.
4. Creates `ncspot/config.toml` from the example, plus a `~/.zshrc.secrets` template.
5. Installs VS Code extensions from `vscode/extensions.txt`, syncs Neovim plugins (lazy.nvim), and makes zsh the login shell.

## Layout

| Path | What |
|---|---|
| `Brewfile` | Homebrew taps, formulae, casks, npm globals, go tools |
| `home/` | Dotfiles symlinked into `~`, including `.wezterm.lua` (the terminal) |
| `local-bin/` | Scripts symlinked into `~/.local/bin` |
| `vscode/` | VS Code settings, keybindings, extension list |
| `nvim/` | Neovim config (lazy.nvim, `lua/iden/...`) |
| `zellij/` | Zellij config (`config.kdl`) + `layouts/dev.kdl` (used by the `start` shell function) |
| `ncspot/` | Terminal Spotify client keybindings |
| `git/ignore` | Global gitignore |
| `tmux/` | Misc tool config |

The shell stack is zsh + powerlevel10k + zsh-autosuggestions + zsh-syntax-highlighting + fzf (with fd/bat/eza previews) + zoxide. Aliases and functions (`sp`, `start`, `stop`, `y`, etc.) are all in `home/.zshrc`.

## Secrets (not in the repo)

- `~/.zshrc.secrets`: `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_REFRESH_TOKEN`. `.zshrc` sources it.
- `ncspot/config.toml`: ncspot's login lives here. It's gitignored, and ncspot can also log in interactively.
- Tool logins: `gh auth login`, `gcloud auth login`, `vercel login`, `wrangler login`, `stripe login`, `firebase login`, `netlify login`, `supabase login`, `tailscale up`.

`.gitignore` is an allowlist, so any new config dir has to be added to it explicitly. That keeps tokens and caches from tools like gh, gcloud and stripe out of this public repo.

## Manual steps

Some things `install.sh` can't do:

- **Not installable via Homebrew:** Xcode (App Store), Visual Studio, Adobe Acrobat, Movavi Video Editor, GlobalProtect, Okta Verify, Trello, LockDown Browser, Hytale Launcher, NoxAppPlayer, Unity editor (via Unity Hub), GarageBand/iMovie/Keynote/Numbers/Pages (App Store).
- **Raycast:** extensions come from the Raycast Store: Spotify Player, Color Picker, Kill Process, Google Chrome. For hotkeys and settings, use Raycast's Settings → Advanced → Export/Import (`.rayconfig`).
- **Node:** comes from Homebrew. NVM is optional and is loaded by `.zshrc` only if `~/.nvm` exists.
- **Log into apps and CLIs** (see Secrets above).

## Updating this repo from the current machine

```sh
cd ~/.config
brew bundle dump --file=Brewfile --force --no-vscode   # then re-append the "# Apps" cask block if dump dropped it
code --list-extensions > vscode/extensions.txt
git add -A && git status   # check nothing secret got staged
```

Home dotfiles and VS Code settings are symlinks, so editing them in place already updates the repo.
