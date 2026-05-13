#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_dir/.github/workflows/ci.yml"
dependabot="$repo_dir/.github/dependabot.yml"

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

if ! rg -q 'ci/check_patch_whitespace\.sh' "$workflow"; then
    printf 'CI workflow must reject whitespace errors in the committed patch.\n' >&2
    exit 1
fi

if ! rg -q 'package-ecosystem:\s*"github-actions"' "$dependabot" \
        || ! rg -q 'directory:\s*"/"' "$dependabot" \
        || ! rg -q 'interval:\s*"weekly"' "$dependabot"; then
    printf 'Dependabot must keep weekly GitHub Actions update checks enabled.\n' >&2
    exit 1
fi
