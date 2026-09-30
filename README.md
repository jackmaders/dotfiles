# Dotfiles

This repository manages user configuration on Ubuntu in WSL with chezmoi.
NixOS and Home Manager configuration has been replaced with Ubuntu package
installation and normal dotfiles.

## Layout

```text
chezmoi.toml.tmpl                 # First-run profile and Git identity prompts
.chezmoidata/packages.yaml        # Ubuntu APT package list
run_onchange_before_*.sh.tmpl     # Install APT packages when the list changes
run_once_after_*.sh.tmpl          # One-time setup after files and packages
run_after_*.sh.tmpl               # Validate/install required tools on each apply
dot_zshenv.tmpl                  # Bootstrap the XDG Zsh startup directory
dot_config/zsh/                  # Zsh environment, login, and interactive startup files
dot_config/git/config.tmpl       # Shared Git settings and profile identity
.chezmoitemplates/profile/       # Dynamically included personal/Twinkl settings
dot_config/starship.toml.tmpl    # Shared prompt settings plus selected theme
dot_config/zed/                  # Zed settings for the WSL-side Zed environment
```

Zsh reads `.zshenv` for every shell, `.zprofile` for login shells, and `.zshrc`
for interactive shells. Keep `.zshenv` limited to quiet environment setup; put
interactive behavior in `.zshrc`.

## First run

Install chezmoi and Git inside Ubuntu, then initialize this repo as the source
directory. For example, from Ubuntu/WSL:

```sh
sudo apt update
sudo apt install chezmoi git
```

Run chezmoi as your normal user, not with `sudo`. In particular, don't run the
installer while your working directory is under `/mnt/c`: Windows-mounted
directories may not support the `chmod` the installer uses. If you use the
upstream installer, run it from your Linux home directory as your normal user.

On first initialization, chezmoi asks you to type `personal` or `twinkl` for
the profile, then asks for the local Git identity values. These are stored in
the machine-local chezmoi config, not in this repo.

```sh
chezmoi --source "$PWD" init
```

Review the plan before applying it:

```sh
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply
```

The apply step installs Ubuntu packages when the package list changes, ensures
the pinned `fnm` release is installed in `~/.local/bin`, installs the latest
Node.js LTS and makes it the `fnm` default, then installs Codex CLI with that
Linux Node.js if it is not already installed for the LTS version. It then
installs the latest stable Herdr release with its official Linux installer
and Claude Code with Anthropic's native Linux installer. Claude Code manages
its own updates after installation.
The apply also creates `~/.ssh/id_ed25519` if it does not already exist, then
sets Zsh as the user's login shell once. `ssh-keygen` asks for a passphrase;
`sudo` is used for APT and `chsh`. APT or setup failures stop the apply instead
of being skipped. Open a new WSL session after apply for the default shell
change to take effect.

To use the new SSH key with GitHub, run:

```sh
gh auth login --git-protocol ssh
```

Follow the prompts to authenticate and upload the generated public key.

## Profiles

The local file `~/.config/chezmoi/chezmoi.toml` contains `data.profile`,
`data.gitName`, and `data.gitEmail`. Set `data.profile` to `personal` or
`twinkl`; templates dynamically include the matching files from
`.chezmoitemplates/profile/` for Git, Starship, and profile-specific directory
setup. Git commit and tag signing are enabled only for the Twinkl profile,
using the generated `~/.ssh/id_ed25519.pub` key. Personal profile commits and
tags are explicitly not signed.
Keep private keys and other secrets outside this repository.

The APT list contains shared shell and CLI dependencies. `fnm` is installed
from its pinned official release on each apply; a missing or mismatched version
is installed or replaced. After installing packages, fnm, Herdr, Node.js,
Codex, and Claude Code, `chezmoi apply` checks that every required command is
available and fails if one is missing. The fnm executable is in `~/.local/bin`,
which `.zshenv` adds to `PATH`. Applications
that use other vendor-specific installers (such as Bun,
dust, pnpm, Obsidian, xh, vimgolf, .NET/Godot, Antigravity CLI, and AWS Vault)
still need their Ubuntu installation source added before they can be automated
here. `chezmoi apply` does not remove packages when a profile changes.

The config leaves WSLg-provided display and runtime variables to WSL instead of
hard-coding the old NixOS values.

## Zed in WSL

`dot_config/zed` manages the Linux-side Zed user configuration under
`~/.config/zed`. It is suitable for language-server, task, and debug settings
that use tools installed in Ubuntu. Zed's Windows UI preferences live in the
Windows user profile; manage those from Windows if you want them versioned too.

The archive's Godot debug entry is rendered only when `data.godotPath` is set in
the local chezmoi config. The C# language server, .NET task, and debugger must
also be installed inside Ubuntu. Project-only Zed settings can stay in a
project's `.zed/` directory.
