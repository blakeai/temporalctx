#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Running shell test suite from: $ROOT"
"$ROOT/tests/temporalctx_plugin_test.sh"
"$ROOT/tests/install_test.sh"

echo "PASS: all tests"
