#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
channel_manager="$repo_dir/src/model/channelmanager.cpp"
channel_list_model="$repo_dir/src/model/channellistmodel.cpp"
notification_manager="$repo_dir/src/notification/notificationmanager.cpp"
notification_qml="$repo_dir/src/qml/components/Notification.qml"
options_view="$repo_dir/src/qml/OptionsView.qml"
settings_manager="$repo_dir/src/model/settingsmanager.cpp"
settings_manager_header="$repo_dir/src/model/settingsmanager.h"
qml_qrc="$repo_dir/src/qml/qml.qrc"

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

if ! rg -q 'timer = new QTimer\(this\);' "$notification_manager"; then
    printf 'NotificationManager timer must be parented to the manager.\n' >&2
    exit 1
fi

if ! rg -q 'delete currentObject;' "$notification_manager"; then
    printf 'NotificationManager must release any active QML notification object on shutdown.\n' >&2
    exit 1
fi

if rg -q 'QList<NotificationData\*>|new NotificationData|qDeleteAll\(queue\)' \
    "$repo_dir/src/notification/notificationmanager.h" \
    "$notification_manager"; then
    printf 'NotificationManager queue must store notification data by value instead of raw pointers.\n' >&2
    exit 1
fi

for required in \
    '#if !defined(Q_OS_MACOS) && !defined(Q_OS_LINUX)' \
    'QRect selectedNotificationGeometry()' \
    'const int requestedScreen = SettingsManager::getInstance()->alertScreen();' \
    'const int screenIndex = qMax(0, qMin(requestedScreen, screens.count() - 1));' \
    'QQmlComponent component(engine, QUrl(QStringLiteral("qrc:/components/Notification.qml")));' \
    'const QRect geometry = selectedNotificationGeometry();' \
    'currentObject->setProperty("screenX", geometry.x());' \
    'currentObject->setProperty("screenY", geometry.y());' \
    'currentObject->setProperty("screenWidth", geometry.width());' \
    'currentObject->setProperty("screenHeight", geometry.height());' \
    'currentObject->setProperty("location", SettingsManager::getInstance()->alertPosition());' \
    'currentObject->setProperty("visible", true);'
do
    if ! rg -q -F "$required" "$notification_manager"; then
        printf 'NotificationManager must keep the Windows in-app notification surface contract: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    '<file>components/Notification.qml</file>' \
    'property real screenX: 0' \
    'property real screenY: 0' \
    'property real screenWidth: Screen.width' \
    'property real screenHeight: Screen.height' \
    'property int location: Settings.alertPosition' \
    'case 0:' \
    'case 1:' \
    'case 2:' \
    'case 3:' \
    'setPosition()'
do
    if ! rg -q -F "$required" "$qml_qrc" "$notification_qml"; then
        printf 'Notification.qml must support configured notification screen geometry and corners: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Q_PROPERTY(int alertPosition READ alertPosition WRITE setAlertPosition NOTIFY alertPositionChanged)' \
    'Q_PROPERTY(int alertScreen READ alertScreen WRITE setAlertScreen NOTIFY alertScreenChanged)' \
    'int alertPosition() const;' \
    'void setAlertPosition(int alertPosition);' \
    'int alertScreen() const;' \
    'void setAlertScreen(int alertScreen);' \
    'void alertPositionChanged();' \
    'void alertScreenChanged();'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose notification corner and screen settings: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setAlertPosition(settings.value("alertPosition", mAlertPosition).toInt());' \
    'setAlertScreen(settings.value("alertScreen", mAlertScreen).toInt());' \
    'const int normalizedPosition = qMax(0, qMin(alertPosition, 3));' \
    'settings.setValue("alertPosition", normalizedPosition);' \
    'emit alertPositionChanged();' \
    'const int screenCount = QGuiApplication::screens().count();' \
    'const int normalizedScreen = qMax(0, qMin(alertScreen, maxScreen));' \
    'settings.setValue("alertScreen", normalizedScreen);' \
    'emit alertScreenChanged();'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist and clamp notification corner/screen settings: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Notification corner"' \
    'model: ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]' \
    'Component.onCompleted: currentIndex = Settings.alertPosition' \
    'onActivated: Settings.alertPosition = index' \
    'onAlertPositionChanged: alertPosition.currentIndex = Settings.alertPosition' \
    'text: "Notification screen"' \
    'model: Settings.screenNames()' \
    'Component.onCompleted: currentIndex = Settings.alertScreen' \
    'onActivated: Settings.alertScreen = index' \
    'onAlertScreenChanged: alertScreen.currentIndex = Settings.alertScreen'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose Windows notification corner/screen controls: %s\n' "$required" >&2
        exit 1
    fi
done

channel_manager_constructor=$(sed -n '/ChannelManager::ChannelManager()/,/^}/p' "$channel_manager")
followed_model_factory=$(sed -n '/ChannelListModel \*ChannelManager::createFollowedChannelsModel()/,/^}/p' "$channel_manager")
channel_manager_update_streams=$(sed -n '/void ChannelManager::updateStreams/,/^}/p' "$channel_manager")
channel_list_update_stream=$(sed -n '/bool ChannelListModel::updateStream/,/^}/p' "$channel_list_model")
channel_list_update_streams=$(sed -n '/void ChannelListModel::updateStreams/,/^}/p' "$channel_list_model")

if ! printf '%s\n' "$channel_manager_constructor" | rg -q 'resultsModel = new ChannelListModel\(\);' \
    || ! printf '%s\n' "$channel_manager_constructor" | rg -q 'favouritesModel = createFollowedChannelsModel\(\);'; then
    printf 'ChannelManager must keep search results separate from the notification-enabled followed-channel model.\n' >&2
    exit 1
fi

if printf '%s\n' "$channel_manager" | rg -q 'connect\(resultsModel, &ChannelListModel::(channelOnlineStateChanged|multipleChannelsChangedOnline)'; then
    printf 'Search results must not be connected to online/offline notification slots.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$followed_model_factory" | rg -q 'connect\(model, &ChannelListModel::channelOnlineStateChanged, this, &ChannelManager::notify\);' \
    || ! printf '%s\n' "$followed_model_factory" | rg -q 'connect\(model, &ChannelListModel::multipleChannelsChangedOnline, this, &ChannelManager::notifyMultipleChannelsOnline\);'; then
    printf 'Followed-channel model must be the only model wired to channel online notification slots.\n' >&2
    exit 1
fi

if [ "$(rg -c '&ChannelListModel::channelOnlineStateChanged' "$channel_manager")" -ne 1 ] \
    || [ "$(rg -c '&ChannelListModel::multipleChannelsChangedOnline' "$channel_manager")" -ne 1 ]; then
    printf 'Channel online notification signals must only be connected once through createFollowedChannelsModel.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_manager_update_streams" | rg -q 'favouritesModel->updateStreams\(list\);' \
    || ! printf '%s\n' "$channel_manager_update_streams" | rg -q 'resultsModel->updateStreams\(list\);' \
    || ! printf '%s\n' "$channel_manager_update_streams" | rg -q 'qDeleteAll\(list\);'; then
    printf 'ChannelManager::updateStreams must refresh both models while leaving notification delivery isolated to favourites.\n' >&2
    exit 1
fi

if printf '%s\n' "$channel_list_update_stream" | rg -q '^[[:space:]]*emit channelOnlineStateChanged' \
    || printf '%s\n' "$channel_list_update_stream" | rg -q '^[[:space:]]*emit multipleChannelsChangedOnline'; then
    printf 'ChannelListModel::updateStream must report state changes without directly sending notifications.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_list_update_stream" | rg -q 'if \(channel->isOnline\(\) != item->isOnline\(\)\)' \
    || ! printf '%s\n' "$channel_list_update_stream" | rg -q 'onlineStateChanged = true;' \
    || ! printf '%s\n' "$channel_list_update_streams" | rg -q 'if \(updateStream\(channel\)\)' \
    || ! printf '%s\n' "$channel_list_update_streams" | rg -q 'onlineChannels << channel;' \
    || ! printf '%s\n' "$channel_list_update_streams" | rg -q 'emit channelOnlineStateChanged\(channel\);' \
    || ! printf '%s\n' "$channel_list_update_streams" | rg -q 'emit multipleChannelsChangedOnline\(onlineChannels\);'; then
    printf 'ChannelListModel must only emit online notification signals after a real online-state transition.\n' >&2
    exit 1
fi
