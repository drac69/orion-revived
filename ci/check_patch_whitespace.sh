#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

if git cat-file -e 'HEAD^1^{tree}' 2>/dev/null; then
    git diff --check HEAD^1 HEAD
elif [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    printf 'Skipping patch whitespace check because HEAD parent is unavailable in a shallow checkout.\n'
else
    git diff-tree --check --no-commit-id --root -r HEAD
fi
