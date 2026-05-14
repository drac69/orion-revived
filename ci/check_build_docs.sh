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

if rg -q "I'll|next version|Visual C\+\+ 2015-runtime" "$readme"; then
    printf 'README must not keep stale upstream Windows installer/runtime wording.\n' >&2
    exit 1
fi

if ! rg -q 'latest-supported-vc-redist' "$readme"; then
    printf 'README Windows troubleshooting must point to the current Microsoft VC++ redistributable page.\n' >&2
    exit 1
fi

if ! rg -q 'pkg install .*qt5-qmake' "$readme"; then
    printf 'README FreeBSD dependencies must include qt5-qmake for the Qt 5 qmake wrapper.\n' >&2
    exit 1
fi

if ! rg -q 'sudo dnf install .*mpv-libs-devel' "$readme" \
    || ! rg -q 'Fedora packages should prefer the mpv backend' "$readme" \
    || ! rg -q 'GStreamer H\.264/AAC' "$readme"; then
    printf 'README Fedora notes must document mpv build dependencies and the Qt Multimedia/GStreamer playback caveat.\n' >&2
    exit 1
fi

if ! rg -q 'default install prefix is `/usr/local`' "$readme"; then
    printf 'README FreeBSD build notes must document the /usr/local default install prefix.\n' >&2
    exit 1
fi

if ! rg -q 'freebsd: PREFIX = /usr/local' "$repo_dir/orion.pro"; then
    printf 'orion.pro must default FreeBSD installs to /usr/local.\n' >&2
    exit 1
fi

if ! rg -q 'unix:!macx:!android: \{' "$repo_dir/orion.pro"; then
    printf 'orion.pro install target must cover Unix desktop builds, including FreeBSD.\n' >&2
    exit 1
fi
