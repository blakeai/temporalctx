#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

command -v zsh >/dev/null 2>&1 || fail "zsh is required for plugin tests"
section "temporalctx plugin tests"
log "zsh binary: $(command -v zsh)"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
log "temp workspace: $tmp_root"

# Test: defaults and explicit context switching + previous toggle.
log "case: switch context, print current, resolve flags, toggle previous"
cfg="$tmp_root/config.yml"
cat > "$cfg" <<'YAML'
current-context: local

contexts:
  local:
    address: localhost:7233
    namespace: default
    tls: false
  cloud-prod:
    address: us-west-2.aws.api.temporal.io:7233
    namespace: example-prod.a1b2c
    tls: true
    api-key: ${TEMPORAL_CLOUD_PROD_API_KEY}
YAML

out="$(TEMPORAL_CONFIG="$cfg" TEMPORAL_CLOUD_PROD_API_KEY=sekret zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "c1=$(temporalctx -c)"
  echo "s1=$(temporalctx cloud-prod)"
  echo "c2=$(temporalctx -c)"
  echo "flags=$(_temporal_flags)"
  echo "s2=$(temporalctx -)"
  echo "c3=$(temporalctx -c)"
')"

assert_contains "$out" "c1=local" "current context should start at local"
assert_contains "$out" "s1=cloud-prod" "switch should output target context"
assert_contains "$out" "c2=cloud-prod" "current context should switch"
assert_contains "$out" "--address us-west-2.aws.api.temporal.io:7233" "flags should include address"
assert_contains "$out" "--namespace example-prod.a1b2c" "flags should include namespace"
assert_contains "$out" "--tls" "flags should include tls"
assert_contains "$out" "--api-key sekret" "flags should include resolved api key"
assert_contains "$out" "s2=local" "dash should switch back"
assert_contains "$out" "c3=local" "current context should be previous"
log "case passed: switch/current/flags/previous"

# Test: interactive temporalctx (no args) uses fzf chooser result.
log "case: interactive picker uses fzf-selected context"
mkdir -p "$tmp_root/bin"
cat > "$tmp_root/bin/fzf" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf 'cloud-prod\n'
SH
cat > "$tmp_root/bin/temporal" <<'SH'
#!/usr/bin/env bash
printf 'ARGS:'
printf ' %s' "$@"
printf '\n'
SH
chmod +x "$tmp_root/bin/fzf" "$tmp_root/bin/temporal"

out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "pick=$(temporalctx)"
  echo "curr=$(temporalctx -c)"
')"

assert_contains "$out" "pick=cloud-prod" "interactive picker should switch to fzf-selected context"
assert_contains "$out" "curr=cloud-prod" "current context should match picker result"
log "case passed: interactive picker"

# Test: temporal command wrapping + opt-out.
log "case: temporal wrapper injects flags and supports opt-out"
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" TEMPORAL_CLOUD_PROD_API_KEY=sekret zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "wrapped=$(temporal workflow list --limit 5)"
  echo "raw=$(TEMPORALCTX_DISABLE_WRAP=1 temporal workflow list --limit 5)"
')"
assert_contains "$out" "wrapped=ARGS: --address us-west-2.aws.api.temporal.io:7233 --namespace example-prod.a1b2c --tls --api-key sekret workflow list --limit 5" "temporal wrapper should prepend context flags"
assert_contains "$out" "raw=ARGS: workflow list --limit 5" "opt-out env var should bypass wrapping"
log "case passed: temporal wrapper"

echo "PASS: temporalctx.plugin.zsh"
