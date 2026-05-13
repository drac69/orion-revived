#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
player_view="$repo_dir/src/qml/PlayerView.qml"
status_changed_block=$(sed -n '/onStatusChanged:/,/^        }/p' "$player_view")

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
