#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
section "uninstaller tests"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
log "temp workspace: $tmp_root"

# Fake temporal binary for install prerequisites.
mkdir -p "$tmp_root/bin"
cat > "$tmp_root/bin/temporal" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$tmp_root/bin/temporal"

# Case: default uninstall removes plugin and state but keeps config.
log "case: default uninstall keeps config"
home1="$tmp_root/home1"
custom1="$tmp_root/custom1"
mkdir -p "$home1" "$custom1"
PATH="$tmp_root/bin:$PATH" HOME="$home1" ZSH_CUSTOM="$custom1" "$REPO_ROOT/install.sh" >"$tmp_root/i1.out" 2>"$tmp_root/i1.err"
[[ -e "$custom1/plugins/temporalctx" ]] || fail "plugin should be installed"
[[ -f "$home1/.temporal/config.yml" ]] || fail "config should exist after install"
: > "$home1/.temporal/.temporalctx-previous"
: > "$home1/.temporal/temporal-dev-server.pid"
: > "$home1/.temporal/overmind.sock"
HOME="$home1" ZSH_CUSTOM="$custom1" "$REPO_ROOT/uninstall.sh" >"$tmp_root/u1.out" 2>"$tmp_root/u1.err"
[[ ! -e "$custom1/plugins/temporalctx" ]] || fail "plugin path should be removed"
[[ -f "$home1/.temporal/config.yml" ]] || fail "config should be kept by default"
[[ ! -e "$home1/.temporal/.temporalctx-previous" ]] || fail "previous state should be removed"
[[ ! -e "$home1/.temporal/temporal-dev-server.pid" ]] || fail "pid state should be removed"
[[ ! -e "$home1/.temporal/overmind.sock" ]] || fail "overmind socket state should be removed"
log "case passed: default uninstall keeps config"

# Case: --purge-config removes config file.
log "case: --purge-config removes config"
home2="$tmp_root/home2"
custom2="$tmp_root/custom2"
mkdir -p "$home2" "$custom2"
PATH="$tmp_root/bin:$PATH" HOME="$home2" ZSH_CUSTOM="$custom2" "$REPO_ROOT/install.sh" >"$tmp_root/i2.out" 2>"$tmp_root/i2.err"
[[ -f "$home2/.temporal/config.yml" ]] || fail "config should exist before purge"
HOME="$home2" ZSH_CUSTOM="$custom2" "$REPO_ROOT/uninstall.sh" --purge-config >"$tmp_root/u2.out" 2>"$tmp_root/u2.err"
[[ ! -f "$home2/.temporal/config.yml" ]] || fail "config should be removed with --purge-config"
log "case passed: purge config"

# Case: --full also removes plugin-managed temporal.zsh link.
log "case: --full removes helper link"
home3="$tmp_root/home3"
custom3="$tmp_root/custom3"
zshc3="$tmp_root/zshc3"
mkdir -p "$home3" "$custom3" "$zshc3"
PATH="$tmp_root/bin:$PATH" HOME="$home3" ZSH_CUSTOM="$custom3" ZSHC="$zshc3" "$REPO_ROOT/install.sh" --full >"$tmp_root/i3.out" 2>"$tmp_root/i3.err"
[[ -L "$zshc3/temporal.zsh" ]] || fail "--full should create helper symlink"
HOME="$home3" ZSH_CUSTOM="$custom3" ZSHC="$zshc3" "$REPO_ROOT/uninstall.sh" --full >"$tmp_root/u3.out" 2>"$tmp_root/u3.err"
[[ ! -e "$zshc3/temporal.zsh" ]] || fail "--full uninstall should remove helper symlink"
log "case passed: full helper removal"

echo "PASS: uninstall.sh"
