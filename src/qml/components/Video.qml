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

import QtQuick 2.5
import QtQuick.Controls 2.1
import QtQuick.Controls.Material 2.1

Channel {
    property string _id
    property int views
    property int duration
    property int position
    property string vodType
    property string createdAt
    property string publishedAt
    property string description
    property string url
    property string seekPreviews
    property string mutedSegments
    property string mutedSegmentRanges
    online: true

    Label {
        id: mutedSegmentsIcon
        font.family: "Material Icons"
        text: "\ue04f"
        font.pointSize: 16
        padding: 4
        anchors {
            top: parent.top
            left: parent.left
            margins: parent.width * 0.15
        }

        Material.foreground: Material.accent
        visible: mutedSegments.length > 0
        background: Rectangle {
            color: Material.background
            opacity: 0.8
        }
    }

    Label {
        id: resumePlaybackIcon
        font.family: "Material Icons"
        text: "\ue923"
        font.pointSize: 20
        anchors {
            top: parent.top
            right: parent.right
            margins: parent.width * 0.2
        }

        Material.foreground: Material.accent
        visible: position > 0
    }
}
