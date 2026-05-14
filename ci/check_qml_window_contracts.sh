#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readme="$repo_dir/README.md"
main_qml="$repo_dir/src/qml/main.qml"
topbar_qml="$repo_dir/src/qml/TopBar.qml"
sidebar_qml="$repo_dir/src/qml/SideBar.qml"
options_view="$repo_dir/src/qml/OptionsView.qml"
common_grid_qml="$repo_dir/src/qml/components/CommonGrid.qml"
main_cpp="$repo_dir/src/main.cpp"
settings_manager="$repo_dir/src/model/settingsmanager.cpp"
settings_manager_header="$repo_dir/src/model/settingsmanager.h"
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

for required in \
    'QString singleInstanceLockPath()' \
    'QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation)' \
    'QStandardPaths::writableLocation(QStandardPaths::TempLocation)' \
    'QDir::tempPath()' \
    'QCoreApplication::organizationName()' \
    'QCoreApplication::applicationName()' \
    'baseDir.mkpath(lockDirName)' \
    'return baseDir.absoluteFilePath(lockDirName + "/orion.lock");' \
    '#include <QLockFile>' \
    'const QString lockPath = singleInstanceLockPath();' \
    'QLockFile lockfile(lockPath);' \
    'const bool primaryInstance = lockfile.tryLock(100);' \
    'if (!primaryInstance && !SettingsManager::getInstance()->multipleInstances()) {' \
    'enable multiple instances in settings to allow this.' \
    'Lock file:' \
    'rootContext->setContextProperty("g_instance", primaryInstance ? "main" : "child");'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'main.cpp must keep the single-instance lock gated by the multiple-instance setting: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Q_PROPERTY(bool multipleInstances READ multipleInstances WRITE setMultipleInstances NOTIFY multipleInstancesChanged)' \
    'bool mMultipleInstances = false;' \
    'bool multipleInstances() const;' \
    'void setMultipleInstances(bool multipleInstances);' \
    'void multipleInstancesChanged();'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose the multiple-instance preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setMultipleInstances(settings.value("multipleInstances", mMultipleInstances).toBool())' \
    'settings.setValue("multipleInstances", multipleInstances)' \
    'emit multipleInstancesChanged()'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist the multiple-instance preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Allow multiple instances"' \
    'checked: Settings.multipleInstances' \
    'onClicked: Settings.multipleInstances = checked'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose the multiple-instance toggle: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Q_PROPERTY(bool compactNavigation READ compactNavigation WRITE setCompactNavigation NOTIFY compactNavigationChanged)' \
    'Q_PROPERTY(bool sideNavigation READ sideNavigation WRITE setSideNavigation NOTIFY sideNavigationChanged)' \
    'bool mCompactNavigation = false;' \
    'bool mSideNavigation = false;' \
    'bool compactNavigation() const;' \
    'void setCompactNavigation(bool compactNavigation);' \
    'bool sideNavigation() const;' \
    'void setSideNavigation(bool sideNavigation);' \
    'void compactNavigationChanged();' \
    'void sideNavigationChanged();'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose compact and side navigation preferences: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setCompactNavigation(settings.value("compactNavigation", mCompactNavigation).toBool());' \
    'setSideNavigation(settings.value("sideNavigation", mSideNavigation).toBool());' \
    'settings.setValue("compactNavigation", compactNavigation);' \
    'settings.setValue("sideNavigation", sideNavigation);' \
    'emit compactNavigationChanged();' \
    'emit sideNavigationChanged();'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist compact and side navigation preferences: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Compact navigation"' \
    'checked: Settings.compactNavigation' \
    'onClicked: Settings.compactNavigation = checked' \
    'text: "Side navigation"' \
    'checked: Settings.sideNavigation' \
    'onClicked: Settings.sideNavigation = checked' \
    'text: "Chat position"' \
    'model: ["Left", "Right", "Bottom", "Top"]' \
    'selection: Settings.chatEdge'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose compact/side navigation and chat-position controls: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'property bool sideNavigationVisible: Settings.sideNavigation && !appFullScreen && !isMobile()' \
    'anchors.leftMargin: sideNavigationVisible ? sidebar.width : 0' \
    'SideBar {' \
    'id: sidebar' \
    'visible: sideNavigationVisible' \
    'currentIndex: view.currentIndex' \
    'onIndexRequested: topbar.setCurrentIndex(index)' \
    'visible: !root.sideNavigationVisible && !appFullScreen'
do
    if ! rg -q -F "$required" "$main_qml"; then
        printf 'main.qml must route between top and side navigation without hiding player fullscreen state: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'property bool showIcons: Settings.compactNavigation || root.width < 700' \
    'font.family: showIcons ? "Material Icons" : rootWindow.font.name' \
    'text: !tab.showIcons ? "Channels" : "\ue8b6"' \
    'text: !tab.showIcons ? "Player" : "\ue038"'
do
    if ! rg -q -F "$required" "$topbar_qml"; then
        printf 'TopBar must keep compact navigation icon fallback behavior: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'signal indexRequested(int index)' \
    'width: 56' \
    '{ "index": 0, "label": "Channels", "icon": "\ue8b6" }' \
    '{ "index": 4, "label": "Player", "icon": "\ue038" }' \
    'checked: root.currentIndex === modelData.index' \
    'ToolTip.text: modelData.label' \
    'onClicked: root.indexRequested(modelData.index)'
do
    if ! rg -q -F "$required" "$sidebar_qml"; then
        printf 'SideBar must keep desktop side navigation routing and labels: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'onClosing: {' \
    'Qt.quit()' \
    'Shortcut {' \
    'sequence: "Ctrl+Q"' \
    'context: Qt.ApplicationShortcut' \
    'onActivated: Qt.quit()'
do
    if ! rg -q -F "$required" "$main_qml"; then
        printf 'main.qml must keep the Ctrl+Q application quit shortcut: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'QString normalizedStartupChannel(QString value)' \
    'const QUrl url = QUrl::fromUserInput(value);' \
    'host == "twitch.tv" || host == "www.twitch.tv"' \
    "url.path().split('/', Qt::SkipEmptyParts)" \
    'value.remove(QRegularExpression("^[#@/]+"));' \
    'value.remove(QRegularExpression("[/?#].*$"));' \
    'QCommandLineOption channelOption(QStringList() << "c" << "channel"' \
    'parser.addPositionalArgument("channel", "Twitch channel name or twitch.tv URL to open on startup.");' \
    'startupChannel = normalizedStartupChannel(parser.value(channelOption));' \
    'startupChannel = normalizedStartupChannel(parser.positionalArguments().first());' \
    'rootContext->setContextProperty("g_startupChannel", startupChannel);'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'main.cpp must normalize --channel and positional twitch.tv startup targets: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'function openChannelName(channelName)' \
    'channelName = (channelName || "").trim().replace(/^[@#\/]+/, "")' \
    'view.playerView.getStreams({' \
    '"name": channelName' \
    'topbar.setCurrentIndex(4)' \
    'if (g_startupChannel && openChannelName(g_startupChannel)) {' \
    'console.log("Opening startup channel", g_startupChannel)'
do
    if ! rg -q -F "$required" "$main_qml"; then
        printf 'main.qml must open normalized startup channels in the player view: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Open a channel directly from a launcher or shell:' \
    'orion --channel channelname' \
    'orion https://www.twitch.tv/channelname'
do
    if ! rg -q -F "$required" "$readme"; then
        printf 'README must document direct startup channel examples: %s\n' "$required" >&2
        exit 1
    fi
done

mapfile -t menu_files < <(rg -l '\bMenu\s*\{' "$repo_dir/src/qml")
if (( ${#menu_files[@]} > 0 )); then
    missing_workaround=$(rg --files-without-match 'preparePopupMenu' "${menu_files[@]}" || true)
    if [ -n "$missing_workaround" ]; then
        printf 'QML menu files must call rootWindow.preparePopupMenu before showing menus:\n%s\n' "$missing_workaround" >&2
        exit 1
    fi
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
    'property int clickedIndex: -1' \
    'var currentIndex = root.indexAt(contentPointX, contentPointY)' \
    'currentIndex === clickedIndex' \
    'var clickedItem = root.itemAt(contentPointX, contentPointY)' \
    '_ct.reset()' \
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
