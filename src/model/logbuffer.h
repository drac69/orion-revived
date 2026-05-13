#ifndef LOGBUFFER_H
#define LOGBUFFER_H

#include <QObject>
#include <QMutex>
#include <QString>
#include <QStringList>

#include "singletonprovider.h"

class LogBuffer : public QObject
{
    ORION_QML_SINGLETON
    Q_OBJECT
    Q_PROPERTY(QString text READ text NOTIFY textChanged)

    QStringList mLines;
    mutable QMutex mMutex;
    int mMaxLines = 500;

    explicit LogBuffer(QObject *parent = nullptr);

public:
    static LogBuffer *getInstance();

    QString text() const;
    void appendLine(const QString &line);

    Q_INVOKABLE void clear();

signals:
    void textChanged();
};

#endif // LOGBUFFER_H
