# Opinionated Temporal helper aliases/functions.
# Installed by `./install.sh --full`.

# Query a workflow's state.
# Usage: tq <workflow-id>
tq() {
  local wf_id="${1:?Usage: tq <workflow-id>}"
  temporal workflow query \
    --workflow-id "$wf_id" \
    --type getState
}

# Describe a workflow.
# Usage: td <workflow-id>
td() {
  local wf_id="${1:?Usage: td <workflow-id>}"
  temporal workflow describe \
    --workflow-id "$wf_id"
}

# List recent workflows.
# Usage: tl [limit]
tl() {
  local limit="${1:-10}"
  temporal workflow list \
    --limit "$limit"
}
