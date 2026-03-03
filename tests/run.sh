#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/tests/temporalctx.plugin.zsh.test"
"$ROOT/tests/install.sh.test"

echo "PASS: all tests"
