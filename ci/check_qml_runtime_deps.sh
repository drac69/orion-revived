#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readme="$repo_dir/README.md"
workflow="$repo_dir/.github/workflows/ci.yml"
main_cpp="$repo_dir/src/main.cpp"
ci_dependency_sources=(
    "$workflow"
    "$repo_dir/ci/install_ubuntu_ci_deps.sh"
)

allowed_external_imports=(
    Qt.labs.settings
    QtAV
    QtGraphicalEffects
    QtMultimedia
    QtQuick
    QtQuick.Controls
    QtQuick.Controls.Material
    QtQuick.Layouts
    QtQuick.Window
    aldrog.twitchtube.ircchat
    app.orion
    mpv
)

mapfile -t qml_external_imports < <(
    rg --no-filename --only-matching --replace '$1' '^import ([A-Za-z][A-Za-z0-9_.]*)\b' "$repo_dir/src/qml" | sort -u
)

for qml_import in "${qml_external_imports[@]}"; do
    known=false
    for allowed_import in "${allowed_external_imports[@]}"; do
        if [ "$qml_import" = "$allowed_import" ]; then
            known=true
            break
        fi
    done

    if [ "$known" = false ]; then
        printf 'QML import %s must be added to ci/check_qml_runtime_deps.sh with package coverage or an explicit local-module reason.\n' "$qml_import" >&2
        exit 1
    fi
done

require_registration_for_import() {
    local import_name=$1
    local registration_pattern=$2

    if rg -q "^import ${import_name//./\\.}\\b" "$repo_dir/src/qml" \
            && ! rg -q "$registration_pattern" "$repo_dir/src/main.cpp"; then
        printf 'QML import %s must have a matching C++ registration in src/main.cpp.\n' "$import_name" >&2
        exit 1
    fi
}

require_package_for_import() {
    local import_pattern=$1
    local package_name=$2

    if rg -q "$import_pattern" "$repo_dir/src/qml"; then
        if ! rg -q "$package_name" "$readme"; then
            printf 'README Ubuntu dependencies must include %s for %s.\n' "$package_name" "$import_pattern" >&2
            exit 1
        fi
        if ! rg -q "$package_name" "${ci_dependency_sources[@]}"; then
            printf 'CI dependencies must include %s for %s.\n' "$package_name" "$import_pattern" >&2
            exit 1
        fi
    fi
}

require_registration_for_import 'aldrog.twitchtube.ircchat' 'qmlRegisterType<IrcChat>\("aldrog\.twitchtube\.ircchat"'
require_registration_for_import 'app.orion' 'qmlRegisterSingletonType<.*>\("app\.orion"'
require_registration_for_import 'mpv' 'qmlRegisterType<MpvObject>\("mpv"'

for required in \
    '#include <QQmlError>' \
    'QObject::connect(&engine, &QQmlApplicationEngine::warnings' \
    'for (const QQmlError &warning : warnings)' \
    'qCritical().noquote() << warning.toString();' \
    'engine.load(QUrl("qrc:/main.qml"));' \
    'qFatal("Main window was not opened. Check the QML errors above for missing modules or startup failures.");'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'main.cpp must print QML startup warnings before fatal missing-window errors: %s\n' "$required" >&2
        exit 1
    fi
done

warnings_line=$(rg -n 'QQmlApplicationEngine::warnings' "$main_cpp" | head -n1 | cut -d: -f1 || true)
load_line=$(rg -n 'engine\.load\(QUrl\("qrc:/main\.qml"\)\);' "$main_cpp" | head -n1 | cut -d: -f1 || true)
fatal_line=$(rg -n 'Main window was not opened\. Check the QML errors above' "$main_cpp" | head -n1 | cut -d: -f1 || true)
if [[ -z "$warnings_line" || -z "$load_line" || -z "$fatal_line" \
        || "$warnings_line" -ge "$load_line" || "$load_line" -ge "$fatal_line" ]]; then
    printf 'QML warning logging must be connected before engine.load(), and the fatal missing-window message must follow the load.\n' >&2
    exit 1
fi

require_package_for_import '^import Qt\.labs\.settings\b' 'qml-module-qt-labs-settings'
require_package_for_import '^import QtGraphicalEffects\b' 'qml-module-qtgraphicaleffects'
require_package_for_import '^import QtQuick\b' 'qml-module-qtquick2'
require_package_for_import '^import QtQuick\.Controls\b' 'qml-module-qtquick-controls2'
require_package_for_import '^import QtQuick\.Controls\.Material\b' 'qml-module-qtquick-controls2'
require_package_for_import '^import QtQuick\.Layouts\b' 'qml-module-qtquick-layouts'
require_package_for_import '^import QtQuick\.Window\b' 'qml-module-qtquick-window2'
require_package_for_import '^import QtMultimedia\b' 'qml-module-qtmultimedia'

if rg -n '^import QtQuick\.Controls\.Styles\b' "$repo_dir/src/qml"; then
    printf 'QML must not depend on deprecated Qt Quick Controls 1 Styles imports.\n' >&2
    exit 1
fi
