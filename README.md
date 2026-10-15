# Dotfiles

Ubuntu in WSL dotfiles managed with chezmoi. Obsidian's official Debian package
requires amd64; desktop applications use WSLg. Run chezmoi as your normal user.

## First run

Install Git and curl, then install chezmoi into `~/.local/bin`. This is the
supported bootstrap location; the dotfiles do not install chezmoi themselves.
Run the installer from your Linux home directory, where executable permissions
are supported:

```sh
sudo apt update
sudo apt install --yes git curl
cd "$HOME"
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init jackmaders
"$HOME/.local/bin/chezmoi" diff
"$HOME/.local/bin/chezmoi" apply
```

Initialization prompts for `personal` or `twinkl`, a Git author name, and an
email address. These values live in `~/.config/chezmoi/chezmoi.toml`, outside
the repository. To use an existing checkout instead, run
`~/.local/bin/chezmoi --source "$PWD" init`, then `diff` and `apply` with the
same `--source` argument.

Apply installs APT packages, creates development and vault directories, creates
`~/.ssh/id_ed25519` if neither key file exists, and sets Zsh as the login shell.
`ssh-keygen` asks for a passphrase; APT and `chsh` use `sudo`. Existing private
keys are preserved. An orphan public key stops setup with recovery instructions.
Open a new WSL session for the login-shell change to take effect. To authenticate
with GitHub and upload the generated public key, run:

```sh
gh auth login --git-protocol ssh
```

## Layout and lifecycle

```text
.chezmoi.toml.tmpl                         # Local profile and Git identity prompts
.chezmoiexternal.toml                      # Pinned fnm binary and fzf-tab plugin
run_onchange_before_10-install-apt-packages.sh # Shared Ubuntu packages
run_once_after_20-bootstrap.sh.tmpl        # Directories, SSH key, login shell
run_after_40-install-tools.sh              # Install and verify tools on each apply
dot_zshenv                                # Bootstrap ~/.config/zsh
dot_config/zsh/                           # Environment and interactive startup
dot_config/git/config.tmpl                # Git settings, identity, signing
dot_config/starship.toml.tmpl              # Prompt and profile colors
dot_config/gh/config.yml                  # GitHub CLI preferences
```

APT runs when its script contents change. Bootstrap runs once for each unique
rendered version of its contents: editing it or selecting a new profile can run
it again, while returning to a previously applied version skips it. Its guards
preserve existing keys and avoid changing an already selected login shell.
Failures stop apply. Packages and directories are not removed on profile changes.

Every apply installs the latest Node.js LTS and selects it as fnm's default,
ensures Codex and pnpm are installed for that Node version, and checks required
commands. It also installs Starship, Bun, and Claude Code when missing, runs the
Herdr and Antigravity CLI installers, and installs the latest stable Obsidian
desktop package. fnm stays pinned to the version in the external manifest.
Claude Code and Antigravity CLI also manage updates during normal use.

## Profiles and paths

Set `data.profile` to `personal` or `twinkl` in the local chezmoi config, then
apply. Profiles select prompt colors, `~/dev/personal` or `~/dev/twinkl`, and Git
signing. Twinkl signs commits and tags with `~/.ssh/id_ed25519.pub`; personal
disables signing. `data.gitName` and `data.gitEmail` set the author identity.
Keep private keys and secrets outside this repository.

This setup uses the standard XDG locations `~/.config` and `~/.local/share`;
custom `XDG_CONFIG_HOME` and `XDG_DATA_HOME` values are unsupported. Zsh reads
`.zshenv` for every shell and `.zshrc` for interactive shells.
Its environment adds `~/.local/bin`, `$BUN_INSTALL/bin`
(default `~/.bun/bin`), and `$PNPM_HOME` (default `~/.local/share/pnpm`) to PATH.
WSL supplies display and runtime variables.
