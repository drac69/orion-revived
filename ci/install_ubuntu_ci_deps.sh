#!/usr/bin/env bash
set -euo pipefail

apt_update_timeout=${ORION_CI_APT_UPDATE_TIMEOUT:-300s}
apt_install_timeout=${ORION_CI_APT_INSTALL_TIMEOUT:-1800s}
apt_retries=${ORION_CI_APT_RETRIES:-2}
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
    shellcheck
    qt5-qmake
    qtbase5-dev
    qtdeclarative5-dev
    qml-module-qtgraphicaleffects
    qml-module-qt-labs-settings
    qml-module-qtquick-controls2
    qml-module-qtquick-layouts
    qml-module-qtquick-window2
    qml-module-qtquick2
    qtquickcontrols2-5-dev
)
packages=("${common_packages[@]}" "$@")
apt_options=(
    -o Acquire::Retries=5
    -o Acquire::http::Timeout=60
    -o Acquire::https::Timeout=60
)

run_with_retry() {
    local label=$1
    local command_timeout=$2
    shift 2
    local attempt=1
    local status=0

    while (( attempt <= apt_retries )); do
        printf '::group::%s, attempt %d/%d\n' "$label" "$attempt" "$apt_retries"
        if sudo env DEBIAN_FRONTEND=noninteractive timeout --kill-after=30s "$command_timeout" "$@"; then
            printf '::endgroup::\n'
            return 0
        else
            status=$?
        fi
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

run_with_retry "apt-get update" "$apt_update_timeout" apt-get "${apt_options[@]}" update
run_with_retry "apt-get install" "$apt_install_timeout" apt-get "${apt_options[@]}" install -y --no-install-recommends "${packages[@]}"
