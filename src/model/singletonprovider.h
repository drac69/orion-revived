#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QJSEngine>

///\brief
/// Orion QML singleton provider macro
/// Needs getInstance()-method defined when used.
/// Use on begin of class declaration
///

#define ORION_QML_SINGLETON \
    public: \
    static QObject *provider(QQmlEngine */*eng*/, QJSEngine */*jseng*/) {           \
        QQmlEngine::setObjectOwnership(getInstance(), QQmlEngine::CppOwnership);    \
        return getInstance();                                                       \
    }   \
    protected:
