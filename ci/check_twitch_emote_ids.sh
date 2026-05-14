#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

check_absent() {
    local label=$1
    local pattern=$2
    shift 2
    local paths=()
    local path
    for path in "$@"; do
        paths+=("$repo_dir/$path")
    done

    if rg -n "$pattern" "${paths[@]}"; then
        echo "Unexpected $label" >&2
        exit 1
    fi
}

check_present() {
    local label=$1
    local pattern=$2
    shift 2
    local paths=()
    local path
    for path in "$@"; do
        paths+=("$repo_dir/$path")
    done

    if ! rg -n "$pattern" "${paths[@]}" >/dev/null; then
        echo "Missing $label" >&2
        exit 1
    fi
}

check_absent "numeric Helix emote ID parsing" 'emote\["(id|emote_set_id)"\]\.toString\(\)\.toInt\(\)' "src/util/jsonparser.cpp"
check_absent "numeric IRC emote tag IDs" 'key\.toInt\(\)' "src/model/ircchat.cpp"
check_absent "legacy Twitch emote CDN URL" 'emoticons/v1' "src/model/ircchat.cpp" "src/model/ircchat.h" "src/network/urls.h"

check_present "string Helix emote parser return type" 'QMap<QString, QMap<QString, QString>> JsonParser::parseEmoteSets' "src/util/jsonparser.cpp"
check_present "string IRC emote tag parser return type" 'QMap<int, QPair<int, QString>> IrcChat::parseEmotesTag' "src/model/ircchat.cpp"
check_present "current Twitch emote CDN template" 'emoticons/v2/%1/static/dark/1\.0' "src/model/ircchat.cpp"
check_present "IRC emote tag separator guard" 'separator <= 0' "src/model/ircchat.cpp"
check_present "IRC emote tag conversion guard" 'toInt\(&firstOk\)' "src/model/ircchat.cpp"
check_present "IRC emote tag range guard" 'last < first' "src/model/ircchat.cpp"
check_present "IRC emote tag availability guard" 'hasValidPosition' "src/model/ircchat.cpp"
check_absent "unguarded IRC emote range conversion" 'firstAndLast\[0\]\.toInt\(\)|firstAndLast\[1\]\.toInt\(\)' "src/model/ircchat.cpp"
