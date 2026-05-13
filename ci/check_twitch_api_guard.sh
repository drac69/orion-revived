#!/usr/bin/env bash
set -euo pipefail

fail=0

check_absent() {
    local label="$1"
    local pattern="$2"
    local matches

    matches=$(rg -n --glob '!*.md' --glob '!distfiles/**' --glob '!ci/check_twitch_api_guard.sh' "$pattern" src ci .github || true)
    if [[ -n "$matches" ]]; then
        printf 'Deprecated Twitch API usage found: %s\n%s\n' "$label" "$matches" >&2
        fail=1
    fi
}

check_absent "Kraken/v5 API constants and Accept headers" 'TWITCH_API_V5|application/vnd\.twitchtv\.v5|api\.twitch\.tv/kraken|\bkraken\b'
check_absent "unsupported VOD replay chat/comments API" 'replaychat|vodChatPiece|getVodChatPiece|getNextVodChatPiece|cancelLastVodChatRequest|resetVodChat|/comments'

legacy_host_files=$(rg -l 'api\.twitch\.tv/api' src || true)
if [[ "$legacy_host_files" != "src/network/urls.h" ]]; then
    printf 'Unexpected api.twitch.tv/api host reference. Only the documented playback-token macro may remain.\n%s\n' "$legacy_host_files" >&2
    fail=1
fi

unexpected_macro_refs=$(rg -n '\bTWITCH_API\b' src | rg -v '^src/network/(urls\.h|networkmanager\.cpp):' || true)
if [[ -n "$unexpected_macro_refs" ]]; then
    printf 'Unexpected TWITCH_API macro use outside the known playback-token implementation.\n%s\n' "$unexpected_macro_refs" >&2
    fail=1
fi

networkmanager_macro_refs=$(rg -n '\bTWITCH_API\b' src/network/networkmanager.cpp || true)
networkmanager_macro_count=$(printf '%s\n' "$networkmanager_macro_refs" | sed '/^$/d' | wc -l)
if (( networkmanager_macro_count > 2 )); then
    printf 'TWITCH_API macro is only allowed for live and VOD playback-token requests.\n%s\n' "$networkmanager_macro_refs" >&2
    fail=1
fi

if ! rg -q 'const qint16 IrcChat::PORT = 6697;' src/model/ircchat.cpp; then
    printf 'Twitch IRC TLS connections must use the documented IRC port 6697.\n' >&2
    fail=1
fi

if ! rg -q 'RECONNECT' src/model/ircchat.cpp; then
    printf 'Twitch IRC RECONNECT command handling is required for server-requested reconnects.\n' >&2
    fail=1
fi

if rg -q 'joinChannel\(root\.channel' src/qml/irc/Chat.qml; then
    printf 'QML connected-state handling must not issue duplicate chat JOIN commands.\n' >&2
    fail=1
fi

exit "$fail"
