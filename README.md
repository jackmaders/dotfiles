# Dotfiles

This repository manages user configuration on Ubuntu in WSL with chezmoi.
NixOS and Home Manager configuration has been replaced with Ubuntu package
installation and normal dotfiles.

## Layout

```text
chezmoi.toml.tmpl                 # First-run profile and Git identity prompts
.chezmoidata/packages.yaml        # Ubuntu APT package list
run_onchange_before_*.sh.tmpl     # Install APT packages when the list changes
dot_zshenv.tmpl                  # XDG paths, ZDOTDIR, and selected profile
dot_config/zsh/                  # Login and interactive Zsh startup files
dot_config/git/config.tmpl       # Shared Git settings and profile identity
dot_config/starship.toml.tmpl    # Personal or Twinkl prompt theme
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

The apply step runs the Ubuntu APT package script when its package list changes.
It uses `sudo` for APT and skips packages that are not present in the configured
Ubuntu repositories. Set Zsh as the WSL user's login shell once with:

```sh
sudo chsh -s "$(command -v zsh)" "$USER"
```

## Profiles

The local file `~/.config/chezmoi/chezmoi.toml` contains `data.profile`,
`data.gitName`, and `data.gitEmail`. Set `data.profile` to `personal` or
`twinkl`; shared templates use that value for Git and Starship configuration.
For Twinkl SSH signing, set `data.gitSigningKey` to the public key path. Keep
private keys and other secrets outside this repository.

The APT list contains shared shell and CLI dependencies. Applications that use
vendor-specific installers (for example Bun, dust, fnm, pnpm, Obsidian, xh,
vimgolf, Herdr, .NET/Godot, Antigravity CLI, AWS Vault, and Claude Code) need
their Ubuntu installation source added separately before they can be
automated here. `chezmoi apply` does not remove packages when a profile changes.

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
