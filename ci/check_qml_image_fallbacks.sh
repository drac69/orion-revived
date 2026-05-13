#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

channel_cpp="$repo_dir/src/model/channel.cpp"
channel_header="$repo_dir/src/model/channel.h"
channel_manager_header="$repo_dir/src/model/channelmanager.h"
qml_resource="$repo_dir/src/qml/qml.qrc"
channel_card="$repo_dir/src/qml/components/Channel.qml"
grid_tooltip="$repo_dir/src/qml/components/GridTooltip.qml"
info_drawer="$repo_dir/src/qml/components/InfoDrawer.qml"
round_image="$repo_dir/src/qml/components/RoundImage.qml"
notification="$repo_dir/src/qml/components/Notification.qml"
image_provider="$repo_dir/src/model/imageprovider.cpp"

if ! rg -q 'setPreviewurl\(other\.previewuri\)' "$channel_cpp"; then
    printf 'Channel::updateWith must refresh non-empty preview URLs.\n' >&2
    exit 1
fi

for default_logo_header in "$channel_header" "$channel_manager_header"; do
    if ! rg -q '#define DEFAULT_LOGO_URL\s+"qrc:/icon/orion\.ico"' "$default_logo_header"; then
        printf '%s must use the bundled icon as the default logo.\n' "$default_logo_header" >&2
        exit 1
    fi
done

if ! rg -q '<file>icon/orion\.ico</file>' "$qml_resource"; then
    printf 'qml.qrc must bundle icon/orion.ico for image fallbacks.\n' >&2
    exit 1
fi

for fallback_image in "$channel_card" "$grid_tooltip" "$round_image" "$notification"; do
    if ! rg -q 'Image\.Error' "$fallback_image" || ! rg -q 'qrc:/icon/orion\.ico' "$fallback_image"; then
        printf '%s must fall back to the bundled icon on image load errors.\n' "$fallback_image" >&2
        exit 1
    fi
done

if ! rg -q 'Image\.Error' "$info_drawer" || ! rg -q 'source = ""' "$info_drawer"; then
    printf 'InfoDrawer background image errors must clear the failed remote source.\n' >&2
    exit 1
fi

if rg -q 'img\.source\s*=\s*game\.preview' "$grid_tooltip"; then
    printf 'GridTooltip must route game previews through previewSource fallback handling.\n' >&2
    exit 1
fi

if ! rg -q 'previewSource\s*=\s*game\.preview' "$grid_tooltip"; then
    printf 'GridTooltip must set previewSource for game previews.\n' >&2
    exit 1
fi

if [ "$(rg -c 'if \(!_reply\)' "$image_provider")" -lt 3 ]; then
    printf 'ImageProvider download slots must guard unexpected non-reply senders.\n' >&2
    exit 1
fi

if ! rg -q '_file\.cancelWriting\(\)' "$image_provider"; then
    printf 'ImageProvider must cancel partial writes when a download finishes without a reply sender.\n' >&2
    exit 1
fi

if rg -q 'qobject_cast<DownloadHandler\*>\(sender\(\)\)' "$image_provider"; then
    printf 'ImageProvider must pass download keys through typed signals instead of recovering them from sender().\n' >&2
    exit 1
fi

if ! rg -q 'emit downloadComplete\(_file\.fileName\(\), key, hadError\)' "$image_provider"; then
    printf 'DownloadHandler must emit the image key with successful download completion.\n' >&2
    exit 1
fi

if ! rg -q 'emit downloadComplete\(_file\.fileName\(\), key, true\)' "$image_provider"; then
    printf 'DownloadHandler must emit the image key with failed download completion.\n' >&2
    exit 1
fi

if ! rg -q 'dh, &QObject::deleteLater' "$image_provider"; then
    printf 'ImageProvider must delete DownloadHandler instances through a typed completion connection.\n' >&2
    exit 1
fi
