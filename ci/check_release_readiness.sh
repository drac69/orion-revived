#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readiness="$repo_dir/docs/release-readiness.md"
readme="$repo_dir/README.md"
issue_config="$repo_dir/.github/ISSUE_TEMPLATE/config.yml"

require_token() {
    local file=$1
    local token=$2
    local description=$3

    if ! rg -Fq "$token" "$file"; then
        printf '%s is missing %s\n' "${file#"$repo_dir"/}" "$description" >&2
        exit 1
    fi
}

if [[ ! -s "$readiness" ]]; then
    printf 'Missing release readiness document: docs/release-readiness.md\n' >&2
    exit 1
fi

require_token "$readiness" "source-only release \`v1.6.9\`" "current source-only release status"
require_token "$readiness" "GitHub Actions validates the maintained source-build matrix" "CI matrix scope"
require_token "$readiness" "Linux Qt5/mpv" "Linux mpv source-build coverage"
require_token "$readiness" "Linux Qt5/Qt Multimedia" "Linux Qt Multimedia source-build coverage"
require_token "$readiness" "Linux Qt5/mpv plus Qt Multimedia" "Linux combined source-build coverage"
require_token "$readiness" "macOS Qt5/mpv" "macOS source-build coverage"
require_token "$readiness" "Windows Qt5/mpv" "Windows source-build coverage"
require_token "$readiness" "signed installers" "installer claim caveat"
require_token "$readiness" "notarized \`.app\` bundles" "macOS notarization caveat"
require_token "$readiness" "Android packages, Play Store packages, F-Droid packages" "Android release-channel caveat"
require_token "$readiness" "metadata/app.orion.android.yml" "F-Droid metadata evidence"
require_token "$readiness" "must stay disabled" "Android/F-Droid disabled status"
require_token "$readiness" "twitch.tv fallback" "Twitch fallback path"
require_token "$readiness" "Unsupported Twitch playlist-token" "unsupported Twitch native API blocker"
require_token "$readiness" "Do not ship a Twitch client secret" "Twitch secret packaging warning"
require_token "$readiness" "https://github.com/belagrf/orion-revived/issues/1" "Twitch blocker issue link"
require_token "$readiness" "https://github.com/belagrf/orion-revived/issues/2" "Android blocker issue link"
require_token "$readiness" "https://github.com/belagrf/orion-revived/issues/3" "desktop release blocker issue link"

require_token "$readme" "docs/release-readiness.md" "release readiness link"
require_token "$issue_config" "Release readiness" "release readiness contact link"
require_token "$issue_config" "docs/release-readiness.md" "release readiness contact URL"
