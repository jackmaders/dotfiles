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

# fnm is supplied by the pinned executable archive in .chezmoiexternal.toml.
fnm_binary="$HOME/.local/bin/fnm"
if [[ ! -x "$fnm_binary" ]] || [[ "$("$fnm_binary" --version)" != "fnm 1.39.0" ]]; then
  echo "Expected fnm 1.39.0 at $fnm_binary." >&2
  exit 1
fi

# Node.js, Codex, and pnpm
(
  export PATH="$HOME/.local/bin:$PATH"

  # Keep the latest LTS installed and use it as the default Node.js version.
  "$fnm_binary" install --lts
  node_version="$("$fnm_binary" exec --using=lts/latest node -p 'process.versions.node')"
  "$fnm_binary" default "$node_version"

  # Run npm through fnm so a Windows Node on the WSL PATH cannot own this install.
  if ! "$fnm_binary" exec --using="$node_version" npm list --global --depth=0 @openai/codex >/dev/null 2>&1; then
    "$fnm_binary" exec --using="$node_version" npm install --global @openai/codex
  fi

  if ! "$fnm_binary" exec --using="$node_version" npm list --global --depth=0 pnpm >/dev/null 2>&1; then
    "$fnm_binary" exec --using="$node_version" npm install --global pnpm
  fi

  "$fnm_binary" exec --using="$node_version" codex --version >/dev/null
  "$fnm_binary" exec --using="$node_version" pnpm --version >/dev/null
)

# Bun
(
  bun_install_dir="${BUN_INSTALL:-$HOME/.bun}"
  bun_binary="$bun_install_dir/bin/bun"
  if [[ -x "$bun_binary" ]] && "$bun_binary" --version >/dev/null 2>&1; then
    exit 0
  fi

  export BUN_INSTALL="$bun_install_dir"
  curl -fsSL https://bun.sh/install | bash

  if [[ ! -x "$bun_binary" ]]; then
    echo "The Bun installer did not create an executable at $bun_binary." >&2
    exit 1
  fi

  "$bun_binary" --version >/dev/null
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
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"
for required_command in fnm chezmoi bun herdr claude agy obsidian direnv zoxide starship clear rg eza; do
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
