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

import QtQuick.Controls 2.1
import QtQuick 2.5
import QtQuick.Layouts 1.1
import "components"
import "util.js" as Util

import app.orion 1.0

Item{
    id: vodsView

    //anchors.fill: parent
    property variant selectedChannel
    property int itemCount: 0
    property var channelVodPositions

    function search(channel){

        if (!channel || typeof channel == "undefined")
            return

        selectedChannel = {
            "_id": channel._id,
            "name": channel.name,
            "game": channel.game,
            "title": channel.title,
            "online": channel.online,
            "favourite": channel.favourite || ChannelManager.containsFavourite(channel._id),
            "viewers": channel.viewers,
            "logo": channel.logo,
            "preview": channel.preview,
        }

        channelVodPositions = VodManager.getChannelVodsLastPlaybackPositions(channel.name);

        VodManager.search(selectedChannel._id, 0, 35)

        itemCount = 35

        requestSelectionChange(3)
    }

    function getLastPlaybackPosition(channel, vod) {
        console.log("getLastPlaybackPosition", channel.name, vod._id);
        return VodManager.getVodLastPlaybackPosition(channel.name, vod._id);
    }

    property bool itemInView: isItemInView(this)
    onItemInViewChanged: {
        if (itemInView) {
            vodgrid.checkScroll()
        }
    }

    Connections {
        target: VodManager
        onVodLastPositionUpdated: {
            //console.log("onVodLastPositionUpdated", channel, vod, position);
            if (selectedChannel.name === channel) {
                channelVodPositions[vod] = position;
                // need binding to update
                channelVodPositions = channelVodPositions;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolBar {
            visible: !!selectedChannel
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                TextField {
                    id: filterInput
                    Layout.fillWidth: true
                    placeholderText: "Filter VODs"
                    text: vodsModel.filterText
                    selectByMouse: true
                    onTextChanged: {
                        if (vodsModel.filterText !== text) {
                            vodsModel.filterText = text
                        }
                    }
                }

                ToolButton {
                    visible: filterInput.text.length > 0
                    font.family: "Material Icons"
                    text: "\ue14c"
                    focusPolicy: Qt.NoFocus
                    onClicked: filterInput.text = ""
                    ToolTip.visible: hovered
                    ToolTip.text: "Clear filter"
                }

                ToolButton {
                    checkable: true
                    checked: vodsModel.oldestFirst
                    font.family: "Material Icons"
                    text: checked ? "\ue5d8" : "\ue5db"
                    focusPolicy: Qt.NoFocus
                    onClicked: vodsModel.oldestFirst = checked
                    ToolTip.visible: hovered
                    ToolTip.text: checked ? "Oldest first" : "Newest first"
                }
            }
        }

        CommonGrid {
            id: vodgrid

            Layout.fillWidth: true
            Layout.fillHeight: true

            model: vodsModel

            delegate: Video {
                _id: model.id
                title: model.title
                views: model.views
                preview: model.preview
                logo: preview
                duration: model.duration
                position: channelVodPositions[model.id] || 0
                game: model.game
                createdAt: model.createdAt
                seekPreviews: model.seekPreviews

                width: vodgrid.cellWidth
            }

            function playItem(item) {
                var lastPlaybackPosition = getLastPlaybackPosition(selectedChannel, item);
                playerView.getStreams(selectedChannel, item, lastPlaybackPosition || 0);
            }

            onItemClicked: playItem(clickedItem)
            onItemDoubleClicked: playItem(clickedItem)

            onItemTooltipHover: {
                if (g_tooltip)
                    g_tooltip.displayVod(item, getPosition)
            }

            onAtYEndChanged: checkScroll()

            onUpdateTriggered: search(selectedChannel)

            function checkScroll(){
                if (atYEnd && VodManager.loadedCount() === itemCount && itemCount > 0){
                    VodManager.search(selectedChannel._id, itemCount, 25)
                    itemCount += 25
                }
            }
        }
    }
}
