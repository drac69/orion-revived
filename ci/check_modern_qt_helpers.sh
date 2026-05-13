#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if rg -n '\bforeach\s*\(' "$repo_dir/src/util"; then
    printf 'src/util parser helpers must use range-based loops instead of Qt foreach.\n' >&2
    exit 1
fi
