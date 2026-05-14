#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
irc_chat="$repo_dir/src/model/ircchat.cpp"
chat_qml="$repo_dir/src/qml/irc/Chat.qml"
chat_view="$repo_dir/src/qml/irc/ChatView.qml"
chat_drawer="$repo_dir/src/qml/ChatDrawer.qml"
chat_message="$repo_dir/src/qml/irc/ChatMessage.qml"
player_view="$repo_dir/src/qml/PlayerView.qml"
options_view="$repo_dir/src/qml/OptionsView.qml"
settings_manager="$repo_dir/src/model/settingsmanager.cpp"
settings_manager_header="$repo_dir/src/model/settingsmanager.h"
triage="$repo_dir/docs/upstream-issue-triage.md"
workflow="$repo_dir/.github/workflows/ci.yml"

if ! rg -q 'QString unescapeIrcTagValue\(const QString &value\)' "$irc_chat"; then
    printf 'IRC chat parser must centralize message-tag value unescaping.\n' >&2
    exit 1
fi

if ! rg -q 'static int ircCommandPosition\(const QString &cmd\)' "$irc_chat" \
    || ! rg -Fq "cmd.startsWith('@')" "$irc_chat" \
    || ! rg -Fq "cmd.at(start) == QLatin1Char(':')" "$irc_chat" \
    || ! rg -Fq 'int cmdKeywordPos = ircCommandPosition(cmd);' "$irc_chat"; then
    printf 'IRC command parsing must locate the command after message tags and source prefixes.\n' >&2
    exit 1
fi

for expected in \
    "character == QLatin1Char(':')" \
    "out.append(QLatin1Char(';'))" \
    "character == QLatin1Char('s')" \
    "out.append(QLatin1Char(' '))" \
    "character == QLatin1Char('\\\\')" \
    "out.append(QLatin1Char('\\\\'))" \
    "character == QLatin1Char('r')" \
    "out.append(QLatin1Char('\\r'))" \
    "character == QLatin1Char('n')" \
    "out.append(QLatin1Char('\\n'))"
do
    if ! rg -Fq "$expected" "$irc_chat"; then
        printf 'IRC tag unescape handling is missing expected case: %s\n' "$expected" >&2
        exit 1
    fi
done

if ! rg -q 'value = unescapeIrcTagValue\(tag\.mid\(assignPos \+ 1\)\);' "$irc_chat"; then
    printf 'IRC Tag values must be unescaped in the common Tag parser.\n' >&2
    exit 1
fi

if rg -q 'systemMessage\.replace\("\\\\s", " "\)|systemMessage\.replace\("\\\\\\\\", "\\\\"' "$irc_chat"; then
    printf 'USERNOTICE system-message unescaping must not stay as an ad hoc special case.\n' >&2
    exit 1
fi

if ! rg -q 'if \(tagsEnd == -1\)' "$irc_chat"; then
    printf 'IRC tag extraction must guard malformed tag-only input without a separator.\n' >&2
    exit 1
fi

if ! rg -Fq "cmd.isEmpty() || cmd.at(0) != QChar('@')" "$irc_chat" \
    || ! rg -Fq 'if (tag.isEmpty())' "$irc_chat" \
    || ! rg -Fq 'key = tag;' "$irc_chat"; then
    printf 'IRC tag parsing must tolerate empty commands and valueless tags.\n' >&2
    exit 1
fi

if ! rg -q '#167:.*unescapes IRCv3 message-tag values' "$triage"; then
    printf 'Upstream issue triage must document IRCv3 tag unescaping coverage.\n' >&2
    exit 1
fi

for required in \
    'onNetworkAccessChanged:' \
    'if (up && root.channel && !root.replayMode && !chat.connected)' \
    'onErrorOccured:' \
    'Chat connection error:'
do
    if ! rg -q -F "$required" "$chat_qml"; then
        printf 'Chat QML must surface IRC errors and reconnect active live chat after network recovery: %s\n' "$required" >&2
        exit 1
    fi
done

for command in PRIVMSG USERNOTICE WHISPER NOTICE GLOBALUSERSTATE USERSTATE CLEARCHAT; do
    if ! rg -q "commandKeyword == \"$command\"" "$irc_chat"; then
        printf 'IRC parser must dispatch %s through the structured command keyword.\n' "$command" >&2
        exit 1
    fi
done

for required in \
    'QString raidChannel;' \
    'tag.key == "msg-id"' \
    'tag.key == "msg-param-login"' \
    'raidChannel = tag.value;' \
    'const bool isRaidNotice = noticeId == "raid" && !raidChannel.isEmpty();' \
    'parse.chatMessage.systemMessage += QString(" https://www.twitch.tv/%1").arg(raidChannel);' \
    'emit raidReceived(raidChannel);'
do
    if ! rg -q -F "$required" "$irc_chat"; then
        printf 'USERNOTICE raid handling must append the raid target URL and emit the raid signal: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'signal raidReceived(string channel)' \
    'onRaidReceived:' \
    'root.raidReceived(channel)'
do
    if ! rg -q -F "$required" "$chat_qml" "$chat_view" "$chat_drawer"; then
        printf 'QML chat layers must propagate raid signals to the player: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Q_PROPERTY(bool autoRaidRedirect READ autoRaidRedirect WRITE setAutoRaidRedirect NOTIFY autoRaidRedirectChanged)' \
    'bool mAutoRaidRedirect = false;' \
    'bool autoRaidRedirect() const;' \
    'void setAutoRaidRedirect(bool autoRaidRedirect);' \
    'void autoRaidRedirectChanged();'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose the automatic raid redirect setting: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setAutoRaidRedirect(settings.value("autoRaidRedirect", mAutoRaidRedirect).toBool());' \
    'settings.setValue("autoRaidRedirect", autoRaidRedirect);' \
    'emit autoRaidRedirectChanged();'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist the automatic raid redirect setting: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Follow raids automatically"' \
    'checked: Settings.autoRaidRedirect' \
    'onClicked: Settings.autoRaidRedirect = checked'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose the automatic raid redirect toggle: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'if (Settings.autoRaidRedirect && channel && !isVod)' \
    'rootWindow.openChannelName(channel)'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must optionally follow live raids without redirecting VOD playback: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: Util.makeUrl(root.systemMessage)' \
    'textInteractionFlags: Qt.TextSelectableByMouse | Qt.TextSelectableByKeyboard | Qt.LinksAccessibleByMouse' \
    'onLinkActivated: linkActivation(link)' \
    'Qt.openUrlExternally(link)'
do
    if ! rg -q -F "$required" "$chat_message"; then
        printf 'ChatMessage must render system notices as selectable/clickable links: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -q 'cmd\.contains\("(PRIVMSG|USERNOTICE|WHISPER|NOTICE|GLOBALUSERSTATE|CLEARCHAT)"' "$irc_chat" \
    || rg -q 'const QString USERSTATE_CMD' "$irc_chat" \
    || rg -q 'cmd\.indexOf\(cmdKeyword\)|cmd\.indexOf\("HOSTTARGET"\)|cmd\.indexOf\("NOTICE"\)' "$irc_chat"; then
    printf 'IRC parser must not dispatch commands through substring matching.\n' >&2
    exit 1
fi

if ! rg -q 'tag\.key == "ban-reason"' "$irc_chat" \
    || ! rg -q 'tag\.key == "ban-duration"' "$irc_chat" \
    || ! rg -q 'Chat was cleared by a moderator\.' "$irc_chat"; then
    printf 'CLEARCHAT handling must parse moderation tags through the shared Tag parser and handle room clears.\n' >&2
    exit 1
fi

if ! rg -Fq 'badgesStr.split(",", Qt::SkipEmptyParts)' "$irc_chat" \
    || ! rg -q 'splitPos <= 0 \|\| splitPos == badgeStr\.length\(\) - 1' "$irc_chat"; then
    printf 'IRC badge parsing must skip empty and malformed badge/version entries.\n' >&2
    exit 1
fi

if rg -q 'getParamValue' "$irc_chat" "$repo_dir/src/model/ircchat.h"; then
    printf 'Obsolete IRC parameter substring parsing helper must not remain.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_irc_tag_parsing\.sh' "$workflow"; then
    printf 'CI workflow must run the IRC tag parsing guard.\n' >&2
    exit 1
fi
