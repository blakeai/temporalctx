# temporalctx oh-my-zsh plugin
# Switch between Temporal contexts defined in ~/.temporal/config.yml.

typeset -g _TEMPORALCTX_PLUGIN_DIR="${${(%):-%x}:A:h}"

_temporalctx_config_file() {
  if [[ -n "$TEMPORAL_CONFIG" ]]; then
    print -r -- "$TEMPORAL_CONFIG"
  else
    print -r -- "$HOME/.temporal/config.yml"
  fi
}

_temporalctx_previous_file() {
  local config_file
  config_file="$(_temporalctx_config_file)"
  print -r -- "${config_file:h}/.temporalctx-previous"
}

_temporalctx_pid_file() {
  local config_file
  config_file="$(_temporalctx_config_file)"
  print -r -- "${config_file:h}/temporal-dev-server.pid"
}

_temporalctx_overmind_socket() {
  local config_file
  config_file="$(_temporalctx_config_file)"
  print -r -- "${config_file:h}/overmind.sock"
}

_temporalctx_procfile() {
  print -r -- "${_TEMPORALCTX_PLUGIN_DIR}/Procfile"
}

_temporalctx_default_config() {
  cat <<'YAML'
current-context: local

contexts:
  local:
    address: localhost:7233
    namespace: default
    tls: false
YAML
}

_temporalctx_ensure_config() {
  local config_file
  config_file="$(_temporalctx_config_file)"

  mkdir -p -- "${config_file:h}"
  if [[ ! -f "$config_file" ]]; then
    _temporalctx_default_config > "$config_file"
  fi
}

_temporalctx_list_contexts() {
  local config_file
  config_file="$(_temporalctx_config_file)"

  awk '
    /^contexts:[[:space:]]*$/ { in_contexts=1; next }
    in_contexts {
      if ($0 ~ /^[^[:space:]]/) exit
      if ($0 ~ /^  [A-Za-z0-9._-]+:[[:space:]]*$/) {
        name = $0
        sub(/^  /, "", name)
        sub(/:[[:space:]]*$/, "", name)
        print name
      }
    }
  ' "$config_file"
}

_temporalctx_current_context() {
  local config_file
  config_file="$(_temporalctx_config_file)"

  awk '
    /^current-context:[[:space:]]*/ {
      sub(/^current-context:[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$config_file"
}

_temporalctx_context_field() {
  local ctx="$1"
  local key="$2"
  local config_file
  config_file="$(_temporalctx_config_file)"

  awk -v ctx="$ctx" -v key="$key" '
    /^contexts:[[:space:]]*$/ { in_contexts=1; next }
    in_contexts {
      if ($0 ~ /^[^[:space:]]/) exit
      if ($0 ~ /^  [A-Za-z0-9._-]+:[[:space:]]*$/) {
        name = $0
        sub(/^  /, "", name)
        sub(/:[[:space:]]*$/, "", name)
        in_ctx = (name == ctx)
        next
      }
      if (in_ctx && $0 ~ /^    [A-Za-z0-9._-]+:[[:space:]]*/) {
        line = $0
        sub(/^    /, "", line)
        split(line, parts, ":")
        field = parts[1]
        value = substr(line, length(field) + 2)
        if (field != key) next
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$config_file"
}

_temporalctx_unquote() {
  local value="$1"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value#\"}"
    value="${value%\"}"
  elif [[ "$value" == \''*\' && "$value" == *\' ]]; then
    value="${value#\'}"
    value="${value%\'}"
  fi
  print -r -- "$value"
}

_temporalctx_resolve_value() {
  local value="$1"
  printf '%s\n' "$value" | awk '
    {
      s = $0
      out = ""
      pos = 1
      while (match(substr(s, pos), /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
        mstart = pos + RSTART - 1
        out = out substr(s, pos, mstart - pos)
        var = substr(s, mstart + 2, RLENGTH - 3)
        out = out ENVIRON[var]
        pos = mstart + RLENGTH
      }
      print out substr(s, pos)
    }
  '
}

_temporalctx_context_exists() {
  local ctx="$1"
  _temporalctx_list_contexts | awk -v ctx="$ctx" '$0 == ctx { found=1 } END { exit(found ? 0 : 1) }'
}

_temporalctx_set_current_context() {
  local new_ctx="$1"
  local config_file tmp_file
  config_file="$(_temporalctx_config_file)"
  tmp_file="$(mktemp)" || return 1

  awk -v ctx="$new_ctx" '
    BEGIN { updated=0 }
    /^current-context:[[:space:]]*/ {
      print "current-context: " ctx
      updated=1
      next
    }
    { print }
    END {
      if (!updated) {
        print "current-context: " ctx
      }
    }
  ' "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
}

_temporalctx_switch() {
  local target="$1"
  local current prev_file
  current="$(_temporalctx_current_context)"

  if ! _temporalctx_context_exists "$target"; then
    print -u2 -- "temporalctx: context '$target' not found"
    return 1
  fi

  if [[ "$current" == "$target" ]]; then
    print -r -- "$target"
    return 0
  fi

  prev_file="$(_temporalctx_previous_file)"
  if [[ -n "$current" ]]; then
    print -r -- "$current" > "$prev_file"
  fi

  _temporalctx_set_current_context "$target" || return 1
  print -r -- "$target"
}

_temporalctx_pick_context() {
  local contexts current selected current_line

  if ! command -v fzf >/dev/null 2>&1; then
    print -u2 -- "temporalctx: fzf is required for interactive selection"
    return 1
  fi

  contexts="$(_temporalctx_list_contexts)"
  if [[ -z "$contexts" ]]; then
    print -u2 -- "temporalctx: no contexts found in $(_temporalctx_config_file)"
    return 1
  fi

  current="$(_temporalctx_current_context)"
  current_line="$(printf '%s\n' "$contexts" | awk -v c="$current" '$0 == c { print NR; exit }')"

  if [[ -n "$current_line" ]]; then
    selected="$(printf '%s\n' "$contexts" | fzf --prompt='temporalctx> ' --height=40% --reverse --border --bind "start:pos(${current_line})")"
  else
    selected="$(printf '%s\n' "$contexts" | fzf --prompt='temporalctx> ' --height=40% --reverse --border)"
  fi

  [[ -n "$selected" ]] || return 1
  _temporalctx_switch "$selected"
}

_temporalctx_edit_config() {
  local config_file editor_cmd
  config_file="$(_temporalctx_config_file)"
  editor_cmd="${VISUAL:-${EDITOR:-vi}}"
  ${=editor_cmd} "$config_file"
}

_temporalctx_help() {
  cat <<'EOF'
Usage:
  temporalctx              interactive picker (fzf)
  temporalctx <context>    switch to context
  temporalctx -            switch to previous context
  temporalctx -c           print current context
  temporalctx edit         open config in $VISUAL/$EDITOR
  temporalctx start        start local dev server
  temporalctx stop         stop local dev server
  temporalctx help         show this help
EOF
}

_temporalctx_start_local_server() {
  local no_overmind pid_file pid socket procfile
  no_overmind="${1:-0}"

  if [[ "$no_overmind" != "1" ]] && command -v overmind >/dev/null 2>&1; then
    socket="$(_temporalctx_overmind_socket)"
    procfile="$(_temporalctx_procfile)"
    if [[ ! -f "$procfile" ]]; then
      print -u2 -- "temporalctx: Procfile not found at $procfile"
      return 1
    fi
    OVERMIND_SOCKET="$socket" overmind start -f "$procfile" -D >/dev/null 2>&1 || return 1
    print -r -- "started local dev server via overmind"
    return 0
  fi

  pid_file="$(_temporalctx_pid_file)"

  if [[ -f "$pid_file" ]]; then
    pid="$(<"$pid_file")"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      print -u2 -- "temporalctx: local dev server already running (pid $pid)"
      return 1
    fi
    rm -f -- "$pid_file"
  fi

  if [[ -z "$(whence -p temporal)" ]]; then
    print -u2 -- "temporalctx: temporal CLI not found in PATH"
    return 127
  fi

  command temporal server start-dev >/dev/null 2>&1 &
  pid="$!"
  print -r -- "$pid" > "$pid_file"
  print -r -- "started local dev server (pid $pid)"
}

_temporalctx_stop_local_server() {
  local no_overmind pid_file pid i socket
  no_overmind="${1:-0}"

  if [[ "$no_overmind" != "1" ]] && command -v overmind >/dev/null 2>&1; then
    socket="$(_temporalctx_overmind_socket)"
    if [[ ! -S "$socket" && ! -e "$socket" ]]; then
      print -u2 -- "temporalctx: local dev server not running"
      return 1
    fi
    OVERMIND_SOCKET="$socket" overmind quit >/dev/null 2>&1 || return 1
    print -r -- "stopped local dev server via overmind"
    return 0
  fi

  pid_file="$(_temporalctx_pid_file)"

  if [[ ! -f "$pid_file" ]]; then
    print -u2 -- "temporalctx: local dev server not running"
    return 1
  fi

  pid="$(<"$pid_file")"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
    rm -f -- "$pid_file"
    print -u2 -- "temporalctx: local dev server not running"
    return 1
  fi

  kill "$pid" >/dev/null 2>&1 || true
  for i in {1..20}; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  rm -f -- "$pid_file"
  print -r -- "stopped local dev server (pid $pid)"
}

typeset -ga _temporalctx_flags

_temporalctx_build_flags() {
  _temporalctx_ensure_config

  local current address namespace tls api_key
  _temporalctx_flags=()
  current="$(_temporalctx_current_context)"
  if [[ -z "$current" ]]; then
    return 0
  fi

  address="$(_temporalctx_unquote "$(_temporalctx_context_field "$current" "address")")"
  namespace="$(_temporalctx_unquote "$(_temporalctx_context_field "$current" "namespace")")"
  tls="$(_temporalctx_unquote "$(_temporalctx_context_field "$current" "tls")")"
  api_key="$(_temporalctx_unquote "$(_temporalctx_context_field "$current" "api-key")")"

  address="$(_temporalctx_resolve_value "$address")"
  namespace="$(_temporalctx_resolve_value "$namespace")"
  tls="$(_temporalctx_resolve_value "$tls")"
  api_key="$(_temporalctx_resolve_value "$api_key")"

  [[ -n "$address" ]] && _temporalctx_flags+=("--address" "$address")
  [[ -n "$namespace" ]] && _temporalctx_flags+=("--namespace" "$namespace")
  if [[ "${tls:l}" == "true" ]]; then
    _temporalctx_flags+=("--tls")
  fi
  [[ -n "$api_key" ]] && _temporalctx_flags+=("--api-key" "$api_key")
  return 0
}

_temporal_flags() {
  local token
  local -a rendered
  _temporalctx_build_flags || return 1

  rendered=()
  for token in "${_temporalctx_flags[@]}"; do
    rendered+=("$(printf '%q' "$token")")
  done
  print -r -- "${(j: :)rendered}"
}

temporal() {
  local subcommand

  if [[ "${TEMPORALCTX_DISABLE_WRAP:-}" == "1" ]]; then
    command temporal "$@"
    return $?
  fi

  if [[ -z "$(whence -p temporal)" ]]; then
    print -u2 -- "temporalctx: temporal CLI not found in PATH"
    return 127
  fi

  _temporalctx_build_flags || return 1

  if [[ "$#" -eq 0 || "$1" == -* ]]; then
    command temporal "$@"
    return $?
  fi

  subcommand="$1"
  shift
  command temporal "$subcommand" "${_temporalctx_flags[@]}" "$@"
}

temporalctx() {
  local no_overmind=0
  _temporalctx_ensure_config

  case "$1" in
    "")
      _temporalctx_pick_context
      ;;
    help|-h|--help)
      _temporalctx_help
      ;;
    start)
      if [[ "$2" == "--no-overmind" ]]; then
        no_overmind=1
      elif [[ -n "$2" ]]; then
        print -u2 -- "temporalctx: unknown option for start: $2"
        return 1
      fi
      _temporalctx_start_local_server "$no_overmind"
      ;;
    stop)
      if [[ "$2" == "--no-overmind" ]]; then
        no_overmind=1
      elif [[ -n "$2" ]]; then
        print -u2 -- "temporalctx: unknown option for stop: $2"
        return 1
      fi
      _temporalctx_stop_local_server "$no_overmind"
      ;;
    edit|-e|--edit)
      _temporalctx_edit_config
      ;;
    -c)
      _temporalctx_current_context
      ;;
    -)
      local prev_file prev current
      prev_file="$(_temporalctx_previous_file)"
      if [[ ! -f "$prev_file" ]]; then
        print -u2 -- "temporalctx: no previous context"
        return 1
      fi
      prev="$(<"$prev_file")"
      current="$(_temporalctx_current_context)"
      if [[ -z "$prev" ]]; then
        print -u2 -- "temporalctx: no previous context"
        return 1
      fi
      if ! _temporalctx_context_exists "$prev"; then
        print -u2 -- "temporalctx: previous context '$prev' not found"
        return 1
      fi
      if [[ -n "$current" ]]; then
        print -r -- "$current" > "$prev_file"
      fi
      _temporalctx_set_current_context "$prev" || return 1
      print -r -- "$prev"
      ;;
    *)
      _temporalctx_switch "$1"
      ;;
  esac
}

alias tctx='temporalctx'
