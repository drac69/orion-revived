#!/usr/bin/env bash
set -euo pipefail

version_for() {
    "$1" -query QT_VERSION 2>/dev/null || true
}

run_explicit_qmake() {
    local candidate=$1
    local version
    shift

    if ! command -v "$candidate" >/dev/null 2>&1; then
        printf 'QMAKE is set to %s, but that executable was not found.\n' "$candidate" >&2
        exit 127
    fi

    version=$(version_for "$candidate")
    if [[ "$version" != 5.* ]]; then
        printf 'QMAKE must point to Qt 5 qmake; %s reports QT_VERSION=%s.\n' "$candidate" "${version:-unknown}" >&2
        exit 127
    fi

    exec "$candidate" "$@"
}

try_qmake() {
    local candidate=$1
    local version
    shift

    if ! command -v "$candidate" >/dev/null 2>&1; then
        return 1
    fi

    version=$(version_for "$candidate")
    if [[ "$version" == 5.* ]]; then
        exec "$candidate" "$@"
    fi

    return 1
}

if [[ -n "${QMAKE:-}" ]]; then
    run_explicit_qmake "$QMAKE" "$@"
fi

if try_qmake qmake "$@"; then
    exit 0
fi

if try_qmake qmake-qt5 "$@"; then
    exit 0
fi

printf 'Qt 5 qmake is required; install qt5-qmake or set QMAKE to a Qt 5 qmake executable.\n' >&2
exit 127
