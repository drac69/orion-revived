#include "httpserver.h"

#include <QUuid>
#include <QUrl>
#include <QUrlQuery>

namespace {

QString requestTarget(const QByteArray &request)
{
    const QList<QByteArray> lines = request.split('\n');
    if (lines.isEmpty())
        return QString();

    const QList<QByteArray> parts = lines.first().trimmed().split(' ');
    if (parts.size() < 2 || parts.first() != "GET")
        return QString();

    return QString::fromUtf8(parts.at(1));
}

QUrlQuery queryFromTarget(const QString &target)
{
    if (target.isEmpty())
        return QUrlQuery();

    QUrl callbackUrl(QStringLiteral("http://localhost") + target);
    QUrlQuery query(callbackUrl);
    if (!query.hasQueryItem(QStringLiteral("access_token")) && !callbackUrl.fragment().isEmpty())
        query = QUrlQuery(callbackUrl.fragment());

    return query;
}

QString accessTokenFromQuery(const QUrlQuery &query)
{
    return query.queryItemValue(QStringLiteral("access_token"), QUrl::FullyDecoded).trimmed();
}

QString stateFromQuery(const QUrlQuery &query)
{
    return query.queryItemValue(QStringLiteral("state"), QUrl::FullyDecoded).trimmed();
}

QString errorFromQuery(const QUrlQuery &query)
{
    return query.queryItemValue(QStringLiteral("error"), QUrl::FullyDecoded).trimmed();
}

}

HttpServer::HttpServer(QObject *parent): QObject(parent)
{

}

HttpServer *HttpServer::getInstance() {
    static HttpServer *instance = new HttpServer();
    return instance;
}

QString HttpServer::port() {
    return m_port;
}

QString HttpServer::state() const
{
    return m_state;
}

bool HttpServer::isOk() const
{
    return !listenError;
}

void HttpServer::start() {
    if (server) {
        stop();
    }

    server = new QTcpServer(this);
    m_state = QUuid::createUuid().toString(QUuid::WithoutBraces);

    /// IMPORTANT!
    quint16 port = 8979;

    connect(server, &QTcpServer::newConnection, this, &HttpServer::onConnect);
    if (!server->listen(QHostAddress::LocalHost, port)) {
        listenError = true;
        emit error();
        return;
    }

    listenError = false;
    m_port = QString::number(port);

    qDebug() << "listening port" << m_port;
}

void HttpServer::stop() {
    if (server) {
        qDebug() << "Stopping server";
        server->deleteLater();
        server = nullptr;
    }
    m_state.clear();
}

void HttpServer::onConnect() {
    qDebug()<<"Connected";
    QTcpSocket *socket = server->nextPendingConnection();
    connect(socket, &QTcpSocket::readyRead, this, &HttpServer::onRead);
}

void HttpServer::onRead() {
    qDebug() << "Reading request...";
    QTcpSocket *socket = (QTcpSocket*) this->sender();
    socket->connect(socket, &QTcpSocket::disconnected, &QObject::deleteLater);

    /// Read data
    const QUrlQuery callbackQuery = queryFromTarget(requestTarget(socket->readAll()));
    const QString code = accessTokenFromQuery(callbackQuery);
    const QString oauthError = errorFromQuery(callbackQuery);
    const bool stateMatches = !m_state.isEmpty() && stateFromQuery(callbackQuery) == m_state;
    if (!code.isEmpty() && stateMatches)
        qDebug() << "Found OAuth access token";

    // Respond with 200
    // http payload message body
    QByteArray content;
    if (!code.isEmpty() && !stateMatches) {
        qWarning() << "Ignoring OAuth callback with mismatched state";
        content = "<!DOCTYPE html><html>"
                  "<body><h1>Login failed</h1><p>Return to Orion and try logging in again.</p></body></html>";
    } else if (!oauthError.isEmpty()) {
        qWarning().noquote() << "Twitch OAuth login failed:" << oauthError;
        content = "<!DOCTYPE html><html>"
                  "<body><h1>Login failed</h1><p>You can close this page now.</p></body></html>";
    } else if (code.isEmpty()) {
        content = "<!DOCTYPE html><html><script>"
                  "var uri = '' + window.location.href;"
                  "window.location.href = uri.replace('#','?');"
                  "</script><body></body></html>";
    }

    else {
        content = "<!DOCTYPE html><html>"
                  "<body><h1>Success!</h1><p>You can close this page now</p></body></html>";
    }

    QString response = "HTTP/1.1 200 OK\n";
    response += "Content-Type: text/html; charset=utf-8\n";
    response += "Connection: Closed\n";
    response += "Content-Length: " + QString::number(content.length()) + "\n";
    response += "\n" + content;

    socket->write(response.toUtf8());
    socket->waitForBytesWritten();
    socket->disconnectFromHost();

    // Check if we have the api code ready
    if (!code.isEmpty() && stateMatches) {
        qDebug() << "Received OAuth access token";
        emit codeReceived(code);

        // Spin down server
        stop();
    } else if (!oauthError.isEmpty() && stateMatches) {
        stop();
    }
}
