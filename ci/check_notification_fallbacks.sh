#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

for source_file in "$repo_dir/src/notification/notificationsender.cpp" "$repo_dir/src/notification/notificationsender.mm"; do
    if rg -Uq 'else\s+pushNotification\(this->title, this->subtitle\)' "$source_file"; then
        printf '%s must not recurse when sending notifications without images.\n' "$source_file" >&2
        exit 1
    fi

    if ! rg -q 'sendNotification\(this->title, this->subtitle\)' "$source_file"; then
        printf '%s must send notifications directly when no image URL is available.\n' "$source_file" >&2
        exit 1
    fi

    if ! rg -q 'imageUrl\.scheme\(\) == "qrc"' "$source_file"; then
        printf '%s must load bundled qrc notification images directly.\n' "$source_file" >&2
        exit 1
    fi

    if ! rg -q 'sendNotification\(title, subtitle\);' "$source_file"; then
        printf '%s must still show text notifications when image loading fails.\n' "$source_file" >&2
        exit 1
    fi

    if rg -q 'SIGNAL\(|SLOT\(' "$source_file"; then
        printf '%s must use type-checked signal/slot connections.\n' "$source_file" >&2
        exit 1
    fi
done

if ! rg -q 'this->deleteLater\(\);' "$repo_dir/src/notification/notificationsender.cpp"; then
    printf 'Linux NotificationSender must delete itself after sending.\n' >&2
    exit 1
fi

if ! rg -q 'if \(!reply\)' "$repo_dir/src/notification/notificationsender.cpp"; then
    printf 'Linux NotificationSender must guard unexpected non-reply senders before reading image replies.\n' >&2
    exit 1
fi
