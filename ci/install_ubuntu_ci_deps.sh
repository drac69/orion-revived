#!/usr/bin/env bash
set -euo pipefail

apt_timeout=${ORION_CI_APT_TIMEOUT:-300s}
apt_retries=${ORION_CI_APT_RETRIES:-3}
if [[ ! "$apt_retries" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ORION_CI_APT_RETRIES must be a positive integer, got %s\n' "$apt_retries" >&2
    exit 2
fi

common_packages=(
    appstream
    build-essential
    desktop-file-utils
    libsystemd-dev
    pkg-config
    ripgrep
    qt5-qmake
    qtbase5-dev
    qtdeclarative5-dev
    qml-module-qtgraphicaleffects
    qml-module-qt-labs-settings
    qml-module-qtquick-controls
    qml-module-qtquick-controls2
    qml-module-qtquick-layouts
    qml-module-qtquick-window2
    qml-module-qtquick2
    qtquickcontrols2-5-dev
)
packages=("${common_packages[@]}" "$@")

run_with_retry() {
    local label=$1
    shift
    local attempt=1
    local status=0

    while (( attempt <= apt_retries )); do
        printf '::group::%s, attempt %d/%d\n' "$label" "$attempt" "$apt_retries"
        if timeout --foreground "$apt_timeout" "$@"; then
            printf '::endgroup::\n'
            return 0
        fi
        status=$?
        printf '::endgroup::\n'

        if (( attempt == apt_retries )); then
            printf '%s failed after %d attempts with exit status %d\n' "$label" "$attempt" "$status" >&2
            return "$status"
        fi

        sleep "$((attempt * 15))"
        attempt=$((attempt + 1))
    done
}

if [[ "${ORION_CI_APT_DRY_RUN:-}" == "1" ]]; then
    printf '%s\n' "${packages[@]}"
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive
run_with_retry "apt-get update" sudo apt-get update
run_with_retry "apt-get install" sudo apt-get install -y --no-install-recommends "${packages[@]}"
