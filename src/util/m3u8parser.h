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

#ifndef M3U8PARSER_H
#define M3U8PARSER_H

#include <QVariantMap>
#include <QMap>
#include <QByteArray>
#include <QString>

namespace m3u8 {

    static QString attributeValue(const QString &line, const QString &name)
    {
        const int colon = line.indexOf(':');
        const QString attributes = colon >= 0 ? line.mid(colon + 1) : line;
        int pos = 0;

        while (pos < attributes.length()) {
            while (pos < attributes.length() && (attributes.at(pos) == ',' || attributes.at(pos).isSpace())) {
                pos++;
            }

            const int keyStart = pos;
            while (pos < attributes.length() && attributes.at(pos) != '=' && attributes.at(pos) != ',') {
                pos++;
            }

            if (pos >= attributes.length() || attributes.at(pos) != '=') {
                while (pos < attributes.length() && attributes.at(pos) != ',') {
                    pos++;
                }
                continue;
            }

            const QString key = attributes.mid(keyStart, pos - keyStart).trimmed();
            pos++;

            QString value;
            if (pos < attributes.length() && attributes.at(pos) == '"') {
                pos++;
                const int valueStart = pos;
                while (pos < attributes.length() && attributes.at(pos) != '"') {
                    pos++;
                }
                value = attributes.mid(valueStart, pos - valueStart);
                if (pos < attributes.length()) {
                    pos++;
                }
            }
            else {
                const int valueStart = pos;
                while (pos < attributes.length() && attributes.at(pos) != ',') {
                    pos++;
                }
                value = attributes.mid(valueStart, pos - valueStart).trimmed();
            }

            if (key.compare(name, Qt::CaseInsensitive) == 0) {
                return value;
            }
        }

        return QString();
    }

    static QString normalizeStreamName(QString streamName)
    {
        streamName = streamName.trimmed();

        if (streamName == "chunked") {
            return QStringLiteral("source");
        }

        if (streamName.compare(QStringLiteral("Audio Only"), Qt::CaseInsensitive) == 0) {
            return QStringLiteral("audio_only");
        }

        return streamName;
    }

    static QVariantMap getUrls(const QByteArray &data)
    {
        QVariantMap streams;

        QString streamName;
        foreach(QString str, QString(data).split("\n")){
            str = str.trimmed();

            if (str.startsWith("#EXT-X-STREAM-INF")){
                streamName = normalizeStreamName(attributeValue(str, QStringLiteral("VIDEO")));
                if (streamName.isEmpty()) {
                    streamName = normalizeStreamName(attributeValue(str, QStringLiteral("NAME")));
                }
            }
            else if (!streamName.isEmpty()
                     && (str.startsWith("http://") || str.startsWith("https://"))){

                streams.insert(streamName, str);

                streamName.clear();
            }
        }

        return streams;
    }
}

#endif // M3U8PARSER_H
