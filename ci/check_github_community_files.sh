#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

require_file() {
    local file=$1

    if [[ ! -s "$file" ]]; then
        printf 'Missing or empty GitHub community file: %s\n' "${file#"$repo_dir"/}" >&2
        exit 1
    fi
}

require_token() {
    local file=$1
    local token=$2
    local description=$3

    if ! rg -Fq "$token" "$file"; then
        printf '%s is missing %s\n' "${file#"$repo_dir"/}" "$description" >&2
        exit 1
    fi
}

support="$repo_dir/SUPPORT.md"
security="$repo_dir/SECURITY.md"
pull_request="$repo_dir/.github/pull_request_template.md"
issue_config="$repo_dir/.github/ISSUE_TEMPLATE/config.yml"

for file in "$support" "$security" "$pull_request" "$issue_config"; do
    require_file "$file"
done

require_token "$support" "current \`modernize-maintenance\` branch" "current-branch support scope"
require_token "$support" "latest GitHub Release" "latest-release support scope"
require_token "$support" "Linux and FreeBSD source builds" "desktop source-build scope"
require_token "$support" "macOS source builds validated by GitHub Actions" "macOS source-build scope"
require_token "$support" "Windows source builds validated by GitHub Actions" "Windows source-build scope"
require_token "$support" "Source-level Android metadata and manifest checks" "Android source-maintenance scope"
require_token "$support" "Signed Windows installers" "unsigned Windows packaging caveat"
require_token "$support" "Signed or notarized macOS packages" "unsigned macOS packaging caveat"
require_token "$support" "Play Store packages, F-Droid packages, or APK releases" "Android package caveat"
require_token "$support" "Unsupported native HLS playlist-token behavior, VOD replay chat" "Twitch API fallback caveat"
require_token "$support" "Do not paste OAuth tokens" "credential redaction warning"

require_token "$security" "current \`modernize-maintenance\` branch" "security support scope"
require_token "$security" "latest GitHub Release" "security release scope"
require_token "$security" "Android packages, signed Windows installers, and signed or notarized macOS" "unsupported artifact caveat"
require_token "$security" "Do not disclose exploitable details" "responsible disclosure warning"
require_token "$security" "OAuth tokens, Twitch client secrets" "credential redaction warning"
require_token "$security" "GitHub private vulnerability reporting" "private reporting path"

require_token "$pull_request" "## Summary" "summary section"
require_token "$pull_request" "## Validation" "validation section"
require_token "$pull_request" "Scope checklist" "scope checklist"
require_token "$pull_request" "focused CI guard" "CI guard checklist item"
require_token "$pull_request" "Twitch API changes are backed by current official Twitch documentation" "Twitch documentation checklist item"
require_token "$pull_request" "Android changes include the Qt/SDK/NDK/toolchain versions" "Android validation checklist item"
require_token "$pull_request" "do not claim signed Windows installers" "packaging claim checklist item"
require_token "$pull_request" "OAuth tokens, Twitch client secrets" "credential redaction checklist item"

require_token "$issue_config" "Support policy" "support policy contact link"
