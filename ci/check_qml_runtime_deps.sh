#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readme="$repo_dir/README.md"
workflow="$repo_dir/.github/workflows/ci.yml"

require_package_for_import() {
    local import_pattern=$1
    local package_name=$2

    if rg -q "$import_pattern" "$repo_dir/src/qml"; then
        if ! rg -q "$package_name" "$readme"; then
            printf 'README Ubuntu dependencies must include %s for %s.\n' "$package_name" "$import_pattern" >&2
            exit 1
        fi
        if ! rg -q "$package_name" "$workflow"; then
            printf 'CI dependencies must include %s for %s.\n' "$package_name" "$import_pattern" >&2
            exit 1
        fi
    fi
}

require_package_for_import '^import Qt\.labs\.settings\b' 'qml-module-qt-labs-settings'
require_package_for_import '^import QtGraphicalEffects\b' 'qml-module-qtgraphicaleffects'
require_package_for_import '^import QtQuick\.Controls\b' 'qml-module-qtquick-controls2'
require_package_for_import '^import QtQuick\.Controls\.Styles\b' 'qml-module-qtquick-controls'
require_package_for_import '^import QtQuick\.Layouts\b' 'qml-module-qtquick-layouts'
require_package_for_import '^import QtQuick\.Window\b' 'qml-module-qtquick-window2'
require_package_for_import '^import QtMultimedia\b' 'qml-module-qtmultimedia'
