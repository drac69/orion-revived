#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
emote_picker_qml="$repo_dir/src/qml/components/EmotePicker.qml"
chat_view_qml="$repo_dir/src/qml/irc/ChatView.qml"

for required in \
    'if (typeof index !== "number" || !_innerModel || index < 0 || index >= _innerModel.count)' \
    'if (root._visibleItemClicked(hoveringIndex)) {' \
    'if (root._visibleItemClicked(_emotesGrid.currentIndex) && (event.modifiers & Qt.ShiftModifier) !== Qt.ShiftModifier)' \
    'if (root._visibleItemClicked(0) && (event.modifiers & Qt.ShiftModifier) !== Qt.ShiftModifier)'
do
    if ! rg -q -F "$required" "$emote_picker_qml"; then
        printf 'EmotePicker must guard visible-item selection before emitting itemClicked: %s\n' "$required" >&2
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
