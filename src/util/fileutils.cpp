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

#include "fileutils.h"

namespace {
bool writeAll(const QString &filename, const QByteArray &data, QIODevice::OpenMode mode)
{
    QFile file(filename);
    if (!file.open(mode)) {
        return false;
    }

    const qint64 bytesWritten = file.write(data);
    return bytesWritten == data.size() && file.flush();
}
}

std::string util::notabs(std::string str){
	std::string newstr;
	for (size_t i=0; i<str.length(); i++){
		if (str[i] != '\t') newstr += str[i];
	}
	return newstr;
}

QString util::readFile(const QString &filename){
    QFile file(filename);
    QString data;
    if (file.open(QFile::ReadOnly)){
        QTextStream in(&file);
        data = in.readAll();
    }
    return data;
}

bool util::writeFile(const QString& filename, const QByteArray& data){
    return writeAll(filename, data, QFile::WriteOnly | QFile::Truncate);
}

void util::writeImage(const char* path, FILE *data){
	std::ofstream file(path);
	file << data;
	file.close();
}

bool util::fileExists(const char* file){
	struct stat buf;
    return (stat(file, &buf) != -1);
}

//bool util::folderExists(const char* file){
//	struct stat buf;
//    return (stat(file, &buf) != -1 && S_ISDIR(buf.st_mode));
//}


bool util::writeBinaryFile(const QString &filename, const QByteArray &data)
{
    return writeAll(filename, data, QFile::WriteOnly | QFile::Truncate);
}
