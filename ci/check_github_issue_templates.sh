#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
template_dir="$repo_dir/.github/ISSUE_TEMPLATE"

require_file() {
    local file=$1

    if [[ ! -s "$file" ]]; then
        printf 'Missing or empty issue template: %s\n' "${file#"$repo_dir"/}" >&2
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

config="$template_dir/config.yml"
bug="$template_dir/bug_report.yml"
feature="$template_dir/feature_request.yml"
android="$template_dir/android_validation.yml"
twitch="$template_dir/twitch_api_gap.yml"

for file in "$config" "$bug" "$feature" "$android" "$twitch"; do
    require_file "$file"
done

require_token "$config" "blank_issues_enabled: false" "disabled blank issues"
require_token "$config" "Current releases" "release contact link"
require_token "$config" "Upstream issue triage" "upstream triage contact link"

for form in "$bug" "$feature" "$android" "$twitch"; do
    require_token "$form" "name:" "form name"
    require_token "$form" "description:" "form description"
    require_token "$form" "title:" "default issue title"
    require_token "$form" "body:" "issue form body"
    require_token "$form" "validations:" "required-field validations"
    require_token "$form" "Do not paste OAuth tokens" "credential redaction warning"
    require_token "$form" "required: true" "required user inputs"
done

require_token "$bug" "Version or commit" "build identity field"
require_token "$bug" "Platform" "platform field"
require_token "$bug" "Build or package source" "build source field"
require_token "$bug" "Twitch auth mode" "Twitch auth mode field"
require_token "$bug" "orion --debug" "debug log guidance"
require_token "$bug" "docs/upstream-issue-triage.md" "upstream triage reminder"

require_token "$feature" "Twitch API/Product dependency" "Twitch API dependency field"
require_token "$feature" "official Twitch documentation" "official Twitch documentation guidance"
require_token "$feature" "unsupported Twitch-native HLS, replay chat, and rewards-credit APIs" "unsupported Twitch API acknowledgement"

require_token "$android" "Target device" "target device field"
require_token "$android" "Build recipe" "Android build recipe field"
require_token "$android" "Playback pause/resume" "playback validation prompt"
require_token "$android" "Phone-call/audio-focus behavior" "audio-focus validation prompt"
require_token "$android" "Lifecycle/backgrounding behavior" "lifecycle validation prompt"
require_token "$android" "adb logcat" "Android logcat guidance"
require_token "$android" "docs/android.md" "Android status reminder"

require_token "$twitch" "Current official Twitch documentation" "official Twitch docs field"
require_token "$twitch" "Native HLS playback token or playlist loading" "native HLS API option"
require_token "$twitch" "VOD replay chat" "VOD replay chat API option"
require_token "$twitch" "Drops or rewards credit" "drops or rewards API option"
require_token "$twitch" "Existing fallback" "fallback field"
