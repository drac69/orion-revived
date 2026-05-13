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


#include <QString>
#include <QUrl>
#include <QGuiApplication>
#include <QtGlobal>
#include <QDebug>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QDateTime>
#include "imageprovider.h"
#include "../network/networkmanager.h"

const int ImageProvider::MSEC_PER_DOWNLOAD = 16; // ~ 256kbit/sec for 2k images

ImageProvider::ImageProvider(const QString imageProviderName, const QString extension, const QString cacheDirName) : QObject(),
    _cacheProvider(this), _imageProviderName(imageProviderName), _extension(extension) {

    activeDownloadCount = 0;

    _bulkDownloadTimer.setInterval(MSEC_PER_DOWNLOAD);
    _bulkDownloadTimer.setSingleShot(true);
    connect(&_bulkDownloadTimer, &QTimer::timeout, this, &ImageProvider::bulkDownloadStep);

    const QString useCacheDirName = cacheDirName.isEmpty() ? imageProviderName : cacheDirName;
    _cacheDir.setPath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/") + useCacheDirName);
}

ImageProvider::~ImageProvider() {
}

bool ImageProvider::makeAvailable(QString key) {
    key = getCanonicalKey(key);

    if (currentlyDownloading.contains(key)) {
        // download of this emote in progress
        return true;
    }
    else if (download(key)) {
        // if this emote isn't already downloading, it's safe to load the cache file or download if not in the cache
        currentlyDownloading.insert(key);
        activeDownloadCount += 1;
        return true;
    }
    else {
        // we already had the emote locally and don't need to wait for it to download
        return false;
    }
}

bool ImageProvider::download(QString key) {
    if (_imageTable.contains(key)) {
        //qDebug() << "already in the table";
        return false;
    }

    const QUrl url = getUrlForKey(key);
    _cacheDir.mkpath(".");

    QString filename = _cacheDir.absoluteFilePath(key + _extension);

    if (_cacheDir.exists(key + _extension)) {
        //qDebug() << "local file already exists";
        loadImageFile(key, filename);
        return false;
    }
    qDebug() << "downloading " << url.toString();

    QNetworkRequest request(url);
    QNetworkReply* _reply = nullptr;
    _reply = networkAccessManager()->get(request);

    DownloadHandler * dh = new DownloadHandler(filename, key);

    connect(_reply, &QNetworkReply::readyRead,
        dh, &DownloadHandler::dataAvailable);
    connect(_reply, &QNetworkReply::errorOccurred,
        dh, &DownloadHandler::error);
    connect(_reply, &QNetworkReply::finished,
        dh, &DownloadHandler::replyFinished);
    connect(dh, &DownloadHandler::downloadComplete,
        this, &ImageProvider::individualDownloadComplete);

    return true;
}

void ImageProvider::bulkDownloadStep() {
    for (; _bulkDownloadPos != _curBulkDownloadKeys.constEnd(); _bulkDownloadPos++) {
        const QString & key = *_bulkDownloadPos;

        if (makeAvailable(key)) {
            // hit us back when the next time interval is up
            _bulkDownloadTimer.start();
            return;
        }
        else {
            qApp->processEvents();
        }
    }

    emit bulkDownloadComplete();
}

void ImageProvider::bulkDownload(const QList<QString> & keys) {
    _curBulkDownloadKeys = keys;

    _bulkDownloadPos = keys.constBegin();

    bulkDownloadStep();
}


void ImageProvider::individualDownloadComplete(QString filename, bool hadError) {
    DownloadHandler * dh = qobject_cast<DownloadHandler*>(sender());
    const QString emoteKey = dh->getKey();
    delete dh;

    if (hadError) {
        // delete partial download if any
        QFile(filename).remove();
    }
    else {
        loadImageFile(emoteKey, filename);
    }

    if (activeDownloadCount > 0) {
        activeDownloadCount--;
        qDebug() << activeDownloadCount << "active downloads remaining";
    }

    currentlyDownloading.remove(emoteKey);

    if (activeDownloadCount == 0) {
        emit downloadComplete();
    }
}

QHash<QString, QImage> ImageProvider::imageTable() {
    return _imageTable;
}

void ImageProvider::loadImageFile(QString emoteKey, QString filename) {
    QImage emoteImg;
    emoteImg.load(filename);
    _imageTable.insert(emoteKey, emoteImg);
}

QQmlImageProviderBase * ImageProvider::getQMLImageProvider() {
    return &_cacheProvider;
}

bool ImageProvider::downloadsInProgress() const {
    return activeDownloadCount > 0;
}

QNetworkAccessManager *ImageProvider::networkAccessManager()
{
    NetworkManager *networkManager = NetworkManager::getInstance();
    return networkManager ? networkManager->getManager() : &_manager;
}


URLFormatImageProvider::URLFormatImageProvider(const QString imageProviderName, const QString urlFormat, const QString extension, const QString cacheDir) :
    ImageProvider(imageProviderName, extension, cacheDir), _urlFormat(urlFormat)
{

}

const QUrl URLFormatImageProvider::getUrlForKey(QString & key) {
    return _urlFormat.arg(key);
}

QString ImageProvider::getCanonicalKey(const QString key) {
    return key;
}

// DownloadHandler

DownloadHandler::DownloadHandler(QString filename, QString key) : filename(filename), key(key), hadError(false) {
    _file.setFileName(filename);
    _file.open(QFile::WriteOnly);
    qDebug() << "save to" << filename;
}

void DownloadHandler::dataAvailable() {
    QNetworkReply* _reply = qobject_cast<QNetworkReply*>(sender());
    if (!_reply) {
        hadError = true;
        return;
    }

    auto buffer = _reply->readAll();
    _file.write(buffer.data(), buffer.size());
}

void DownloadHandler::error(QNetworkReply::NetworkError /*code*/) {
    hadError = true;
    QNetworkReply* _reply = qobject_cast<QNetworkReply*>(sender());
    if (!_reply) {
        qDebug() << "Network error downloading" << filename << ": missing reply sender";
        return;
    }

    qDebug() << "Network error downloading" << _reply->request().url().toString() << ":" << _reply->errorString();
}

void DownloadHandler::replyFinished() {
    QNetworkReply* _reply = qobject_cast<QNetworkReply*>(sender());
    if (!_reply) {
        hadError = true;
        _file.cancelWriting();
        emit downloadComplete(_file.fileName(), true);
        return;
    }

    _reply->deleteLater();
    _file.commit();
    //qDebug() << _file.fileName();
    //might need something for windows for the forwardslash..
    qDebug() << "download of" << _file.fileName() << "complete";

    emit downloadComplete(_file.fileName(), hadError);
}


// CachedImageProvider
CachedImageProvider::CachedImageProvider(ImageProvider const* provider) : QQuickImageProvider(QQuickImageProvider::Image), _provider(provider) {

}

QImage CachedImageProvider::requestImage(const QString &id, QSize * size, const QSize & requestedSize) {
    //qDebug() << "Requested id" << id << "from image provider";

    QString key = id;
    const int queryIndex = key.indexOf('?');
    if (queryIndex >= 0) {
        key.truncate(queryIndex);
    }

    auto result = _provider->_imageTable.find(key);
    if (result != _provider->_imageTable.end()) {
        const QImage image = result.value();
        if (size) {
            *size = image.size();
        }

        const bool hasRequestedWidth = requestedSize.width() > 0;
        const bool hasRequestedHeight = requestedSize.height() > 0;
        if (!hasRequestedWidth && !hasRequestedHeight) {
            return image;
        }

        QSize targetSize = image.size();
        if (hasRequestedWidth && hasRequestedHeight) {
            targetSize = requestedSize;
        } else if (hasRequestedWidth && image.width() > 0) {
            targetSize.setWidth(requestedSize.width());
            targetSize.setHeight(qMax(1, image.height() * requestedSize.width() / image.width()));
        } else if (hasRequestedHeight && image.height() > 0) {
            targetSize.setWidth(qMax(1, image.width() * requestedSize.height() / image.height()));
            targetSize.setHeight(requestedSize.height());
        }

        if (!targetSize.isValid() || targetSize.isEmpty() || targetSize == image.size()) {
            return image;
        }

        return image.scaled(targetSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    return QImage();
}
