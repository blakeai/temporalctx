#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

if [[ $# -gt 1 ]]; then
  echo "Usage: ./install.sh [target-directory]" >&2
  exit 1
fi

default_target_base="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"
if [[ $# -eq 1 ]]; then
  user_target="$1"
  if [[ "$(basename "$user_target")" == "temporalctx" ]]; then
    target_dir="$user_target"
  else
    target_dir="$user_target/temporalctx"
  fi
else
  target_dir="$default_target_base/temporalctx"
fi

mkdir -p "$(dirname "$target_dir")"

if [[ -e "$target_dir" || -L "$target_dir" ]]; then
  if [[ -L "$target_dir" ]]; then
    symlink_target="$(readlink "$target_dir" || true)"
    if [[ -z "$symlink_target" ]]; then
      echo "Target symlink is unreadable: $target_dir" >&2
      exit 1
    fi
  elif [[ -d "$target_dir/.git" ]]; then
    :
  else
    echo "Target exists and is not a temporalctx plugin checkout/symlink: $target_dir" >&2
    exit 1
  fi
else
  if ln -s "$REPO_DIR" "$target_dir" 2>/dev/null; then
    echo "Linked plugin at $target_dir -> $REPO_DIR"
  else
    remote_url="$(git -C "$REPO_DIR" config --get remote.origin.url || true)"
    if [[ -z "$remote_url" ]]; then
      echo "Could not symlink and no git remote found for cloning." >&2
      exit 1
    fi
    git clone "$remote_url" "$target_dir"
    echo "Cloned plugin to $target_dir"
  fi
fi

config_file="${TEMPORAL_CONFIG:-$HOME/.temporal/config}"
mkdir -p "$(dirname "$config_file")"
if [[ ! -f "$config_file" ]]; then
  cat > "$config_file" <<'YAML'
current-context: local

contexts:
  local:
    address: localhost:7233
    namespace: default
    tls: false
YAML
  echo "Created default config at $config_file"
else
  echo "Config already exists at $config_file"
fi

echo
echo "Installation complete."
echo "Add temporalctx to your Oh My Zsh plugins list, for example:"
echo "  plugins=(... temporalctx)"
echo "Then reload your shell:"
echo "  source ~/.zshrc"
