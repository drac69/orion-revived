#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$repo_dir/src/network/networkmanager.cpp"
header_file="$repo_dir/src/network/networkmanager.h"

fail=0

for required in \
    'https://id.twitch.tv/oauth2/validate' \
    'Authorization", ("OAuth " + access_token)' \
    'accessTokenValidator.setInterval(60 * 60 * 1000)' \
    'connect(&accessTokenValidator, &QTimer::timeout, this, &NetworkManager::validateAccessToken)' \
    'accessTokenValidator.stop()' \
    'SettingsManager::getInstance()->setAccessToken(QString())' \
    'tokenClientId != getClientId()'
do
    if ! rg -qF "$required" "$source_file"; then
        printf 'OAuth token validation is missing required token: %s\n' "$required" >&2
        fail=1
    fi
done

for required in \
    'void validateAccessToken();' \
    'bool access_token_validation_pending = false;' \
    'void accessTokenValidationReply();' \
    'QTimer accessTokenValidator;'
do
    if ! rg -qF "$required" "$header_file"; then
        printf 'OAuth token validation header contract is missing token: %s\n' "$required" >&2
        fail=1
    fi
done

if rg -q 'access_token.*<<|<<.*access_token|validatedToken.*<<|<<.*validatedToken' "$source_file"; then
    printf 'OAuth token validation must not log token values.\n' >&2
    fail=1
fi

exit "$fail"
