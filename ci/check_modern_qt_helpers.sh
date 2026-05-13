#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

for source_path in \
    "$repo_dir/src/util" \
    "$repo_dir/src/network" \
    "$repo_dir/src/model/gamelistmodel.cpp" \
    "$repo_dir/src/model/vodlistmodel.cpp"
do
    if rg -n '\bforeach\s*\(' "$source_path"; then
        printf '%s must use range-based loops instead of Qt foreach.\n' "$source_path" >&2
        exit 1
    fi
done
