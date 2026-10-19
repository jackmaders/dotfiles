#!/usr/bin/env bash
set -euo pipefail

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot detect operating system; cannot install Ubuntu tools." >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
  echo "This setup targets Ubuntu (found ${ID:-unknown}); refusing to continue." >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is unavailable; cannot install tools." >&2
  exit 1
fi

# Starship
(
  starship_install_dir="$HOME/.local/bin"
  starship_binary="$starship_install_dir/starship"
  export PATH="$starship_install_dir:$PATH"

  # Reuse working installations, including the official installer's /usr/local/bin.
  if command -v starship >/dev/null 2>&1 && starship --version >/dev/null 2>&1; then
    exit 0
  fi

  mkdir -p -- "$starship_install_dir"
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$starship_install_dir"

  if [[ ! -x "$starship_binary" ]]; then
    echo "The Starship installer did not create an executable at $starship_binary." >&2
    exit 1
  fi

  "$starship_binary" --version >/dev/null
)

# Vite+ manages Node.js and package managers, including pnpm and Bun.
(
  vp_binary="${VP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/vite-plus}/bin/vp"
  if [[ ! -x "$vp_binary" ]] || ! "$vp_binary" --version >/dev/null 2>&1; then
    curl -fsSL https://vite.plus | VP_NODE_MANAGER=yes bash
  fi

  vp_env="${VP_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/vite-plus}/env"
  if [[ ! -x "$vp_binary" ]] || [[ ! -r "$vp_env" ]]; then
    echo "The Vite+ installer did not create $vp_binary and $vp_env." >&2
    exit 1
  fi
  source "$vp_env"

  # Keep the latest LTS as the default; project versions resolve through shims.
  "$vp_binary" env on
  "$vp_binary" env install lts
  "$vp_binary" env default lts

  # Global packages live in Vite+, independently of fnm and system npm.
  if [[ ! -x "${vp_binary%/vp}/codex" ]] || ! "${vp_binary%/vp}/codex" --version >/dev/null 2>&1; then
    "$vp_binary" install --global --node lts @openai/codex
  fi

  "${vp_binary%/vp}/codex" --version >/dev/null
)

# Herdr
(
  curl -fsSL https://herdr.dev/install.sh | sh

  herdr_binary="$HOME/.local/bin/herdr"
  if [[ ! -x "$herdr_binary" ]]; then
    echo "The Herdr installer did not create an executable at $herdr_binary." >&2
    exit 1
  fi
)

# Claude Code
(
  claude_binary="$HOME/.local/bin/claude"
  if [[ -x "$claude_binary" ]] && "$claude_binary" --version >/dev/null 2>&1; then
    exit 0
  fi

  curl -fsSL https://claude.ai/install.sh | bash

  if [[ ! -x "$claude_binary" ]]; then
    echo "The Claude Code installer did not create an executable at $claude_binary." >&2
    exit 1
  fi

  "$claude_binary" --version >/dev/null
)

# Antigravity CLI
(
  # The installer defaults to ~/.local/bin, which the dotfiles already add to
  # PATH. The CLI updates itself during normal use after its initial install.
  curl -fsSL https://antigravity.google/cli/install.sh | bash

  agy_binary="$HOME/.local/bin/agy"
  if [[ ! -x "$agy_binary" ]]; then
    echo "The Antigravity CLI installer did not create an executable at $agy_binary." >&2
    exit 1
  fi

  # Herdr requires this directory before installing its antigravity-cli hooks.
  mkdir -p "$HOME/.gemini/config"
)

# Hunk
(
  export HUNK_NO_MODIFY_PATH=1
  curl -fsSL https://hunk.dev/install.sh | sh

  hunk_binary="$HOME/.hunk/bin/hunk"
  if [[ ! -x "$hunk_binary" ]]; then
    echo "The Hunk installer did not create an executable at $hunk_binary." >&2
    exit 1
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sf "$hunk_binary" "$HOME/.local/bin/hunk"

  "$HOME/.local/bin/hunk" --version >/dev/null
)

# Obsidian
(
  case "$(dpkg --print-architecture)" in
    amd64) ;;
    *)
      echo "The official Obsidian .deb installer is available for amd64; found $(dpkg --print-architecture)." >&2
      exit 1
      ;;
  esac

  download_dir="$(mktemp -d)"
  cleanup() {
    rm -rf -- "$download_dir"
  }
  trap cleanup EXIT

  release_metadata="$download_dir/desktop-releases.json"
  curl --fail --location --silent --show-error \
    https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/desktop-releases.json \
    --output "$release_metadata"

  release_version="$(sed -n 's/^[[:space:]]*"latestVersion":[[:space:]]*"\([^"]*\)".*/\1/p' "$release_metadata" | head -n 1)"
  if [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Could not read a stable Obsidian desktop version from the official release metadata." >&2
    exit 1
  fi

  download_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${release_version}/obsidian_${release_version}_amd64.deb"
  deb_file="$download_dir/obsidian.deb"
  curl --fail --location --silent --show-error "$download_url" --output "$deb_file"
  if ! dpkg-deb --info "$deb_file" >/dev/null 2>&1; then
    echo "The Obsidian download did not contain a valid Debian package." >&2
    exit 1
  fi

  if (( EUID == 0 )); then
    apt_get=(apt-get)
  else
    if ! command -v sudo >/dev/null 2>&1; then
      echo "sudo is required to install Obsidian." >&2
      exit 1
    fi
    apt_get=(sudo apt-get)
  fi

  "${apt_get[@]}" install --yes --no-install-recommends "$deb_file"

  if ! command -v obsidian >/dev/null 2>&1; then
    echo "The Obsidian .deb package did not install the obsidian command." >&2
    exit 1
  fi
)

# Verify command discovery on every apply, even when APT's list is unchanged.
source "${VP_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/vite-plus}/env"
export PATH="$HOME/.hunk/bin:$HOME/.local/bin:$PATH"
for required_command in vp node codex chezmoi herdr claude agy hunk obsidian direnv zoxide starship clear rg eza; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Required command '$required_command' is unavailable after installation." >&2
    exit 1
  fi
done
if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1; then
  echo "Required command 'bat or batcat' is unavailable; expected the bat package." >&2
  exit 1
fi
if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  echo "Required command 'fd or fdfind' is unavailable; expected the fd-find package." >&2
  exit 1
fi
