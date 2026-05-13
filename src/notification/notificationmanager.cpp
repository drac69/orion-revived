/*
 * Copyright © 2015-2016 Antti Lamminsalo
 *
 * This file is part of Orion.
 *
 * Orion is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU General Public License
 * along with Orion.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "notificationmanager.h"
#include "../model/settingsmanager.h"
#include <QGuiApplication>
#include <QRect>
#include <QScreen>
#include <QVariant>
#include <QDebug>

namespace {
#if !defined(Q_OS_MAC) && !defined(Q_OS_LINUX)
QRect selectedNotificationGeometry()
{
    const QList<QScreen *> screens = QGuiApplication::screens();
    if (screens.isEmpty())
        return QRect(0, 0, 800, 600);

    const int requestedScreen = SettingsManager::getInstance()->alertScreen();
    const int screenIndex = qMax(0, qMin(requestedScreen, screens.count() - 1));
    return screens.at(screenIndex)->availableGeometry();
}
#endif
}

NotificationManager::NotificationManager(QQmlApplicationEngine *engine, QNetworkAccessManager *nm, QObject *parent) :
    QObject(parent),
    net(nm)
{
    currentObject = nullptr;

    queue.clear();

    timer = new QTimer();
    connect(timer, &QTimer::timeout, this, &NotificationManager::showNext);
    timer->setInterval(3000);
    timer->setSingleShot(true);

    this->engine = engine;
}

NotificationManager::~NotificationManager()
{
    timer->stop();
    delete timer;

    qDeleteAll(queue);
    queue.clear();
}

void NotificationManager::showNext()
{
    //Pops first in queue, and shows it
    if (currentObject){
        currentObject->deleteLater();
        currentObject = nullptr;
    }

    if (!queue.isEmpty()){
        NotificationData *data = queue.takeFirst();

#if defined(Q_OS_MAC) || defined (Q_OS_LINUX)
        //NotificationSender deletes itself after displaying message
        NotificationSender *msg = new NotificationSender(net);
        msg->pushNotification(data->title, data->message, data->imgUrl);
#else
        QQmlComponent component(engine, QUrl(QStringLiteral("qrc:/components/Notification.qml")));
        currentObject = component.create();

        if (currentObject) {
            const QRect geometry = selectedNotificationGeometry();
            currentObject->setProperty("screenX", geometry.x());
            currentObject->setProperty("screenY", geometry.y());
            currentObject->setProperty("screenWidth", geometry.width());
            currentObject->setProperty("screenHeight", geometry.height());
            currentObject->setProperty("location", SettingsManager::getInstance()->alertPosition());
            currentObject->setProperty("title", data->title);
            currentObject->setProperty("description", data->message);
            currentObject->setProperty("imgSrc", data->imgUrl);
            currentObject->setProperty("visible", true);
        } else {
            qDebug() << "Error loading notification component:" << component.errors();
        }
#endif
        delete data;

        timer->start();
    }
}

void NotificationManager::pushNotification(const QString &title, const QString &message, const QString &imgUrl)
{
    NotificationData *data = new NotificationData;
    data->title = title;
    data->message = message;
    data->imgUrl = imgUrl;

    queue.append(data);

    if (!timer->isActive()){
        showNext();
    }
}
