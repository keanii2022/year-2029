#!/bin/sh
# Full check: format, lint, Lune logic tests, and a place build. Quiet unless something fails.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
stylua --check src tests >/dev/null || { stylua --check src tests; exit 1; }
selene src tests >build/selene.txt 2>&1 || { cat build/selene.txt; exit 1; }
lune run tests/run.luau
rojo build -o build/Year2029.rbxl >/dev/null
echo "check ok: build/Year2029.rbxl"
