#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
section "installer tests"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
log "temp workspace: $tmp_root"

# Test: installer fails fast when temporal CLI is missing.
log "case: missing temporal CLI fails fast"
if PATH="/usr/bin:/bin" "$REPO_ROOT/install.sh" >"$tmp_root/out" 2>"$tmp_root/err"; then
  fail "install.sh should fail when temporal CLI is missing"
fi
err_text="$(cat "$tmp_root/err")"
assert_contains "$err_text" "temporal CLI is required" "installer should explain missing CLI"
log "case passed: missing temporal CLI fails"

# Fake temporal binary for success cases.
mkdir -p "$tmp_root/bin"
cat > "$tmp_root/bin/temporal" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$tmp_root/bin/temporal"

# Test: default target uses ZSH_CUSTOM/plugins/temporalctx.
log "case: default target uses ZSH_CUSTOM/plugins/temporalctx"
home1="$tmp_root/home1"
custom1="$tmp_root/custom1"
mkdir -p "$home1" "$custom1"
PATH="$tmp_root/bin:$PATH" HOME="$home1" ZSH_CUSTOM="$custom1" "$REPO_ROOT/install.sh" >"$tmp_root/install1.out" 2>"$tmp_root/install1.err"
[[ -L "$custom1/plugins/temporalctx" || -d "$custom1/plugins/temporalctx/.git" ]] || fail "default install should target ZSH_CUSTOM/plugins/temporalctx"
[[ -f "$home1/.temporal/config" ]] || fail "installer should create default config"
log "case passed: default target"

# Test: custom target dir appends /temporalctx when needed.
log "case: custom target appends /temporalctx"
home2="$tmp_root/home2"
mkdir -p "$home2"
custom_target="$tmp_root/alt-plugins"
PATH="$tmp_root/bin:$PATH" HOME="$home2" "$REPO_ROOT/install.sh" "$custom_target" >"$tmp_root/install2.out" 2>"$tmp_root/install2.err"
[[ -L "$custom_target/temporalctx" || -d "$custom_target/temporalctx/.git" ]] || fail "custom target should install to <dir>/temporalctx"
log "case passed: custom target"

echo "PASS: install.sh"
