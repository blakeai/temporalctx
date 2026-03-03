# temporalctx

An oh-my-zsh plugin for switching Temporal contexts (`~/.temporal/config`) similar to `kubectx`.

## Commands

- `temporalctx`: open interactive context picker via `fzf`
- `temporalctx <name>`: switch to named context
- `temporalctx -`: switch to previous context
- `temporalctx -c`: print current context
- `temporal ...`: wrapped by plugin to automatically include current context flags

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
```

Then add `temporalctx` to your `plugins=(...)` in `.zshrc`.

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
