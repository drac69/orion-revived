#ifndef HTTPSERVER_H
#define HTTPSERVER_H

#include <QTcpServer>
#include <QTcpSocket>
#include <QDebug>

#include "../model/singletonprovider.h"

class HttpServer: public QObject
{
    ORION_QML_SINGLETON
    Q_OBJECT

    QTcpServer *server = nullptr;

    bool listenError = false;
    QString m_port;
    QString m_state;

    explicit HttpServer(QObject *parent = nullptr);
public:
    static HttpServer *getInstance();

    Q_INVOKABLE QString port();
    Q_INVOKABLE QString state() const;

    bool isOk() const;

public slots:
    // starts server
    void start();

    // destroys server
    void stop();

    void onConnect();

    void onRead();

signals:
    void codeReceived(QString code);
    void error();
};

#endif // HTTPSERVER_H
