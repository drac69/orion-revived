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
    property bool vodSearchInProgress: false
    property string selectedVodType: "archive"
    property var vodTypeOptions: [
        { "label": "VODs", "type": "archive" },
        { "label": "Highlights", "type": "highlight" },
        { "label": "Uploads", "type": "upload" },
        { "label": "All", "type": "" }
    ]

    function hasSelectedChannelId() {
        return !!(selectedChannel && selectedChannel._id)
    }

    function requestVods(offset, limit) {
        if (!hasSelectedChannelId()) {
            vodSearchInProgress = false
            return
        }

        vodSearchInProgress = true
        VodManager.search(selectedChannel._id, offset, limit, selectedVodType)
    }

    function reloadVods() {
        if (!hasSelectedChannelId()) {
            return
        }

        requestVods(0, 35)
        itemCount = 35
    }

    function search(channel){

        if (!channel || typeof channel == "undefined" || !channel._id) {
            selectedChannel = undefined
            channelVodPositions = ({})
            vodSearchInProgress = false
            itemCount = 0
            return
        }

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

        reloadVods()

        requestSelectionChange(3)
    }

    function getLastPlaybackPosition(channel, vod) {
        if (!channel || !channel.name || !vod || !vod._id) {
            return 0
        }

        console.log("getLastPlaybackPosition", channel.name, vod._id);
        return VodManager.getVodLastPlaybackPosition(channel.name, vod._id);
    }

    function filteredVodsFrom(index) {
        var vods = []
        for (var i = Math.max(0, index); i < vodsModel.count(); i++) {
            var vod = vodsModel.itemAt(i)
            if (vod) {
                vods.push(vod)
            }
        }
        return vods
    }

    function playQueueFrom(index) {
        if (!selectedChannel) {
            return
        }

        var vods = filteredVodsFrom(index)
        if (vods.length > 0) {
            playerView.startVodQueue(selectedChannel, vods, 0)
        }
    }

    property bool itemInView: isItemInView(this)
    onItemInViewChanged: {
        if (itemInView) {
            vodgrid.checkScroll()
        }
    }

    Connections {
        target: VodManager
        onSearchFinished: {
            vodSearchInProgress = false
            vodgrid.checkScroll()
        }

        onSearchFailed: vodSearchInProgress = false

        onVodLastPositionUpdated: {
            //console.log("onVodLastPositionUpdated", channel, vod, position);
            if (selectedChannel && selectedChannel.name === channel && channelVodPositions) {
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
                    placeholderText: "Filter VOD metadata"
                    text: vodsModel.filterText
                    selectByMouse: true
                    onTextChanged: {
                        if (vodsModel.filterText !== text) {
                            vodsModel.filterText = text
                        }
                    }
                    onActiveFocusChanged: {
                        if (activeFocus)
                            Settings.showVirtualKeyboard()
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
                    enabled: vodsModel.count() > 0
                    font.family: "Material Icons"
                    text: "\ue05f"
                    focusPolicy: Qt.NoFocus
                    onClicked: playQueueFrom(0)
                    ToolTip.visible: hovered
                    ToolTip.text: "Play filtered list"
                }

                ComboBox {
                    id: vodTypeFilter
                    model: vodTypeOptions
                    textRole: "label"
                    focusPolicy: Qt.NoFocus
                    Layout.preferredWidth: Math.max(dp(120), implicitWidth)
                    onActivated: {
                        selectedVodType = vodTypeOptions[index].type
                        reloadVods()
                    }
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
                position: channelVodPositions ? (channelVodPositions[model.id] || 0) : 0
                game: model.game
                language: model.language
                vodType: model.type
                createdAt: model.createdAt
                publishedAt: model.publishedAt
                description: model.description
                url: model.url
                seekPreviews: model.seekPreviews
                mutedSegments: model.mutedSegments
                mutedSegmentRanges: model.mutedSegmentRanges

                width: vodgrid.cellWidth
            }

            function playItem(item) {
                if (!selectedChannel || !item) {
                    return
                }

                var lastPlaybackPosition = getLastPlaybackPosition(selectedChannel, item);
                playerView.getStreams(selectedChannel, item, lastPlaybackPosition || 0);
            }

            onItemClicked: playItem(clickedItem)
            onItemDoubleClicked: playQueueFrom(index)

            onItemTooltipHover: {
                if (g_tooltip && item)
                    g_tooltip.displayVod(item, getPosition)
            }

            onAtYEndChanged: checkScroll()

            onUpdateTriggered: search(selectedChannel)

            function checkScroll(){
                if (hasSelectedChannelId() && !vodSearchInProgress && atYEnd && VodManager.loadedCount() >= itemCount && itemCount > 0){
                    requestVods(itemCount, 25)
                    itemCount += 25
                }
            }

            BusyIndicator {
                visible: running
                running: vodSearchInProgress
                anchors.centerIn: parent
            }

            Label {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 420)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: selectedChannel && !vodSearchInProgress && vodsModel.count() === 0
                text: !Settings.hasAccessToken ? "Log in to load Twitch VODs" : (vodsModel.filterText.length > 0 ? "No VODs match this filter" : "No VODs found")
            }
        }
    }
}
