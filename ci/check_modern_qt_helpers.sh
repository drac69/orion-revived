#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

for source_dir in "$repo_dir/src/util" "$repo_dir/src/network"; do
    if rg -n '\bforeach\s*\(' "$source_dir"; then
        printf '%s must use range-based loops instead of Qt foreach.\n' "$source_dir" >&2
        exit 1
    fi
done
