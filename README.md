# .config

My macOS dev setup: apps, CLI tools, shell, terminal, editor and app settings. This repo lives at `~/.config`, the XDG config directory, so tools like nvim, zellij and ncspot read their config straight from it. Files that belong elsewhere in `$HOME` are symlinked in by `install.sh`.

## New machine

On a fresh Mac, open Terminal and run:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iden0605/.config/main/install.sh)"
```

That is the whole setup. It asks for your password once, then runs unattended. Expect it to take a while, most of it app downloads. Nothing needs to be installed first: the script installs git itself, puts this repo at `~/.config`, and carries on from there.

For CLI tools and dotfiles only (VMs, servers), skip the GUI apps:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iden0605/.config/main/install.sh)" -- --no-apps
```

If the repo is already cloned, run `~/.config/install.sh` (or `~/.config/install.sh --no-apps`) instead. It is the same script.

### What it does

1. Installs the Xcode command line tools, Rosetta (Apple Silicon) and Homebrew.
2. Clones this repo to `~/.config`. If `~/.config` already exists, only the paths this repo tracks are replaced; everything else in there is left alone.
3. Runs `brew bundle` on `Brewfile`. That installs formulae, casks/GUI apps, the Nerd Font, global npm packages and gopls.
4. Symlinks `home/*` into `~` (`.zshrc`, `.zprofile`, `.p10k.zsh`, `.wezterm.lua`, `.gitconfig`, `.bashrc`), `local-bin/*` into `~/.local/bin`, and `vscode/*.json` into VS Code's user dir.
5. Creates `ncspot/config.toml` from the example, plus a `~/.zshrc.secrets` template.
6. Installs the Claude Code CLI (the `start` layout opens it) and the VS Code extensions in `vscode/extensions.txt`.
7. Sets up Neovim headlessly: plugins at the commits pinned in `nvim/lazy-lock.json`, Mason LSP servers/formatters/linters, and treesitter parsers.
8. Installs Python 3.12 through uv and the `dotnet-ef` tool, and makes zsh the login shell.

### If something goes wrong

- Nothing is deleted. Any file the script replaces is moved to `~/.dotfiles-backup/<timestamp>/` first.
- A failing step does not stop the run. The script carries on and lists the failed steps at the end.
- It is safe to re-run as often as needed. Finished work is skipped, so fix the cause and run `~/.config/install.sh` again.
- A single app failing to download in the Brew bundle step is the usual culprit; re-running picks up just the ones that are missing.
- If the command line tools can't be installed silently, macOS shows an install dialog. Click Install and the script continues by itself when it finishes.

### After the script

These need a human, so the script leaves them to you:

1. Open WezTerm. That is the terminal everything here is set up for.
2. Fill in `~/.zshrc.secrets` (see Secrets below).
3. Log in: `gh auth login`, `claude`, `ncspot`, and whichever of `gcloud auth login`, `vercel login`, `wrangler login`, `stripe login`, `firebase login`, `netlify login`, `supabase login`, `tailscale up` you need.
4. To push to this repo over SSH, add a key to GitHub and run `git -C ~/.config remote set-url origin git@github.com:iden0605/.config.git`. The script clones over HTTPS.
5. Go through Manual steps below for the apps Homebrew can't install.

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

## Updating this repo from the current machine

```sh
cd ~/.config
brew bundle dump --file=Brewfile --force --no-vscode   # then re-append the "# Apps" cask block if dump dropped it
code --list-extensions > vscode/extensions.txt
git add -A && git status   # check nothing secret got staged
```

Home dotfiles and VS Code settings are symlinks, so editing them in place already updates the repo.
