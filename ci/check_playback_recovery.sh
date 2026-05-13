#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
player_view="$repo_dir/src/qml/PlayerView.qml"
status_changed_block=$(sed -n '/onStatusChanged:/,/^        }/p' "$player_view")
multimedia_backend="$repo_dir/src/qml/MultimediaBackend.qml"
qtav_backend="$repo_dir/src/qml/QtAVBackend.qml"
mpv_backend="$repo_dir/src/qml/MpvBackend.qml"

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
