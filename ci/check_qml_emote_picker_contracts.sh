#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
emote_picker_qml="$repo_dir/src/qml/components/EmotePicker.qml"
emote_selector_qml="$repo_dir/src/qml/irc/EmoteSelector.qml"
chat_view_qml="$repo_dir/src/qml/irc/ChatView.qml"

for required in \
    'if (!model) {' \
    'function visibleIndexToSourceIndex(index)' \
    'if (typeof index !== "number" || !root.model || !_innerModel || index < 0 || index >= _innerModel.count)' \
    'var mappedIndex = _filterIndexMap[index];' \
    'mappedIndex >= 0 && mappedIndex < root.model.count' \
    'var actualIndex = visibleIndexToSourceIndex(index);' \
    'if (actualIndex === -1)' \
    'visible: root.visibleIndexToSourceIndex(_emotesGrid.currentIndex) !== -1' \
    'property int index: root.visibleIndexToSourceIndex(_emotesGrid.currentIndex)' \
    'text: index !== -1 ? root.model.get(index)[root.filterTextProperty] : ""' \
    '_emotesGrid.currentIndex = _innerModel && _innerModel.count > 0 ? 0 : -1' \
    'if (root._visibleItemClicked(hoveringIndex)) {' \
    'if (root._visibleItemClicked(_emotesGrid.currentIndex) && (event.modifiers & Qt.ShiftModifier) !== Qt.ShiftModifier)' \
    'if (root._visibleItemClicked(0) && (event.modifiers & Qt.ShiftModifier) !== Qt.ShiftModifier)'
do
    if ! rg -q -F "$required" "$emote_picker_qml"; then
        printf 'EmotePicker must guard visible-item selection before emitting itemClicked: %s\n' "$required" >&2
        exit 1
    fi
done

for forbidden in \
    'property int index: _filterIndexMap[_emotesGrid.currentIndex] || _emotesGrid.currentIndex' \
    'text: index !== -1 ? model.get(index)[root.filterTextProperty] : ""' \
    '_emotesGrid.currentIndex = 0 // todo: find correct new index'
do
    if rg -q -F "$forbidden" "$emote_picker_qml"; then
        printf 'EmotePicker must not use unguarded filtered index/model access: %s\n' "$forbidden" >&2
        exit 1
    fi
done

for required in \
    'Material.theme: rootWindow.Material.theme' \
    'Material.background: rootWindow.Material.background' \
    'Settings.lightTheme ? "#dddddd" : Qt.lighter(Material.background, 1.35)' \
    'Material.foreground: rootWindow.Material.foreground'
do
    if ! rg -q -F "$required" "$emote_picker_qml"; then
        printf 'EmotePicker must follow the selected application light/dark theme: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'if (index < 0 || index >= _emoteButton.setsVisible.count)' \
    'if (!item) {' \
    'addEmoteToChat(item.insertText || item.emoteName);'
do
    if ! rg -q -F "$required" "$chat_view_qml"; then
        printf 'ChatView must guard emote picker indexes before reading the emote model: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'case "ffzGlobal":' \
    'appendVisibleItem("image://ffzemote/" + chat.lastFfzGlobalEmotes[i], i);' \
    'case "ffzChannel":' \
    'appendVisibleItem("image://ffzemote/" + chat.lastFfzChannelEmotes[i], i);' \
    'chat.downloadFfzEmotesGlobal();' \
    'chat.downloadFfzEmotesChannel();' \
    'setsToDownload.push("ffzGlobal");' \
    'setsToDownload.push("ffzChannel");'
do
    if ! rg -q -F "$required" "$emote_selector_qml"; then
        printf 'EmoteSelector must expose FFZ global/channel emotes in the picker: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'chat.lastFfzChannelEmotes = null;' \
    'property variant lastFfzChannelEmotes' \
    'property variant lastFfzGlobalEmotes' \
    'onFfzEmotesLoaded:' \
    'chat.lastFfzGlobalEmotes = emotesByCode;' \
    'chat.lastFfzChannelEmotes = emotesByCode;'
do
    if ! rg -q -F "$required" "$chat_view_qml"; then
        printf 'ChatView must track FFZ global/channel emotes for picker state: %s\n' "$required" >&2
        exit 1
    fi
done
