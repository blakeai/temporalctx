# temporalctx

Context switching for Temporal, like `kubectx` for Kubernetes. An oh-my-zsh plugin that reads `~/.temporal/config.yml` and automatically injects `--address`, `--namespace`, and `--tls` flags into every `temporal` command.

## Prerequisites

```bash
brew install temporal                # required — the Temporal CLI
brew install fzf                     # required — interactive context picker
brew install overmind                # optional — managed local dev server
```

## Install

Clone the repo, then run the installer:

```bash
git clone git@github.com:blakeai/temporalctx.git
cd temporalctx
./install.sh
```

This symlinks the plugin into your oh-my-zsh custom plugins directory and creates a default config at `~/.temporal/config.yml` if one doesn't exist.

Then add `temporalctx` to your plugins in `~/.zshrc`:

```bash
plugins=(... temporalctx)
```

Reload your shell:

```bash
source ~/.zshrc
```

### Install options

| Flag | What it does |
|---|---|
| `--full` | Also installs helper functions (`tq`, `td`, `tl`) by symlinking `temporal.zsh` into `$ZSH_CONFIG` (or `${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}` when unset) |
| `[path]` | Install to a custom plugins directory instead of `$ZSH_CUSTOM/plugins` |

```bash
# Install with helper functions
./install.sh --full

# Install to a custom location
./install.sh ~/my-zsh-plugins
```

## Uninstall

```bash
./uninstall.sh
```

This removes the plugin symlink, cleans up any helper symlinks, and removes state files. Your config at `~/.temporal/config.yml` is kept.

### Uninstall options

| Flag | What it does |
|---|---|
| `--purge-config` | Also delete `~/.temporal/config.yml` |
| `[path]` | Uninstall from a custom plugins directory |

```bash
# Remove everything including config
./uninstall.sh --purge-config
```

Don't forget to remove `temporalctx` from your `plugins=(...)` in `~/.zshrc`.

## Usage

### Context switching

```bash
temporalctx              # interactive picker (fzf)
temporalctx staging      # switch to "staging" context
temporalctx -            # switch to previous context
temporalctx -c           # print current context
temporalctx edit         # open config in $EDITOR
temporalctx help         # show command help
tctx                     # alias for temporalctx
```

### Transparent CLI wrapping

Every `temporal` command automatically uses the flags from your current context:

```bash
temporalctx staging
temporal workflow list    # runs with --address, --namespace, --tls from "staging"
```

To bypass wrapping for a single session:

```bash
TEMPORALCTX_DISABLE_WRAP=1 temporal workflow list --address localhost:7233
```

### Local dev server

Start and stop a local Temporal dev server:

```bash
temporalctx start        # start dev server
temporalctx stop         # stop dev server
```

**With Overmind** (recommended): If `overmind` is installed, the plugin uses it to manage the dev server process via the bundled `Procfile`. This gives you process supervision, log management, and clean shutdowns for free.

**Without Overmind**: Falls back to running `temporal server start-dev` directly and tracking the PID in `~/.temporal/temporal-dev-server.pid`.

To force PID mode even when Overmind is available:

```bash
temporalctx start --no-overmind
temporalctx stop --no-overmind
```

### Helper functions (--full install only)

When installed with `--full`, you get shorthand functions:

| Command | Equivalent |
|---|---|
| `tq <workflow-id>` | `temporal workflow query --workflow-id <id> --type getState` |
| `td <workflow-id>` | `temporal workflow describe --workflow-id <id>` |
| `tl [limit]` | `temporal workflow list --limit <n>` (default 10) |

## Config

Stored at `~/.temporal/config.yml` (override with `$TEMPORAL_CONFIG`):

```yaml
current-context: local

contexts:
  local:
    address: localhost:7233
    namespace: default
    tls: false

  staging:
    address: staging.temporal.example.com:7233
    namespace: my-team
    tls: true
    api-key: ${TEMPORAL_STAGING_API_KEY}
```

Config values support `${ENV_VAR}` placeholders that resolve at runtime.

## Testing

```bash
./tests/run.sh
```
