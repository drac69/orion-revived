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

check_present "BTTV direct emote URL helper" 'QString IrcChat::bttvEmoteUrl\(const QString &id\) const' "src/model/ircchat.cpp"
check_present "BTTV CDN URL template" 'https://cdn\.betterttv\.net/emote/%1/[12]x' "src/model/ircchat.cpp" "src/model/ircchat.h"
check_present "optional inline image source URL" 'QVariantMap createImageEntry\(QString imageProvider, QString imageId, QString originalText, QString sourceUrl = QString\(\)\)' "src/model/ircchat.cpp"
check_present "inline image sourceUrl payload" 'imageObj\.insert\("sourceUrl", sourceUrl\)' "src/model/ircchat.cpp"
check_present "BTTV substitution direct source URL" 'bttvEmoteUrl\(emoteId\)' "src/model/ircchat.cpp"
check_present "BTTV IRC direct source URL" 'bttvEmoteUrl\(imageId\)' "src/model/ircchat.cpp"
check_present "QML sourceUrl image path" 'if \(msg\[index\]\.sourceUrl\)' "src/qml/irc/ChatMessage.qml"
check_present "QML animated inline image renderer" 'AnimatedImage' "src/qml/irc/ChatMessage.qml"
check_present "QML animated sourceUrl binding" 'Util\.withImageReloadToken\(msgItem\.sourceUrl \|\| "", Network\.imageReloadToken\)' "src/qml/irc/ChatMessage.qml"

check_present "FFZ CDN URL template" 'https://cdn\.frankerfacez\.com/emote/%1/[12]' "src/model/ircchat.cpp" "src/model/ircchat.h"
check_present "FFZ image provider registration" 'engine\.addImageProvider\(IMAGE_PROVIDER_FFZ_EMOTE, _ffzEmoteProvider\.getQMLImageProvider\(\)\)' "src/model/ircchat.cpp"
check_present "FFZ parser hidden emote filter" 'emoteObj\["hidden"\]\.toBool\(\)' "src/util/jsonparser.cpp"
check_present "FFZ parser string and numeric ID support" 'idValue\.isString\(\) \? idValue\.toString\(\) : QString::number\(idValue\.toInt\(\)\)' "src/util/jsonparser.cpp"
check_present "FFZ fixed-string lookup" 'lastCurChannelFfzEmoteFixedStrings, lastGlobalFfzEmoteFixedStrings' "src/model/ircchat.cpp"
check_present "FFZ emote handler" 'void IrcChat::handleFfzEmote\(const QString & id, ImagePositionsMap & mapToUpdate, int pos, int end\)' "src/model/ircchat.cpp"
check_present "FFZ emote kind" 'ImageEntryKind::ffzEmote' "src/model/ircchat.cpp" "src/model/ircchat.h"
check_present "FFZ provider availability" '_ffzEmoteProvider\.makeAvailable\(id\)' "src/model/ircchat.cpp"
check_present "FFZ QML image entry" 'createImageEntry\(_ffzEmoteProvider\.getImageProviderName\(\), imageId, originalText\)' "src/model/ircchat.cpp"
check_present "FFZ global bulk download hook" 'void IrcChat::downloadFfzEmotesGlobal\(\)' "src/model/ircchat.cpp"
check_present "FFZ channel bulk download hook" 'void IrcChat::downloadFfzEmotesChannel\(\)' "src/model/ircchat.cpp"
check_present "FFZ loaded signal emission" 'emit ffzEmotesLoaded\(channelName, toVariantMap\(emotesByCode\)\)' "src/model/ircchat.cpp"
