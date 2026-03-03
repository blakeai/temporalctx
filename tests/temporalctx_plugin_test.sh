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
if [[ "${1:-}" == "server" && "${2:-}" == "start-dev" ]]; then
  trap 'exit 0' TERM INT
  while true; do
    sleep 1
  done
fi
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

# Test: edit subcommand opens config in VISUAL/EDITOR.
log "case: edit subcommand opens config with VISUAL/EDITOR"
cat > "$tmp_root/bin/editor-visual" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${TMP_EDITOR_VISUAL_LOG:?}"
SH
cat > "$tmp_root/bin/editor-fallback" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${TMP_EDITOR_FALLBACK_LOG:?}"
SH
chmod +x "$tmp_root/bin/editor-visual" "$tmp_root/bin/editor-fallback"

visual_log="$tmp_root/visual.log"
fallback_log="$tmp_root/fallback.log"
PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" VISUAL="$tmp_root/bin/editor-visual" EDITOR="$tmp_root/bin/editor-fallback" TMP_EDITOR_VISUAL_LOG="$visual_log" TMP_EDITOR_FALLBACK_LOG="$fallback_log" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  temporalctx edit
'
[[ -f "$visual_log" ]] || fail "VISUAL editor should be invoked by edit subcommand"
visual_args="$(cat "$visual_log")"
assert_contains "$visual_args" "$cfg" "editor should receive config file path"
[[ ! -f "$fallback_log" ]] || fail "EDITOR fallback should not run when VISUAL is set"
log "case passed: edit subcommand"

# Test: help output via subcommand and flag.
log "case: help output"
out="$(TEMPORAL_CONFIG="$cfg" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "-- help --"
  temporalctx help
  echo "-- --help --"
  temporalctx --help
')"
assert_contains "$out" "Usage:" "help output should include usage header"
assert_contains "$out" "temporalctx <context>" "help output should describe context switching"
assert_contains "$out" "temporalctx help" "help output should describe help command"
log "case passed: help output"

# Test: alias + local dev server start/stop via PID file.
log "case: tctx alias and local dev server lifecycle"
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "alias_current=$(tctx -c)"
  start_out="$(temporalctx start --no-overmind)"
  pid_file="${TEMPORAL_CONFIG:h}/temporal-dev-server.pid"
  [[ -f "$pid_file" ]] || exit 22
  pid="$(<"$pid_file")"
  kill -0 "$pid"
  stop_out="$(temporalctx stop --no-overmind)"
  echo "start=${start_out}"
  echo "stop=${stop_out}"
  echo "pid_file_exists=$([[ -f "$pid_file" ]] && echo yes || echo no)"
')"
assert_contains "$out" "alias_current=cloud-prod" "tctx alias should call temporalctx"
assert_contains "$out" "start=started local dev server (pid " "start should report pid"
assert_contains "$out" "stop=stopped local dev server (pid " "stop should report pid"
assert_contains "$out" "pid_file_exists=no" "stop should remove pid file"
log "case passed: alias and local dev server lifecycle"

# Test: overmind path when available, and --no-overmind fallback.
log "case: overmind start/stop and --no-overmind fallback"
cat > "$tmp_root/bin/overmind" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
case "$cmd" in
  start)
    : "${OVERMIND_SOCKET:?OVERMIND_SOCKET required}"
    : > "$OVERMIND_SOCKET"
    exit 0
    ;;
  status)
    : "${OVERMIND_SOCKET:?OVERMIND_SOCKET required}"
    [[ -e "$OVERMIND_SOCKET" ]] || exit 1
    printf 'temporal\trunning\n'
    exit 0
    ;;
  echo)
    : "${OVERMIND_SOCKET:?OVERMIND_SOCKET required}"
    [[ -e "$OVERMIND_SOCKET" ]] || exit 1
    printf 'temporal | fake log line\n'
    exit 0
    ;;
  quit)
    : "${OVERMIND_SOCKET:?OVERMIND_SOCKET required}"
    rm -f -- "$OVERMIND_SOCKET"
    exit 0
    ;;
  *)
    echo "unexpected overmind command: $cmd" >&2
    exit 1
    ;;
esac
SH
chmod +x "$tmp_root/bin/overmind"

out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  sock="${TEMPORAL_CONFIG:h}/overmind.sock"
  echo "start_om=$(temporalctx start)"
  [[ -e "$sock" ]] || exit 31
  echo "stop_om=$(temporalctx stop)"
  echo "sock_exists=$([[ -e "$sock" ]] && echo yes || echo no)"
  echo "start_no_om=$(temporalctx start --no-overmind)"
  pid_file="${TEMPORAL_CONFIG:h}/temporal-dev-server.pid"
  [[ -f "$pid_file" ]] || exit 32
  echo "stop_no_om=$(temporalctx stop --no-overmind)"
')"
assert_contains "$out" "start_om=started local dev server via overmind" "start should use overmind when available"
assert_contains "$out" "stop_om=stopped local dev server via overmind" "stop should use overmind when available"
assert_contains "$out" "sock_exists=no" "overmind stop should clear socket"
assert_contains "$out" "start_no_om=started local dev server (pid " "--no-overmind should force pid mode start"
assert_contains "$out" "stop_no_om=stopped local dev server (pid " "--no-overmind should force pid mode stop"
log "case passed: overmind and --no-overmind"

# Test: status and logs subcommands.
log "case: status and logs subcommands"
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "status_down=$(temporalctx status 2>&1)"
  echo "logs_down=$(temporalctx logs 2>&1)"
  temporalctx start >/dev/null
  echo "status_up=$(temporalctx status 2>&1)"
  echo "logs_up=$(temporalctx logs 2>&1)"
  temporalctx stop >/dev/null
')"
assert_contains "$out" "status_down=temporalctx: local dev server not running" "status should report not running when stopped"
assert_contains "$out" "logs_down=temporalctx: local dev server not running" "logs should report not running when stopped"
assert_contains "$out" "status_up=temporal" "status should show process info when running"
assert_contains "$out" "logs_up=temporal | fake log line" "logs should show output when running"
log "case passed: status and logs subcommands"

# Test: temporal command wrapping + opt-out.
log "case: temporal wrapper injects flags and supports opt-out"
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" TEMPORAL_CLOUD_PROD_API_KEY=sekret zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "wrapped=$(temporal workflow list --limit 5)"
  echo "raw=$(TEMPORALCTX_DISABLE_WRAP=1 temporal workflow list --limit 5)"
')"
assert_contains "$out" "wrapped=ARGS: workflow --address us-west-2.aws.api.temporal.io:7233 --namespace example-prod.a1b2c --tls --api-key sekret list --limit 5" "temporal wrapper should inject context flags after top-level command"
assert_contains "$out" "raw=ARGS: workflow list --limit 5" "opt-out env var should bypass wrapping"
log "case passed: temporal wrapper"

# Test: missing context fields do not emit empty-value flags.
log "case: missing context fields do not emit empty flags"
cfg_missing="$tmp_root/config-missing.yml"
cat > "$cfg_missing" <<'YAML'
current-context: bare

contexts:
  bare:
    namespace: only-namespace
YAML
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg_missing" zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "wrapped=$(temporal workflow list --limit 1)"
')"
assert_contains "$out" "wrapped=ARGS: workflow --namespace only-namespace list --limit 1" "wrapper should include only populated flags"
[[ "$out" != *"--address  "* ]] || fail "wrapper should not pass empty address"
[[ "$out" != *"--api-key  "* ]] || fail "wrapper should not pass empty api key"
log "case passed: missing context fields"

# Test: env placeholders do not loop on self-referential exports.
log "case: self-referential env values do not hang"
out="$(PATH="$tmp_root/bin:$PATH" TEMPORAL_CONFIG="$cfg" TEMPORAL_CLOUD_PROD_API_KEY='${TEMPORAL_CLOUD_PROD_API_KEY}' zsh -c '
  source "'$REPO_ROOT'/temporalctx.plugin.zsh"
  echo "flags=$(_temporal_flags)"
')"
assert_contains "$out" "flags=--address us-west-2.aws.api.temporal.io:7233 --namespace example-prod.a1b2c --tls --api-key" "resolver should return without looping on self-referential env values"
log "case passed: self-referential env values"

echo "PASS: temporalctx.plugin.zsh"
