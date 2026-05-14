#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
vods_view_qml="$repo_dir/src/qml/VodsView.qml"

for required in \
    'function hasSelectedChannelId()' \
    'if (!hasSelectedChannelId()) {' \
    'selectedChannel = undefined' \
    'channelVodPositions = ({})' \
    'if (!channel || !channel.name || !vod || !vod._id)' \
    'var vod = vodsModel.itemAt(i)' \
    'if (vod) {' \
    'if (!selectedChannel || !item) {' \
    'if (selectedChannel && selectedChannel.name === channel && channelVodPositions)' \
    'position: channelVodPositions ? (channelVodPositions[model.id] || 0) : 0' \
    'if (g_tooltip && item)' \
    'if (hasSelectedChannelId() && !vodSearchInProgress'
do
    if ! rg -q -F "$required" "$vods_view_qml"; then
        printf 'VodsView must guard selected-channel and VOD item state before model access: %s\n' "$required" >&2
        exit 1
    fi
done

for forbidden in \
    'if (selectedChannel.name === channel)' \
    'position: channelVodPositions[model.id] || 0' \
    'if (g_tooltip)'
do
    if rg -q -F "$forbidden" "$vods_view_qml"; then
        printf 'VodsView must not dereference selectedChannel/channelVodPositions or tooltip items without guards: %s\n' "$forbidden" >&2
        exit 1
    fi
done
