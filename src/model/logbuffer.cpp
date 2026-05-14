#include "logbuffer.h"

#include <QMutexLocker>

LogBuffer::LogBuffer(QObject *parent)
    : QObject(parent)
{
}

LogBuffer *LogBuffer::getInstance()
{
    static LogBuffer *instance = new LogBuffer();
    return instance;
}

QString LogBuffer::text() const
{
    QMutexLocker locker(&mMutex);
    return mLines.join('\n');
}

void LogBuffer::appendLine(const QString &line)
{
    const QString trimmedLine = line.trimmed();
    if (trimmedLine.isEmpty()) {
        return;
    }

    {
        QMutexLocker locker(&mMutex);
        mLines.append(trimmedLine);
        while (mLines.size() > mMaxLines) {
            mLines.removeFirst();
        }
    }

    emit textChanged();
}

void LogBuffer::clear()
{
    {
        QMutexLocker locker(&mMutex);
        if (mLines.isEmpty()) {
            return;
        }
        mLines.clear();
    }

    emit textChanged();
}
