#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=${ORION_CI_CONTAINER_IMAGE:-ubuntu:24.04}
volume_suffix=${ORION_CI_CONTAINER_VOLUME_SUFFIX:-:Z}
engine=${CONTAINER_ENGINE:-}

if [[ -z "$engine" ]]; then
    if command -v podman >/dev/null 2>&1; then
        engine=podman
    elif command -v docker >/dev/null 2>&1; then
        engine=docker
    else
        printf 'podman or docker is required for the Ubuntu container CI check.\n' >&2
        exit 127
    fi
fi

"$engine" run --rm -i \
    -v "$repo_dir:/work$volume_suffix" \
    -w /work \
    "$image" \
    bash -s <<'CONTAINER_SCRIPT'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates git nodejs sudo

ORION_CI_APT_RETRIES="${ORION_CI_APT_RETRIES:-1}" \
    ci/install_ubuntu_ci_deps.sh libmpv-dev qtmultimedia5-dev qml-module-qtmultimedia

appstreamcli validate --pedantic --no-net distfiles/Orion.appdata.xml
desktop-file-validate distfiles/Orion.desktop

static_scripts=(
    ci/check_legacy_ci_guard.sh
    ci/check_shell_scripts.sh
    ci/check_build_docs.sh
    ci/check_release_readiness.sh
    ci/check_workflow_hygiene.sh
    ci/check_github_issue_templates.sh
    ci/check_github_community_files.sh
    ci/check_version_checker.sh
    ci/check_patch_whitespace.sh
    ci/check_upstream_issue_triage.sh
    ci/check_twitch_api_guard.sh
    ci/check_oauth_callback_parser.sh
    ci/check_oauth_token_validation.sh
    ci/check_twitch_emote_ids.sh
    ci/check_irc_tag_parsing.sh
    ci/check_android_metadata.sh
    ci/check_fdroid_metadata.sh
    ci/check_apple_metadata.sh
    ci/check_qml_resources.sh
    ci/check_qml_runtime_deps.sh
    ci/check_qml_fonts.sh
    ci/check_qml_image_fallbacks.sh
    ci/check_notification_fallbacks.sh
    ci/check_logging_contracts.sh
    ci/check_modern_qt_helpers.sh
    ci/check_qml_window_contracts.sh
    ci/check_qml_emote_picker_contracts.sh
    ci/check_qml_vod_view_contracts.sh
    ci/check_qml_util_html.sh
    ci/check_playback_recovery.sh
    ci/check_m3u8_parser.sh
)

for script in "${static_scripts[@]}"; do
    "$script"
done

build_backend() {
    local name=$1
    shift
    local build_dir="/tmp/orion-build-$name"
    local install_root="/tmp/orion-install-$name"

    rm -rf "$build_dir" "$install_root"
    mkdir -p "$build_dir"

    (
        cd "$build_dir"
        /work/ci/run_qmake.sh /work/orion.pro "$@"
        make -j"$(nproc)"
        make INSTALL_ROOT="$install_root" install
    )

    test -x "$install_root/usr/bin/orion"
    test -f "$install_root/usr/share/metainfo/Orion.appdata.xml"
    test -f "$install_root/usr/share/applications/Orion.desktop"
    test -f "$install_root/usr/share/icons/hicolor/scalable/apps/orion.svg"
}

build_backend mpv CONFIG+=mpv
build_backend multimedia CONFIG+=multimedia
build_backend mpv-multimedia CONFIG+=mpv CONFIG+=multimedia
CONTAINER_SCRIPT
