#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
player_view="$repo_dir/src/qml/PlayerView.qml"
status_changed_block=$(sed -n '/onStatusChanged:/,/^        }/p' "$player_view")
seek_preview="$repo_dir/src/qml/components/SeekPreview.qml"
multimedia_backend="$repo_dir/src/qml/MultimediaBackend.qml"
qtav_backend="$repo_dir/src/qml/QtAVBackend.qml"
mpv_backend="$repo_dir/src/qml/MpvBackend.qml"
mpv_object_header="$repo_dir/src/player/mpvobject.h"
mpv_object_source="$repo_dir/src/player/mpvobject.cpp"
mpv_qt_helper="$repo_dir/src/player/qthelper.hpp"
vod_manager="$repo_dir/src/model/vodmanager.cpp"
settings_manager="$repo_dir/src/model/settingsmanager.cpp"
network_manager="$repo_dir/src/network/networkmanager.cpp"
test_connection_reply_block=$(sed -n '/void NetworkManager::testConnectionReply()/,/^}/p' "$network_manager")

if ! printf '%s\n' "$status_changed_block" | rg -q 'renderer\.status === "BUFFERING"'; then
    printf 'PlayerView must restart stall recovery when active playback returns to BUFFERING.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$status_changed_block" | rg -q 'startupRetryTimer\.restart\(\)'; then
    printf 'PlayerView must restart the buffering retry timer from status changes.\n' >&2
    exit 1
fi

if ! rg -q 'Playback startup stalled; retrying' "$player_view"; then
    printf 'PlayerView must retain bounded buffering retry diagnostics.\n' >&2
    exit 1
fi

if ! rg -q 'unexpectedStopRecoveryTimer' "$player_view"; then
    printf 'PlayerView must retain unexpected STOPPED-state recovery.\n' >&2
    exit 1
fi

for required in \
    'function rendererStatus()' \
    'function rendererPosition()' \
    'Player backend is not available' \
    'running: rendererStatus() === "BUFFERING"' \
    'show(rendererStatus() !== "PLAYING" ?' \
    'text: rendererStatus() !== "PLAYING" && rendererStatus() !== "BUFFERING"' \
    'if (!renderer) {' \
    'return 0' \
    'if (renderer) {' \
    'renderer.setVolume(value)'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must guard UI controls when the renderer item is unavailable: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -q 'running: renderer\.status|show\(renderer\.status|text: renderer\.status|if \(renderer\.status === "PAUSED" \|\| renderer\.status === "STOPPED"\)' "$player_view"; then
    printf 'PlayerView controls must use guarded rendererStatus() bindings outside renderer Connections.\n' >&2
    exit 1
fi

for required in \
    'function currentSeekPreviewSource()' \
    'return currentChannel && currentChannel.seekPreviews ? currentChannel.seekPreviews : ""' \
    'onCurrentChannelChanged: preview.source = currentSeekPreviewSource()' \
    'onCurrentChannelChanged: seekPreview.source = currentSeekPreviewSource()' \
    'root.currentChannel && root.curVodId && Math.abs'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must guard VOD seek-preview and position-save state: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -q 'onCurrentChannelChanged: .*currentChannel\.seekPreviews' "$player_view"; then
    printf 'PlayerView must not dereference currentChannel.seekPreviews directly from seek-preview handlers.\n' >&2
    exit 1
fi

for required in \
    'function resetInfo()' \
    'if (count <= 0 || isNaN(root.from) || isNaN(root.to) || root.to <= root.from)' \
    'var requestedSource = root.source' \
    'if (requestedSource !== root.source || !resp || resp.length <= 0)' \
    'if (!info || !info.count || !info.interval || !info.width || !info.height'
do
    if ! rg -q -F "$required" "$seek_preview"; then
        printf 'SeekPreview must ignore stale or malformed preview metadata: %s\n' "$required" >&2
        exit 1
    fi
done

if ! rg -q 'function showPlaybackError' "$player_view"; then
    printf 'PlayerView must centralize playback error handling.\n' >&2
    exit 1
fi

if ! rg -q 'headersVisible = true' "$player_view" || ! rg -q 'hideTimer\.stop\(\)' "$player_view"; then
    printf 'Playback errors must force the Twitch fallback control to remain visible.\n' >&2
    exit 1
fi

if ! rg -q 'Open VOD on Twitch' "$player_view" || ! rg -q 'Open channel on Twitch' "$player_view"; then
    printf 'Playback errors must keep explicit Twitch fallback labels.\n' >&2
    exit 1
fi

if ! rg -q 'onBackendError' "$player_view" || ! rg -q 'backend_error' "$player_view"; then
    printf 'PlayerView must surface backend playback errors through the common playback error UI.\n' >&2
    exit 1
fi

if ! rg -q 'if \(playbackError\)' "$player_view"; then
    printf 'PlayerView must not overwrite visible playback errors with stopped-state text.\n' >&2
    exit 1
fi

for backend in "$multimedia_backend" "$qtav_backend" "$mpv_backend"; do
    if ! rg -q 'signal backendError\(string message\)' "$backend"; then
        printf 'Backend %s must expose backendError(message).\n' "$backend" >&2
        exit 1
    fi
done

if ! rg -q 'onError:' "$multimedia_backend" || ! rg -q 'backendError\(detail\)' "$multimedia_backend"; then
    printf 'Qt Multimedia backend must forward MediaPlayer errors to PlayerView.\n' >&2
    exit 1
fi

if ! rg -q 'root\.status = "STOPPED"' "$multimedia_backend"; then
    printf 'Qt Multimedia backend errors must leave BUFFERING state after surfacing the error.\n' >&2
    exit 1
fi

if ! rg -q 'onError:' "$qtav_backend" || ! rg -q 'backendError\(detail\)' "$qtav_backend"; then
    printf 'QtAV backend must forward MediaPlayer errors to PlayerView.\n' >&2
    exit 1
fi

if ! rg -q 'root\.status = "STOPPED"' "$qtav_backend"; then
    printf 'QtAV backend errors must leave BUFFERING state after surfacing the error.\n' >&2
    exit 1
fi

if ! rg -q 'void playbackError\(const QString &message\)' "$mpv_object_header"; then
    printf 'MpvObject must expose mpv playback errors to QML.\n' >&2
    exit 1
fi

if ! rg -q 'MPV_EVENT_END_FILE' "$mpv_object_source" \
    || ! rg -q 'MPV_END_FILE_REASON_ERROR' "$mpv_object_source" \
    || ! rg -q 'mpv_error_string\(endFile->error\)' "$mpv_object_source"; then
    printf 'MpvObject must turn MPV_EVENT_END_FILE error reasons into readable playback errors.\n' >&2
    exit 1
fi

if ! rg -q 'onPlaybackError: root\.backendError' "$mpv_backend"; then
    printf 'MpvBackend.qml must forward libmpv playback errors through backendError.\n' >&2
    exit 1
fi

if rg -q 'command_variant|set_property_variant|set_option_variant|get_property_variant' "$mpv_object_source"; then
    printf 'MpvObject must use the non-deprecated mpv Qt helper calls.\n' >&2
    exit 1
fi

if rg -q '#error "This helper is deprecated' "$mpv_qt_helper"; then
    printf 'The bundled mpv Qt helper must not require deprecated libmpv APIs to compile.\n' >&2
    exit 1
fi

if ! rg -q 'static inline int set_option' "$mpv_qt_helper"; then
    printf 'The bundled mpv Qt helper must expose a non-deprecated set_option helper.\n' >&2
    exit 1
fi

if rg -q 'USE_OPENGL_CB|mpv_opengl_cb|MPV_SUB_API_OPENGL_CB|opengl-cb' "$mpv_object_header" "$mpv_object_source"; then
    printf 'MpvObject must use the modern libmpv render API instead of the deprecated OpenGL callback API.\n' >&2
    exit 1
fi

if ! rg -q 'bytesWritten != snapshotData\.size\(\)' "$vod_manager"; then
    printf 'VodManager must treat short playback-position snapshot writes as failed saves.\n' >&2
    exit 1
fi

if ! rg -q 'file\.cancelWriting\(\)' "$vod_manager"; then
    printf 'VodManager must cancel partial playback-position snapshots before returning.\n' >&2
    exit 1
fi

if ! rg -q 'warnSettingsSyncFailure\(settings, "VOD cache settings"\)' "$vod_manager"; then
    printf 'VodManager must warn when cached VOD settings fail to sync.\n' >&2
    exit 1
fi

if ! rg -q 'warnSettingsSyncFailure\(settings, "VOD position settings"\)' "$vod_manager"; then
    printf 'VodManager must warn when VOD position settings fail to sync.\n' >&2
    exit 1
fi

if ! rg -q 'syncSettings\("channel quality"\)' "$settings_manager"; then
    printf 'SettingsManager must immediately sync per-channel stream quality changes.\n' >&2
    exit 1
fi

if ! rg -q 'syncSettings\("stream quality"\)' "$settings_manager"; then
    printf 'SettingsManager must immediately sync default stream quality changes.\n' >&2
    exit 1
fi

if ! rg -q 'syncSettings\("remember channel quality"\)' "$settings_manager"; then
    printf 'SettingsManager must immediately sync the per-channel quality memory toggle.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$test_connection_reply_block" | rg -q 'if \(!reply\)'; then
    printf 'Network connection test replies must guard missing reply senders.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$test_connection_reply_block" | rg -q 'reply->deleteLater\(\)'; then
    printf 'Network connection test replies must release QNetworkReply objects.\n' >&2
    exit 1
fi
