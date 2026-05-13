#pragma once

#include <QObject>
#include "../model/singletonprovider.h"

#ifdef Q_OS_WIN
    #include <Windows.h>
#endif

class Power: public QObject
{
    ORION_QML_SINGLETON
    Q_OBJECT

    Q_PROPERTY(bool screensaver READ screensaver WRITE setScreensaver)

    Power();

public:
    static Power *getInstance();
    ~Power();

    bool screensaver() const;
    Q_INVOKABLE void setScreensaver(bool);

private:
    quint32 cookie;
    bool screensaverEnabled;

    // QObject interface
protected:
    void timerEvent(QTimerEvent *event);
};
