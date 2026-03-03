# temporalctx

An oh-my-zsh plugin for switching Temporal contexts (`~/.temporal/config.yml`) similar to `kubectx`.

## Commands

- `temporalctx`: open interactive context picker via `fzf`
- `temporalctx <name>`: switch to named context
- `temporalctx -`: switch to previous context
- `temporalctx -c`: print current context
- `temporalctx edit` (`-e`/`--edit`): open config in `$VISUAL`, then `$EDITOR`, else `vi`
- `temporalctx start`: start local Temporal dev server
- `temporalctx stop`: stop local Temporal dev server
- `tctx`: alias for `temporalctx`
- `temporal ...`: wrapped by plugin to automatically include current context flags

## Local Dev Server

`temporalctx start` and `temporalctx stop` support two modes:

- Overmind mode (recommended, optional): if `overmind` is installed, plugin uses it with a plugin `Procfile` and socket at `~/.temporal/overmind.sock`.
- PID mode (fallback): if `overmind` is not installed, plugin starts/stops `temporal server start-dev` directly and tracks `~/.temporal/temporal-dev-server.pid`.

Force PID mode even when Overmind is installed:

```bash
temporalctx start --no-overmind
temporalctx stop --no-overmind
```

## Helper function

`_temporal_flags` reads the active context and prints CLI flags:

```bash
--address localhost:7233 --namespace default
```

It resolves `${ENV_VAR}` placeholders in config values.

To bypass wrapping for a command/session, set `TEMPORALCTX_DISABLE_WRAP=1`.

## Install

```bash
./install.sh
# or
./install.sh ~/my-custom-zsh/plugins
# or include opinionated tq/td/tl helpers in $ZSHC/temporal.zsh
./install.sh --full
```

Then add `temporalctx` to your `plugins=(...)` in `.zshrc`.

`--full` is optional and installs plugin-owned helper functions (`tq`, `td`, `tl`) by symlinking:
- `${ZSHC:-~/.config/zsh}/temporal.zsh` -> `<plugin-dir>/temporalctx.full.zsh`

## Config format

```yaml
current-context: local

contexts:
  local:
    address: localhost:7233
    namespace: default
    tls: false
```

## Testing

Run the test suite:

```bash
./tests/run.sh
```
