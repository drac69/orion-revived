#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cd "$repo_dir"

rg --files src/qml \
    | sed 's#^src/qml/##' \
    | grep -v '^qml\.qrc$' \
    | sort > "$tmpdir/files"

rg -o '<file>[^<]+</file>' src/qml/qml.qrc \
    | sed 's#</\?file>##g' \
    | sort > "$tmpdir/resources"

missing_files=$(comm -13 "$tmpdir/files" "$tmpdir/resources")
if [ -n "$missing_files" ]; then
    echo "qml.qrc references missing files:" >&2
    echo "$missing_files" >&2
    exit 1
fi

unbundled_files=$(comm -23 "$tmpdir/files" "$tmpdir/resources")
if [ -n "$unbundled_files" ]; then
    echo "src/qml files not listed in qml.qrc:" >&2
    echo "$unbundled_files" >&2
    exit 1
fi
