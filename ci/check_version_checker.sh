#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
network_manager="$repo_dir/src/network/networkmanager.cpp"
network_manager_header="$repo_dir/src/network/networkmanager.h"
json_parser="$repo_dir/src/util/jsonparser.cpp"
settings_manager="$repo_dir/src/model/settingsmanager.cpp"
triage="$repo_dir/docs/upstream-issue-triage.md"
workflow="$repo_dir/.github/workflows/ci.yml"

if rg -q 'api\.github\.com/repos/alamminsalo/orion|github\.com/alamminsalo/orion/releases' \
    "$network_manager" "$json_parser" "$settings_manager"; then
    printf 'Version checker must not query the archived upstream repository.\n' >&2
    exit 1
fi

if ! rg -q 'https://api\.github\.com/repos/belagrf/orion-revived/releases/latest' "$network_manager" \
    || ! rg -q 'https://api\.github\.com/repos/belagrf/orion-revived/tags\?per_page=100' "$network_manager"; then
    printf 'Version checker must query the formal fork releases and fall back to the formal fork tags.\n' >&2
    exit 1
fi

if ! rg -q 'void checkVersionTags\(\);' "$network_manager_header" \
    || ! rg -q 'void NetworkManager::checkVersionTags\(\)' "$network_manager" \
    || ! rg -q 'status == 404' "$network_manager" \
    || ! rg -q 'checkVersionTags\(\);' "$network_manager"; then
    printf 'Version checker must fall back to tags when GitHub has no latest release.\n' >&2
    exit 1
fi

if ! rg -q 'githubTagUrl' "$network_manager" \
    || ! rg -q 'https://github\.com/belagrf/orion-revived/tree/%1' "$network_manager" \
    || ! rg -q 'QUrl::toPercentEncoding\(tag\)' "$network_manager"; then
    printf 'Version tag checks must return a usable formal fork tag URL.\n' >&2
    exit 1
fi

if ! rg -q 'json\["tag_name"\]' "$json_parser" \
    || ! rg -q 'doc\.isArray\(\)' "$json_parser" \
    || ! rg -q 'normalizedVersionNumberText' "$json_parser" \
    || ! rg -q 'QVersionNumber latest' "$json_parser"; then
    printf 'Version JSON parser must handle GitHub release objects and semantic tag arrays.\n' >&2
    exit 1
fi

if ! rg -q 'semanticVersionFromString' "$settings_manager" \
    || ! rg -q '!candidate\.isNull\(\) && !current\.isNull\(\) && candidate > current' "$settings_manager"; then
    printf 'Version comparison must reject invalid version strings before comparing.\n' >&2
    exit 1
fi

if ! rg -q '#44:' "$triage" \
    || ! rg -q "falls back to this fork's semantic" "$triage" \
    || ! rg -q 'fork release/tag endpoints' "$triage"; then
    printf 'Upstream issue triage must document the release/tag version-check behavior.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_version_checker\.sh' "$workflow"; then
    printf 'CI workflow must run the version checker guard.\n' >&2
    exit 1
fi
