#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
irc_chat="$repo_dir/src/model/ircchat.cpp"
triage="$repo_dir/docs/upstream-issue-triage.md"
workflow="$repo_dir/.github/workflows/ci.yml"

if ! rg -q 'QString unescapeIrcTagValue\(const QString &value\)' "$irc_chat"; then
    printf 'IRC chat parser must centralize message-tag value unescaping.\n' >&2
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

if ! rg -q 'ci/check_irc_tag_parsing\.sh' "$workflow"; then
    printf 'CI workflow must run the IRC tag parsing guard.\n' >&2
    exit 1
fi
