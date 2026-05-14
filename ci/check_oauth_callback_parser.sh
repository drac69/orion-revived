#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$repo_dir/src/network/httpserver.cpp"
header_file="$repo_dir/src/network/httpserver.h"
options_view="$repo_dir/src/qml/OptionsView.qml"

fail=0

for required in \
    '#include <QUrlQuery>' \
    'queryItemValue(QStringLiteral("access_token"), QUrl::FullyDecoded)' \
    'queryItemValue(QStringLiteral("state"), QUrl::FullyDecoded)' \
    'queryItemValue(QStringLiteral("error"), QUrl::FullyDecoded)' \
    'callbackUrl.fragment()' \
    'QUuid::createUuid().toString(QUuid::WithoutBraces)' \
    'stateMatches' \
    'listenError = true' \
    'listenError = false'
do
    if ! rg -qF "$required" "$source_file"; then
        printf 'OAuth callback parser is missing required token: %s\n' "$required" >&2
        fail=1
    fi
done

for required in \
    'QString m_state;' \
    'Q_INVOKABLE QString state() const;' \
    'Q_INVOKABLE bool isOk() const;'
do
    if ! rg -qF "$required" "$header_file"; then
        printf 'OAuth callback state contract is missing required token: %s\n' "$required" >&2
        fail=1
    fi
done

for required in \
    '&state=' \
    'encodeURIComponent(LoginService.state())' \
    'function twitchLoginScopes()' \
    'function twitchLoginUrl()' \
    'encodeURIComponent(twitchLoginScopes().join(" "))' \
    'if (!LoginService.isOk())' \
    'Login server unavailable'
do
    if ! rg -qF "$required" "$options_view"; then
        printf 'OAuth login URL is missing required state token: %s\n' "$required" >&2
        fail=1
    fi
done

for forbidden in 'split("&")' 'split("=")' 'QMap<QString,QString>'; do
    if rg -qF "$forbidden" "$source_file"; then
        printf 'OAuth callback parser must use QUrlQuery instead of ad hoc query splitting.\n' >&2
        fail=1
    fi
done

if rg -q 'Got code.*code|access token.*<<.*code|code.*<<.*access token' "$source_file"; then
    printf 'OAuth callback handling must not log the access token value.\n' >&2
    fail=1
fi

exit "$fail"
