#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

command -v zsh >/dev/null 2>&1 || fail "zsh is required for plugin tests"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# Test: defaults and explicit context switching + previous toggle.
cfg="$tmp_root/config.yml"
cat > "$cfg" <<'YAML'
current-context: local

contexts:
  local:
    address: localhost:7233
    namespace: default
    tls: false
  ss-prod:
    address: us-west-2.aws.api.temporal.io:7233
    namespace: spend-sentry-prod.ofkkt
    tls: true
    api-key: ${TEMPORAL_SS_PROD_API_KEY}
YAML

out="$(TEMPORAL_CONFIG="$cfg" TEMPORAL_SS_PROD_API_KEY=sekret zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "c1=$(temporalctx -c)"
  echo "s1=$(temporalctx ss-prod)"
  echo "c2=$(temporalctx -c)"
  echo "flags=$(_temporal_flags)"
  echo "s2=$(temporalctx -)"
  echo "c3=$(temporalctx -c)"
')"

assert_contains "$out" "c1=local" "current context should start at local"
assert_contains "$out" "s1=ss-prod" "switch should output target context"
assert_contains "$out" "c2=ss-prod" "current context should switch"
assert_contains "$out" "--address us-west-2.aws.api.temporal.io:7233" "flags should include address"
assert_contains "$out" "--namespace spend-sentry-prod.ofkkt" "flags should include namespace"
assert_contains "$out" "--tls" "flags should include tls"
assert_contains "$out" "--api-key sekret" "flags should include resolved api key"
assert_contains "$out" "s2=local" "dash should switch back"
assert_contains "$out" "c3=local" "current context should be previous"

# Test: interactive temporalctx (no args) uses fzf chooser result.
mkdir -p "$tmp_root/bin"
cat > "$tmp_root/bin/fzf" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf 'ss-prod\n'
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

assert_contains "$out" "pick=ss-prod" "interactive picker should switch to fzf-selected context"
assert_contains "$out" "curr=ss-prod" "current context should match picker result"

# Test: temporal command wrapping + opt-out.
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" TEMPORAL_SS_PROD_API_KEY=sekret zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "wrapped=$(temporal workflow list --limit 5)"
  echo "raw=$(TEMPORALCTX_DISABLE_WRAP=1 temporal workflow list --limit 5)"
')"
assert_contains "$out" "wrapped=ARGS: --address us-west-2.aws.api.temporal.io:7233 --namespace spend-sentry-prod.ofkkt --tls --api-key sekret workflow list --limit 5" "temporal wrapper should prepend context flags"
assert_contains "$out" "raw=ARGS: workflow list --limit 5" "opt-out env var should bypass wrapping"

echo "PASS: temporalctx.plugin.zsh"
