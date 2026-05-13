#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_dir/.github/workflows/ci.yml"

if ! rg -q '^permissions:\s*$' "$workflow" || ! rg -q '^\s+contents:\s*read\s*$' "$workflow"; then
    printf 'CI workflow must use least-privilege read-only contents permissions.\n' >&2
    exit 1
fi

if ! rg -q '^concurrency:\s*$' "$workflow" \
        || ! rg -Fq 'group: ${{ github.workflow }}-${{ github.ref }}' "$workflow" \
        || ! rg -q '^\s+cancel-in-progress:\s*true\s*$' "$workflow"; then
    printf 'CI workflow must cancel stale runs for the same workflow/ref.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_workflow_hygiene\.sh' "$workflow"; then
    printf 'CI workflow must run the workflow hygiene guard.\n' >&2
    exit 1
fi
