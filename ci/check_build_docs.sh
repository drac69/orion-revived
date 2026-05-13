#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readme="$repo_dir/README.md"

if ! rg -q '\.\./ci/run_qmake\.sh \.\./' "$readme"; then
    printf 'README build commands must use the Qt 5 qmake wrapper from the build directory.\n' >&2
    exit 1
fi

if rg -q '^\s*qmake \.\./\s*$' "$readme"; then
    printf 'README build commands must not use ambiguous bare qmake.\n' >&2
    exit 1
fi

if ! rg -q 'Qt 5 qmake wrapper' "$readme"; then
    printf 'README backend instructions must mention the Qt 5 qmake wrapper.\n' >&2
    exit 1
fi
