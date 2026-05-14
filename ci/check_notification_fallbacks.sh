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

    if ! rg -q 'if \(!reply\)' "$source_file"; then
        printf '%s must guard unexpected non-reply senders before reading image replies.\n' "$source_file" >&2
        exit 1
    fi
done

if ! rg -q 'this->deleteLater\(\);' "$repo_dir/src/notification/notificationsender.cpp"; then
    printf 'Linux NotificationSender must delete itself after sending.\n' >&2
    exit 1
fi

if ! rg -q 'timer = new QTimer\(this\);' "$repo_dir/src/notification/notificationmanager.cpp"; then
    printf 'NotificationManager timer must be parented to the manager.\n' >&2
    exit 1
fi

if ! rg -q 'delete currentObject;' "$repo_dir/src/notification/notificationmanager.cpp"; then
    printf 'NotificationManager must release any active QML notification object on shutdown.\n' >&2
    exit 1
fi

if rg -q 'QList<NotificationData\*>|new NotificationData|qDeleteAll\(queue\)' \
    "$repo_dir/src/notification/notificationmanager.h" \
    "$repo_dir/src/notification/notificationmanager.cpp"; then
    printf 'NotificationManager queue must store notification data by value instead of raw pointers.\n' >&2
    exit 1
fi
