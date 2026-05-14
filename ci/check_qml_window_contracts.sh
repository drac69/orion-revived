#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
main_qml="$repo_dir/src/qml/main.qml"
common_grid_qml="$repo_dir/src/qml/components/CommonGrid.qml"
add_favourites_block=$(sed -n '/function addToFavourites/,/^    }/p' "$main_qml")
remove_favourites_block=$(sed -n '/function removeFromFavourites/,/^    }/p' "$main_qml")

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

if rg -q 'onContent[XY]Changed: g_tooltip\.hide\(\)' "$common_grid_qml"; then
    printf 'CommonGrid scroll handlers must guard g_tooltip before hiding it.\n' >&2
    exit 1
fi

for required in \
    'onContentXChanged: if (g_tooltip) g_tooltip.hide()' \
    'onContentYChanged: if (g_tooltip) g_tooltip.hide()'
do
    if ! rg -q -F "$required" "$common_grid_qml"; then
        printf 'CommonGrid is missing guarded tooltip scroll handler token: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'if (clickedItem) {' \
    'if (foo) {' \
    'if (clickedItem && mouse.button === Qt.LeftButton)'
do
    if ! rg -q -F "$required" "$common_grid_qml"; then
        printf 'CommonGrid must guard delegate item lookup before emitting click signals: %s\n' "$required" >&2
        exit 1
    fi
done

for block in "$add_favourites_block" "$remove_favourites_block"; do
    if ! printf '%s\n' "$block" | rg -q -F 'if (!channel) return' \
        || ! printf '%s\n' "$block" | rg -q -F 'if (!channel._id)' \
        || ! printf '%s\n' "$block" | rg -q -F 'showMissingChannelId(channel)'; then
        printf 'QML favourite helpers must guard missing channel objects and channel IDs.\n' >&2
        exit 1
    fi
done
