#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
main_qml="$repo_dir/src/qml/main.qml"

for required in \
    'function refreshWindowScreenAssociation()' \
    'Qt.callLater(refreshWindowScreenAssociation)' \
    'function preparePopupMenu()' \
    'refreshWindowScreenAssociation()' \
    'root.x += 1' \
    'root.x -= 1'
do
    if ! rg -q -F "$required" "$main_qml"; then
        printf 'main.qml must keep the startup popup/screen association workaround token: %s\n' "$required" >&2
        exit 1
    fi
done

menu_files=$(rg -l '\bMenu\s*\{' "$repo_dir/src/qml")
missing_workaround=$(rg --files-without-match 'preparePopupMenu' $menu_files || true)
if [ -n "$missing_workaround" ]; then
    printf 'QML menu files must call rootWindow.preparePopupMenu before showing menus:\n%s\n' "$missing_workaround" >&2
    exit 1
fi
