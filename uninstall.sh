#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: ./uninstall.sh [--full] [--purge-config] [target-directory]" >&2
}

full_mode=0
purge_config=0
user_target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)
      full_mode=1
      shift
      ;;
    --purge-config)
      purge_config=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$user_target" ]]; then
        usage
        exit 1
      fi
      user_target="$1"
      shift
      ;;
  esac
done

default_target_base="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"
if [[ -n "$user_target" ]]; then
  if [[ "$(basename "$user_target")" == "temporalctx" ]]; then
    target_dir="$user_target"
  else
    target_dir="$user_target/temporalctx"
  fi
else
  target_dir="$default_target_base/temporalctx"
fi

config_file="${TEMPORAL_CONFIG:-$HOME/.temporal/config.yml}"
config_dir="$(dirname "$config_file")"

if [[ -L "$target_dir" ]]; then
  unlink "$target_dir"
  echo "Removed plugin symlink at $target_dir"
elif [[ -d "$target_dir/.git" ]]; then
  rm -rf "$target_dir"
  echo "Removed plugin directory at $target_dir"
elif [[ -e "$target_dir" ]]; then
  echo "Refusing to remove non-plugin path: $target_dir" >&2
  exit 1
else
  echo "Plugin path not found: $target_dir"
fi

zshc_dir="${ZSHC:-$HOME/.config/zsh}"
helper_target="$zshc_dir/temporal.zsh"
if [[ -L "$helper_target" ]]; then
  link_target="$(readlink "$helper_target" || true)"
  if [[ "$link_target" == *"/temporalctx/temporalctx.full.zsh" ]]; then
    unlink "$helper_target"
    echo "Removed opinionated helper link at $helper_target"
  else
    echo "Skipped helper link at $helper_target (does not point to temporalctx.full.zsh)"
  fi
fi

for state_file in "$config_dir/.temporalctx-previous" "$config_dir/temporal-dev-server.pid" "$config_dir/overmind.sock"; do
  if [[ -e "$state_file" || -L "$state_file" ]]; then
    unlink "$state_file" 2>/dev/null || rm -f "$state_file"
    echo "Removed state file $state_file"
  fi
done

if [[ "$purge_config" == "1" ]]; then
  if [[ -f "$config_file" ]]; then
    unlink "$config_file"
    echo "Removed config file $config_file"
  fi
fi

echo
if [[ "$purge_config" == "1" ]]; then
  echo "Uninstall complete. Plugin and config were removed."
else
  echo "Uninstall complete. Plugin removed; config kept at $config_file"
fi
