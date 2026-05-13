#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if rg -n '\bforeach\s*\(' "$repo_dir/src"; then
    printf 'src must use range-based loops instead of Qt foreach.\n' >&2
    exit 1
fi

if rg -n '\b(NULL|Q_NULLPTR)\b' "$repo_dir/src"; then
    printf 'src must use nullptr/FALSE instead of legacy null macros.\n' >&2
    exit 1
fi

if rg -n 'QVariant::Type|\.type\(\)' "$repo_dir/src/player/qthelper.hpp"; then
    printf 'qthelper.hpp must use QVariant::userType() for Qt meta-type checks.\n' >&2
    exit 1
fi
