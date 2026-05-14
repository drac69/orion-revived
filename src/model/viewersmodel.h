#ifndef VIEWERSMODEL_H
#define VIEWERSMODEL_H

#include <QObject>
#include "singletonprovider.h"
#include "../network/networkmanager.h"

class ViewersModel : public QObject
{
    ORION_QML_SINGLETON
    Q_OBJECT

    NetworkManager *netman;
    static ViewersModel *instance;

    explicit ViewersModel(QObject *parent = nullptr);

public:
    static ViewersModel *getInstance();

signals:
    void chatterListLoaded(QVariantMap chatters);

public slots:
    void loadChatterList(const QString channel, const quint64 broadcasterId = 0, const quint64 moderatorId = 0);
    void processChatterList(QMap<QString, QList<QString>> chatters);

};

#endif // VIEWERSMODEL_H
