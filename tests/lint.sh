#!/bin/bash
# Lint gate: shellcheck for the bash tools, ruff (and pyright when available)
# for the Python tools. The Python tools have no .py extension, so they are
# copied into a temp directory with one added before linting.
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

bash_tools=(randint cointoss diceroll weighted randstr shuffle choose)
py_tools=(bellcurve binomial poisson exponential geometric uniform uuid ulid)

status=0

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "${bash_tools[@]/#/bin/}" tests/*.sh || status=1
else
    echo "shellcheck not found; skipping bash lint" >&2
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for t in "${py_tools[@]}"; do
    cp "bin/$t" "$tmp/$t.py"
done

if command -v ruff >/dev/null 2>&1; then
    ruff check "$tmp" || status=1
else
    echo "ruff not found; skipping python lint" >&2
fi

if command -v pyright >/dev/null 2>&1; then
    pyright "$tmp"/*.py || status=1
else
    echo "pyright not found; skipping python type check" >&2
fi

exit "$status"
