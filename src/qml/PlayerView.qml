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
import QtQuick.Layouts 1.1
import Qt.labs.settings 1.0 as Labs

import "components"
import "util.js" as Util

import app.orion 1.0

Page {
    id: root

    leftPadding: chatdrawer.edge === Qt.LeftEdge && !chatdrawer.interactive ? chatdrawer.position * chatdrawer.width : 0
    rightPadding: chatdrawer.edge === Qt.RightEdge && !chatdrawer.interactive ? chatdrawer.position * chatdrawer.width : 0
    bottomPadding: chatdrawer.edge === Qt.BottomEdge ? chatdrawer.position * chatdrawer.height : 0
    topPadding: chatdrawer.edge === Qt.TopEdge ? chatdrawer.position * chatdrawer.height : 0

    property int duration: -1
    property var currentChannel
    property var streamMap
    property bool isVod: false
    property bool streamOnline: true
    property string curVodId
    property int lastSetPosition
    property bool headersVisible: true
    property bool showPlaybackStats: false
    property string playbackError: ""
    property var vodQueue: []
    property var vodQueueChannel
    property int vodQueueIndex: -1
    property bool suppressVodQueueAdvance: false
    property int startupRetryAttempts: 0
    property int maxStartupRetryAttempts: 2
    property int unexpectedStopRetryAttempts: 0
    property int maxUnexpectedStopRetryAttempts: 2

    Material.theme: rootWindow.Material.theme

    //Renderer interface
    property alias renderer: loader.item

    function playbackStatsAvailable() {
        return renderer && typeof renderer.getPlaybackStats === "function"
    }

    function updateScreensaverState() {
        if (renderer)
            PowerManager.screensaver = !Settings.inhibitScreensaver || (renderer.status !== "PLAYING")
    }

    Timer {
        id: suppressVodQueueAdvanceTimer
        interval: 2000
        repeat: false
        onTriggered: suppressVodQueueAdvance = false
    }

    Timer {
        id: startupRetryTimer
        interval: 12000
        repeat: false
        onTriggered: {
            if (!renderer || renderer.status !== "BUFFERING" || !streamMap || !currentChannel || playbackError) {
                return
            }

            if (startupRetryAttempts >= maxStartupRetryAttempts) {
                console.warn("Playback is still buffering after startup retries")
                setHeaderText("Still buffering: " + getWatchingTitle())
                return
            }

            startupRetryAttempts += 1
            console.warn("Playback startup stalled; retrying", startupRetryAttempts, "of", maxStartupRetryAttempts)
            loadAndPlay(true)
        }
    }

    Timer {
        id: unexpectedStopRecoveryTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!shouldRecoverUnexpectedStop()) {
                return
            }

            unexpectedStopRetryAttempts += 1
            console.warn("Playback stopped unexpectedly; reloading", unexpectedStopRetryAttempts, "of", maxUnexpectedStopRetryAttempts)
            setHeaderText("Reloading: " + getWatchingTitle())
            loadAndPlay()
        }
    }

    function suppressNextVodQueueAdvance() {
        suppressVodQueueAdvance = true
        suppressVodQueueAdvanceTimer.restart()
    }

    function stopRendererWithoutQueueAdvance() {
        if (renderer) {
            unexpectedStopRecoveryTimer.stop()
            suppressNextVodQueueAdvance()
            renderer.stop()
        }
    }

    //Fix minimode header bar
    clip: true

    Connections {
        target: ChannelManager

        onAddedChannel: {
            console.log("Added channel")
            if (currentChannel && currentChannel._id === chanid){
                currentChannel.favourite = true
            }
        }

        onDeletedChannel: {
            console.log("Deleted channel")
            if (currentChannel && currentChannel._id === chanid){
                currentChannel.favourite = false
            }
        }

        onFoundPlaybackStream: {
            loadStreams(streams)
        }
    }

    Connections {
        target: Network

        onNetworkAccessChanged: {
            if (up && currentChannel && renderer && renderer.status !== "PAUSED") {
                //console.log("Network up. Resuming playback...")
                loadAndPlay()
            }
        }

        onStreamGetOperationFinished: {
            //console.log("Received stream status", channelId, currentChannel._id, online)
            if (currentChannel && channelId === currentChannel._id) {
                if (online && !root.streamOnline) {
                    console.log("Stream back online, resuming playback")
                    loadAndPlay()
                }
                root.streamOnline = online
            }
        }

        onError: {
            switch (error) {

            case "token_error":
                playbackError = error
                setHeaderText("Token issue. Error getting stream")
                break;
            case "playlist_error":
                playbackError = error
                var playbackTarget = isVod ? "Unable to load VOD" : "Unable to load stream"
                var watchingTitle = getWatchingTitle()
                setHeaderText(watchingTitle ? playbackTarget + ": " + watchingTitle : playbackTarget)
                break;

            default:
                break;
            }
        }
    }

    Timer {
        //Polls channel when stream goes down
        id: pollTimer
        interval: 4000
        repeat: true
        onTriggered: {
            if (currentChannel && currentChannel._id)
                Network.getStream(currentChannel._id)
        }
    }


    function loadAndPlay(isRetry){
        if (!streamMap) {
            console.log("streamMap not available yet");
            return;
        }

        if (!isRetry) {
            startupRetryAttempts = 0
        }
        unexpectedStopRecoveryTimer.stop()

        var description = setWatchingTitle();

        var start = !isVod ? -1 : seekBar.value

        var quality = selectStreamQuality(preferredStreamQuality());
        if (!quality) {
            console.error("did not find a usable stream quality");
            playbackError = "quality_error"
            startupRetryTimer.stop()
            setHeaderText("No playable stream quality: " + getWatchingTitle())
            return;
        }
        var url = streamMap[quality]

        if (url == null) {
            console.error("did not have a playback url");
            playbackError = "quality_error"
            startupRetryTimer.stop()
            setHeaderText("Missing playback URL: " + getWatchingTitle())
            return;
        }

        console.debug("Loading: ", url)

        suppressNextVodQueueAdvance()
        renderer.load(url, start, description)
        renderer.setVolume(volumeSlider.value)
        startupRetryTimer.restart()
    }

    function channelQualityKey() {
        return currentChannel && currentChannel.name ? currentChannel.name : ""
    }

    function preferredStreamQuality() {
        var channel = channelQualityKey()
        if (Settings.rememberChannelQuality && channel) {
            var channelQuality = Settings.channelQuality(channel)
            if (channelQuality) {
                return channelQuality
            }
        }

        return Settings.quality
    }

    function setPreferredStreamQuality(quality) {
        var channel = channelQualityKey()
        if (Settings.rememberChannelQuality && channel) {
            Settings.setChannelQuality(channel, quality)
            return
        }

        Settings.quality = quality
    }

    function streamQualityHeight(name) {
        if (name === "source") {
            return Number.MAX_VALUE
        }
        if (name === "audio_only") {
            return 0
        }

        var match = /(\d+)p/.exec(name)
        return match ? parseInt(match[1]) : -1
    }

    function selectStreamQuality(preferred) {
        if (!streamMap) {
            return ""
        }
        if (streamMap.hasOwnProperty(preferred)) {
            return preferred
        }

        var preferredHeight = streamQualityHeight(preferred)
        var bestLowerQuality = ""
        var bestLowerHeight = -1
        var lowestQuality = ""
        var lowestHeight = Number.MAX_VALUE
        var firstQuality = ""

        for (var qualityName in streamMap) {
            if (!firstQuality) {
                firstQuality = qualityName
            }

            var height = streamQualityHeight(qualityName)
            if (height >= 0 && height < lowestHeight) {
                lowestHeight = height
                lowestQuality = qualityName
            }
            if (preferredHeight > 0 && height >= 0 && height <= preferredHeight && height > bestLowerHeight) {
                bestLowerHeight = height
                bestLowerQuality = qualityName
            }
        }

        if (bestLowerQuality) {
            console.log("no stream for quality", preferred, "using", bestLowerQuality)
            return bestLowerQuality
        }
        if (preferred !== "source" && lowestQuality) {
            console.log("no stream at or below quality", preferred, "using lowest available", lowestQuality)
            return lowestQuality
        }
        if (streamMap.hasOwnProperty("source")) {
            console.log("no stream for quality", preferred, "using source")
            return "source"
        }

        return firstQuality
    }

    function getStreams(channel, vod, startPos){
        clearVodQueue()
        unexpectedStopRetryAttempts = 0
        getChannel(channel, vod, true, startPos);
    }

    function getChat(channel) {
        clearVodQueue()
        unexpectedStopRetryAttempts = 0
        getChannel(channel, null, false, 0);
    }

    function clearVodQueue() {
        vodQueue = []
        vodQueueChannel = null
        vodQueueIndex = -1
    }

    function startVodQueue(channel, vods, startIndex) {
        if (!channel || !vods || vods.length === 0) {
            return
        }

        vodQueue = vods.slice(0)
        vodQueueChannel = channel
        vodQueueIndex = Math.max(0, Math.min(startIndex || 0, vodQueue.length - 1))
        playQueuedVod(true)
    }

    function playQueuedVod(useSavedPosition) {
        if (!vodQueueChannel || vodQueueIndex < 0 || vodQueueIndex >= vodQueue.length) {
            return
        }

        var vod = vodQueue[vodQueueIndex]
        var startPos = useSavedPosition ? VodManager.getVodLastPlaybackPosition(vodQueueChannel.name, vod._id) : 0
        unexpectedStopRetryAttempts = 0
        getChannel(vodQueueChannel, vod, true, startPos || 0)
    }

    function shouldAdvanceVodQueue() {
        return isVod
                && vodQueueIndex >= 0
                && vodQueueIndex + 1 < vodQueue.length
                && duration > 0
                && renderer
                && renderer.position >= Math.max(0, duration - 5)
    }

    function advanceVodQueue() {
        if (!shouldAdvanceVodQueue()) {
            return false
        }

        vodQueueIndex += 1
        unexpectedStopRetryAttempts = 0
        playQueuedVod(false)
        return true
    }

    function shouldRecoverUnexpectedStop() {
        if (!renderer || renderer.status !== "STOPPED" || !currentChannel || !streamMap || playbackError || !Network.up) {
            return false
        }
        if (unexpectedStopRetryAttempts >= maxUnexpectedStopRetryAttempts) {
            return false
        }
        if (!isVod && !streamOnline) {
            return false
        }
        if (isVod && duration > 0 && renderer.position >= Math.max(0, duration - 5)) {
            return false
        }
        return true
    }

    function scheduleUnexpectedStopRecovery() {
        if (!shouldRecoverUnexpectedStop()) {
            return false
        }

        setHeaderText("Stopped unexpectedly, retrying: " + getWatchingTitle())
        unexpectedStopRecoveryTimer.restart()
        return true
    }

    function getChannel(channel, vod, wantVideo, startPos){

        if (!channel){
            return
        }

        playbackError = ""
        stopRendererWithoutQueueAdvance()

        if (wantVideo) {
            if (!vod || typeof vod === "undefined") {
                ChannelManager.findPlaybackStream(channel.name)
                isVod = false

                duration = -1
            }
            else {
                VodManager.getBroadcasts(vod._id)
                isVod = true
                root.curVodId = vod._id
                root.lastSetPosition = startPos

                duration = vod.duration

                console.log("Setting up VOD, duration " + vod.duration)

                seekBar.value = startPos
            }
        } else {
            isVod = false;
        }

        currentChannel = {
            "_id": channel._id,
            "name": channel.name,
            "game": isVod ? vod.game : channel.game,
            "vodType": isVod ? vod.type : "",
            "language": channel.language || "",
            "title": isVod ? vod.title : channel.title,
            "online": channel.online,
            "favourite": channel.favourite || ChannelManager.containsFavourite(channel._id),
            "viewers": channel.viewers,
            "logo": channel.logo,
            "preview": channel.preview,
            "seekPreviews": isVod ? vod.seekPreviews : "",
            "mutedSegments": isVod ? vod.mutedSegments : "",
        }

        setWatchingTitle()

        if (isVod) {
            var startEpochTime = (new Date(vod.createdAt)).getTime() / 1000.0;

            var vodIdText = String(vod._id || "").replace(/^v/, "")
            var vodIdNum = parseInt(vodIdText)

            if (isNaN(vodIdNum)) {
                console.log("unknown vod id format in", vod._id)
            } else {
                console.log("replaying chat for vod", vodIdNum, "starting at", startEpochTime)
                chatdrawer.chat.replayChat(currentChannel.name, currentChannel._id, vodIdNum, startEpochTime, startPos)
            }
        } else {
            chatdrawer.chat.joinChannel(currentChannel.name, currentChannel._id);
        }

        pollTimer.restart()

        requestSelectionChange(4)
    }

    function setHeaderText(text) {
        title.text = text
    }

    function getWatchingTitle() {
        var description = ""
        if (currentChannel) {
            description = currentChannel.title + (isVod ? ("\r\n" + currentChannel.name) : "")
                    + (currentChannel.game ? " playing " + currentChannel.game : "")
                    + (isVod ? " (VOD)" : "");
        }
        return description;
    }

    function setWatchingTitle() {
        setHeaderText(getWatchingTitle());
        updateMprisMetadata();
    }

    function updateMprisMetadata() {
        if (!MprisManager.available()) return;
        var titleText = currentChannel ? (currentChannel.title || currentChannel.name || "Orion") : "Orion"
        var artistText = currentChannel ? (currentChannel.name || "") : ""
        var artUrl = currentChannel ? (currentChannel.logo || "") : ""
        var length = isVod && duration > 0 ? Math.round(duration * 1000000) : 0
        MprisManager.setMetadata(titleText, artistText, length, artUrl)
    }

    function updateMprisPlaybackStatus() {
        if (!MprisManager.available() || !renderer) return;
        if (renderer.status === "PLAYING") {
            MprisManager.setPlaybackStatus("Playing")
        } else if (renderer.status === "PAUSED" || renderer.status === "BUFFERING") {
            MprisManager.setPlaybackStatus("Paused")
        } else {
            MprisManager.setPlaybackStatus("Stopped")
        }
    }

    function loadStreams(streams) {
        playbackError = ""
        var sourceNames = []
        for (var k in streams) {
            sourceNames.splice(0, 0, k) //revert order
        }

        streamMap = streams
        sourcesBox.model = sourceNames
        console.debug("Available stream qualities:", sourceNames.join(", "))

        sourcesBox.selectItem(selectStreamQuality(preferredStreamQuality()));
        loadAndPlay()
    }

    function seekTo(position) {
        console.log("Seeking to", position, duration)
        if (isVod){
            chatdrawer.chat.playerSeek(position)
            renderer.seekTo(position)
        }
    }

    function currentTwitchUrl() {
        if (isVod && curVodId) {
            var vodId = String(curVodId).replace(/^v/, "")
            return "https://www.twitch.tv/videos/" + encodeURIComponent(vodId)
        }

        return app.channelPageUrl(currentChannel)
    }

    function openCurrentOnTwitch() {
        Qt.openUrlExternally(currentTwitchUrl())
    }

    function reloadStream() {
        playbackError = ""
        startupRetryAttempts = 0
        unexpectedStopRetryAttempts = 0
        stopRendererWithoutQueueAdvance()
        loadAndPlay()
    }

    function resumePlayback() {
        if (isVod && renderer.status === "STOPPED") {
            reloadStream()
            return
        }

        renderer.resume()
    }

    function togglePlayback() {
        if (isVod && renderer.status === "STOPPED") {
            reloadStream()
            return
        }

        renderer.togglePause()
    }

    Connections {
        target: VodManager
        onStreamsGetFinished: {
            loadStreams(items)
        }
    }

    Connections {
        target: rootWindow
        onClosing: {
            stopRendererWithoutQueueAdvance()
        }
    }

    Connections {
        target: Settings
        onInhibitScreensaverChanged: root.updateScreensaverState()
    }

    Connections {
        target: renderer

        onPositionChanged: {
            var newPos = renderer.position;
            if (MprisManager.available()) {
                MprisManager.setPosition(Math.round(newPos * 1000000))
            }
            chatdrawer.chat.playerPositionUpdate(newPos);
            if (root.isVod) {
                if (Math.abs(newPos - root.lastSetPosition) > 10) {
                    root.lastSetPosition = newPos;
                    VodManager.setVodLastPlaybackPosition(root.currentChannel.name, root.curVodId, newPos);
                }
            }
            if (!seekBar.pressed) {
                seekBar.value = newPos
            }
        }

        onPlayingResumed: {
            unexpectedStopRecoveryTimer.stop()
            setWatchingTitle()
        }

        onPlayingPaused: {
            setHeaderText("Paused: " + getWatchingTitle());
        }

        onPlayingStopped: {
            if (suppressVodQueueAdvance) {
                suppressVodQueueAdvance = false
                suppressVodQueueAdvanceTimer.stop()
            } else if (advanceVodQueue()) {
                return
            } else if (scheduleUnexpectedStopRecovery()) {
                return
            }
            setHeaderText("Stopped: " + getWatchingTitle());
        }

        onStatusChanged: {
            root.updateScreensaverState()
            root.updateMprisPlaybackStatus()
            if (renderer.status !== "BUFFERING") {
                startupRetryTimer.stop()
            }
        }
    }

    Connections {
        target: MprisManager

        onPlayRequested: if (renderer) resumePlayback()
        onPauseRequested: if (renderer) renderer.pause()
        onPlayPauseRequested: if (renderer) togglePlayback()
        onStopRequested: if (renderer) stopRendererWithoutQueueAdvance()
        onSeekRequested: {
            if (renderer && root.isVod) {
                root.seekTo(Math.max(0, renderer.position + offset / 1000000))
            }
        }
        onSetPositionRequested: {
            if (renderer && root.isVod) {
                root.seekTo(Math.max(0, position / 1000000))
            }
        }
        onVolumeRequested: {
            volumeSlider.value = Math.max(0, Math.min(100, volume * 100))
        }
        onRaiseRequested: {
            rootWindow.raise()
            rootWindow.requestActivate()
        }
    }

    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: {
            togglePlayback()
            clickRect.run()
            pArea.refreshHeaders()
        }
    }

    Repeater {
        model: ["0", "F5"]
        delegate: Item { Shortcut {
            sequence: modelData
            context: Qt.ApplicationShortcut
            onActivated: {
                reloadStream()
                clickRect.show("\ue5d5")
            }
        } }
    }

    Shortcut {
        sequence: "f"
        context: Qt.ApplicationShortcut
        onActivated: {
            appFullScreen = !appFullScreen
        }
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.ApplicationShortcut
        onActivated: {
            appFullScreen = false
        }
    }

    Shortcut {
        sequence: "m"
        context: Qt.ApplicationShortcut
        onActivated: {
            volumeBtn.toggleMute()
            clickRect.show(volumeSlider.value > 0 ? "\ue050" : "\ue04f")
        }
    }

    Shortcut {
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (volumeSlider.value < volumeSlider.to) {
                volumeSlider.value += 5
                clickRect.show("\ue050")
            }
        }
    }

    Shortcut {
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (volumeSlider.value > volumeSlider.from) {
                volumeSlider.value -= 5
                clickRect.show("\ue04d")
            }
        }
    }

    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!isVod || seekBar.pressed) return
            var totalSeek = seekBar.seekAdvance(5)
            clickRect.show((totalSeek > 0 ? "+" : "") + totalSeek + "s")
        }
    }

    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (!isVod || seekBar.pressed) return
            var totalSeek = seekBar.seekAdvance(-5)
            clickRect.show((totalSeek > 0 ? "+" : "") + totalSeek + "s")
        }
    }

    Item {
        id: playerArea
        anchors.fill: parent

        Keys.onShortcutOverride: {
            event.accepted = false
        }

        Keys.onTabPressed: {
            chatdrawer.forceActiveFocus()
        }

        Loader {
            id: loader
            anchors.fill: parent

            source: {
                switch (Settings.backend) {
                case "mpv":
                    return "MpvBackend.qml";

                case "qtav":
                    return "QtAVBackend.qml";

                case "multimedia":
                default:
                    return "MultimediaBackend.qml";
                }
            }

            onSourceChanged: {
                loadAndPlay()
            }

            onStatusChanged: {
                if (status === Loader.Error) {
                    var failedBackend = Settings.backend
                    Settings.markBackendUnavailable(failedBackend)
                    if (Settings.backend === failedBackend) {
                        setHeaderText("Player backend failed to load: " + failedBackend)
                    }
                }
            }

            onLoaded: {
                console.log("Loaded renderer")
                if (root.showPlaybackStats) {
                    statsPanel.refresh()
                }
            }
        }

        SeekPreview {
            id: preview
            anchors.fill: parent
            blur: 2
            visible: opacity > 0
            opacity: 0
            Behavior on opacity { PropertyAnimation { easing.type: Easing.InOutCubic } }

            Connections {
                target: seekBar
                onValueChanged: preview.value = seekBar.value
                onPressedChanged: {
                    if (seekBar.pressed) {
                        preview.opacity = 1
                        //todo: stop player while seeking
                    }
                }
            }
            Connections {
                target: renderer
                onStatusChanged: {
                    if (preview.visible && !seekBar.pressed && renderer.status !== "BUFFERING") {
                        Util.setTimeout(function() {
                            if (!seekBar.pressed) preview.opacity = 0
                        }, 100)
                    }
                }
            }
            Connections {
                target: root
                onCurrentChannelChanged: preview.source = currentChannel.seekPreviews
                onDurationChanged: preview.to = duration
            }
        }

        BusyIndicator {
            visible: running
            hoverEnabled: false
            anchors.centerIn: parent
            running: renderer.status === "BUFFERING"
        }
    }

    MouseArea {
        id: pArea
        anchors.fill: playerArea

        function refreshHeaders(){
            if (!hideTimer.running && !root.headersVisible)
                root.headersVisible = true
            hideTimer.restart()
        }

        onReleased: playerArea.forceActiveFocus()
        onVisibleChanged: refreshHeaders()
        onPositionChanged: refreshHeaders()
        
        Rectangle {
            id: clickRect
            anchors.centerIn: parent
            width: 0
            height: width
            radius: height / 2
            opacity: 0

            Label {
                id: clickRectIcon
                text: ""
                anchors.centerIn: parent
                font.family: /^[\x00-\x7F]*$/.test(text) ? "Helvetica" : "Material Icons"
                font.pointSize: parent.width * 0.5 / text.length
            }

            ParallelAnimation {
                id: _anim
                running: false

                onStopped: {
                    clickRect.opacity = 0
                }

                NumberAnimation {
                    target: clickRect
                    property: "width"
                    from: pArea.width * 0.1
                    to: pArea.width * 0.6
                    duration: 1500
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: clickRect
                    property: "opacity"
                    from: 0.5
                    to: 0
                    duration: 666
                    easing.type: Easing.OutCubic
                }
            }

            function show(text) {
                clickRectIcon.text = text
               _anim.restart()
            }

            function run() {
                 show(renderer.status !== "PLAYING" ? "\ue037" : "\ue034")
            }

            function abort() {
                _anim.stop()
            }
        }

        onClicked: {
            if (Settings.clickTogglePause) {
                clickRect.run()
                clickTimer.restart()
            }
            refreshHeaders()
        }
        onDoubleClicked: {
            if (!isMobile()) {
                clickTimer.stop()
                clickRect.abort();
                interactive = false /* avoid accidental view flicking */
                appFullScreen = !appFullScreen
                interactive = true
            }
        }
        hoverEnabled: true
        propagateComposedEvents: true
        cursorShape: headersVisible ? Qt.ArrowCursor : Qt.BlankCursor

        Timer {
            //Dbl click timer
            id: clickTimer
            interval: 200
            repeat: false
            onTriggered: {
                togglePlayback();
            }
        }

        Timer {
            id: hideTimer
            interval: 2000
            running: false
            repeat: false
            onTriggered: {
                if (!root.headersVisible || headerBarArea.containsMouse || bottomBarArea.containsMouse) return

                if (renderer.status === "PAUSED" || renderer.status === "STOPPED") return

                // Bug?: MouseArea doesn't work over Controls
                var controls = [ favBtn, chatBtn, playBtn, resetBtn, volumeBtn, volumeSlider, seekBar, sourcesBox, cropBtn, statsBtn, fsBtn];
                for (var i = 0; i < controls.length; i++) {
                    if (controls[i].hovered || controls[i].pressed || controls[i].down)
                        return;
                }

                root.headersVisible = false
            }
        }

        Rectangle {
            id: statsPanel
            visible: root.showPlaybackStats && root.playbackStatsAvailable()
            color: Qt.rgba(0, 0, 0, 0.72)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            radius: 4
            z: 10
            width: Math.max(1, Math.min(parent.width - 20, 430))
            height: statsText.implicitHeight + 20
            x: parent.width - width - 10
            y: (headerBar.visible ? headerBar.height : 0) + 10

            function refresh() {
                if (root.playbackStatsAvailable()) {
                    statsText.text = renderer.getPlaybackStats()
                } else {
                    statsText.text = ""
                }
            }

            onVisibleChanged: if (visible) refresh()

            Timer {
                interval: 1000
                repeat: true
                running: statsPanel.visible
                onTriggered: statsPanel.refresh()
            }

            Label {
                id: statsText
                anchors.fill: parent
                anchors.margins: 10
                color: "white"
                font.family: "monospace"
                font.pointSize: 9
                lineHeight: 1.15
                textFormat: Text.PlainText
                wrapMode: Text.NoWrap
            }
        }

        ToolBar {
            id: headerBar
            Material.foreground: rootWindow.Material.foreground
            background: Rectangle {
                color: root.Material.background
                opacity: 0.8
            }

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            clip: true
            height: root.headersVisible ? 55 : 0
            visible: height > 0

            Behavior on height {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: headerBarArea
                anchors.fill: parent
                hoverEnabled: true
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 5
                    rightMargin: 5
                }

                Label {
                    id: title
                    font.pointSize: 9
                    Layout.fillWidth: true
                    horizontalAlignment: Qt.AlignHCenter
                    clip: true
                    font.bold: true
                }

                IconButtonFlat {
                    id: favBtn
                    text: "\ue87d"
                    highlighted: currentChannel !== undefined && currentChannel.favourite === true

                    onClicked: {
                        if (currentChannel){
                            if (currentChannel.favourite)
                                app.removeFromFavourites(currentChannel, function() {
                                    currentChannel = currentChannel
                                })
                            else{
                                app.addToFavourites(currentChannel, function() {
                                    currentChannel = currentChannel
                                })
                            }
                        }
                    }
                }

                IconButtonFlat {
                    id: externalBtn
                    visible: currentChannel !== undefined
                    text: "\ue89e"
                    highlighted: playbackError !== ""
                    onClicked: openCurrentOnTwitch()
                    ToolTip.visible: hovered
                    ToolTip.text: isVod ? "Open VOD on Twitch" : "Open channel on Twitch"
                }

                IconButtonFlat {
                    id: chatBtn
                    visible: !isMobile()
                    onClicked: {
                        if (chatdrawer.position <= 0)
                            chatdrawer.open()
                        else
                            chatdrawer.close()
                    }
                    text: chatdrawer.hasUnreadMessages ? "\ue87f" : "\ue0ca"
                }
            }
        }

        ToolBar {
            id: bottomBar
            Material.foreground: rootWindow.Material.foreground
            background: Rectangle {
                color: root.Material.background
                opacity: 0.8
            }

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            clip: false
            height: root.headersVisible ? 55 : 0
            visible: height > 0

            Behavior on height {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: bottomBarArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Slider {
                id: seekBar
                from: 0
                to: duration
                visible: isVod && headersVisible
                padding: 0
                focusPolicy: Qt.NoFocus
                hoverEnabled: true
                clip: true

                anchors {
                    verticalCenter: parent.top
                    left: parent.left
                    right: parent.right
                }

                Component.onCompleted: {
                    handle.opacity = 0;
                }

                PropertyAnimation {
                    id: handleAnimation
                    target: seekBar.handle
                    easing.type: Easing.OutQuad
                    property: "opacity"
                    duration: 400
                    running: false
                }

                onHoveredChanged: {
                    var wantedOpacity = hovered || pressed ? 1 : 0;
                    if (handle.opacity === wantedOpacity) return;
                    handleAnimation.to = wantedOpacity;
                    handleAnimation.restart();
                }
                onPressedChanged: {
                    if (!pressed)
                        seekTo(value)
                }

                property real prev: 0
                onValueChanged: {
                    if (seekTimer.running)
                        value = renderer.position + seekTimer.offset
                }

                Timer {
                    id: seekTimer
                    interval: 500
                    repeat: false
                    property real offset: 0
                    onTriggered: {
                        seekTo(renderer.position + offset);
                        offset = 0
                    }
                }

                function seekAdvance(val) {
                    seekTimer.offset += val
                    value = renderer.position + seekTimer.offset
                    seekTimer.restart()
                    return seekTimer.offset
                }

                MouseArea {
                    id: seekBarMouseArea
                    anchors.fill: seekBar
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onClicked: mouse.accepted = false
                    onPressed: mouse.accepted = false
                }

            }

            Rectangle {
                color: root.Material.background
                radius: 5
                implicitHeight: seekTooltip.implicitHeight
                implicitWidth: seekTooltip.implicitWidth

                anchors.bottom: seekBar.top
                x: Math.min(seekBar.width-width-5, Math.max(5, (seekBar.pressed ? (seekBar.handle.x + seekBar.handle.width / 2) : seekBarMouseArea.mouseX) - width / 2))

                visible: opacity > 0
                opacity: (seekBar.hovered || seekBar.pressed) ? 1 : 0
                Behavior on opacity { PropertyAnimation { easing.type: Easing.InCubic } }

                ColumnLayout {
                    id: seekTooltip
                    anchors.fill: parent
                    spacing: 0

                    function timeAtMouse() {
                        if (seekBar.pressed && seekBar.live) return seekBar.value
                        var seekWidth = seekBar.width - seekBar.handle.width
                        var seekX = seekBarMouseArea.mouseX - seekBar.handle.width / 2
                        seekX = Math.min(seekWidth, Math.max(0, seekX))
                        return seekBar.valueAt(seekX / seekWidth)
                    }

                    SeekPreview {
                        id: seekPreview

                        Layout.topMargin: 5
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5

                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight

                        visible: !seekBar.pressed && implicitWidth > 0
                        blur: 1

                        Connections {
                            target: seekBar
                            onValueChanged: seekPreview.value = seekTooltip.timeAtMouse()
                        }
                        Connections {
                            target: seekBarMouseArea
                            onPositionChanged: seekPreview.value = seekTooltip.timeAtMouse()
                        }
                        Connections {
                            target: root
                            onCurrentChannelChanged: seekPreview.source = currentChannel.seekPreviews
                            onDurationChanged: seekPreview.to = duration
                        }

                    }

                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        padding: 5
                        text: Util.formatTime(seekTooltip.timeAtMouse())
                    }
                }

            }

            RowLayout {
                anchors {
                    fill: parent
                    rightMargin: 5
                    leftMargin: 5
                }                
                spacing: 0

                IconButtonFlat {
                    id: playBtn
                    text: renderer.status !== "PLAYING" && renderer.status !== "BUFFERING" ? "\ue037" : "\ue034"
                    onClicked: togglePlayback()
                }

                IconButtonFlat {
                    id: resetBtn
                    text: "\ue5d5"
                    onClicked: reloadStream()
                }

                IconButtonFlat {
                    id: volumeBtn
                    visible: !isMobile()
                    property real mutedValue: 100.0
                    text: volumeSlider.value > 0 ?
                              (volumeSlider.value > 50 ? "\ue050" : "\ue04d")
                            : "\ue04f"
                    onClicked: {
                        toggleMute()
                    }
                    function toggleMute() {
                        if (volumeSlider.value > 0) {
                            mutedValue = volumeSlider.value
                            volumeSlider.value = 0
                        } else {
                            volumeSlider.value = mutedValue
                        }
                    }
                }

                Slider {
                    id: volumeSlider
                    from: 0
                    to: 100
                    width: 0
                    opacity: 0
                    visible: !isMobile()
                    focusPolicy: Qt.NoFocus
                    Layout.maximumWidth: width
                    hoverEnabled: true
                    
                    Behavior on width { PropertyAnimation { easing.type: Easing.InOutQuad } }
                    Behavior on opacity { PropertyAnimation { easing.type: Easing.InOutQuad } }

                    Component.onCompleted: {
                        value = Settings.volumeLevel
                        renderer.setVolume(value)

                        playBtn.hoverEnabled = true
                        resetBtn.hoverEnabled = true
                        volumeBtn.hoverEnabled = true
                    }

                    Connections { target: playBtn; onHoveredChanged: volumeSlider.update(); onPressedChanged: volumeSlider.update() }
                    Connections { target: resetBtn; onHoveredChanged: volumeSlider.update(); onPressedChanged: volumeSlider.update() }
                    Connections { target: volumeBtn; onHoveredChanged: volumeSlider.update(); onPressedChanged: volumeSlider.update() }

                    // Volume slider behavior similar to youtube
                    function update() {
                        if (opacity > 0 && (playBtn.hovered || resetBtn.hovered)) {
                            opacity = 1
                            width = 90
                        } else if (hovered || pressed || volumeBtn.hovered || volumeBtn.pressed) {
                            opacity = 1
                            width = 90
                        } else {
                            opacity = 0
                            width = 0
                        }
                    }

                    onHoveredChanged: update()
                    onPressedChanged: update()

                    onValueChanged: {
                        renderer.setVolume(value)
                        Settings.volumeLevel = value;
                        if (MprisManager.available()) {
                            MprisManager.setVolume(value / 100)
                        }
                    }
                }

                //spacer
                Label {
                    id: videoPositionLabel
                    Layout.minimumWidth: 0
                    Layout.fillWidth: true
                    font.bold: true
                    font.pointSize: 8
                    Material.foreground: Material.Grey
                    horizontalAlignment: Qt.AlignLeft
                    clip: true
                    function updateText() {
                        if (!isVod) return ""
                        text = Util.formatTime(seekBar.value) + "/" + Util.formatTime(duration)
                    }
                    Connections {
                        target: seekBar
                        onValueChanged: videoPositionLabel.updateText()
                    }
                    Connections {
                        target: renderer
                        onPlayingStopped: videoPositionLabel.text = ""
                    }
                }


                ComboBox {
                    id: sourcesBox
                    visible: !!model && model.length > 1
                    font.pointSize: 9
                    font.bold: true
                    focusPolicy: Qt.NoFocus
                    flat: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 140
                    Layout.minimumWidth: 100

                    onActivated: {
                        var quality = sourcesBox.model[currentIndex]
                        if (preferredStreamQuality() !== quality) {
                            setPreferredStreamQuality(quality)
                            loadAndPlay()
                            pArea.refreshHeaders()
                        }
                    }

                    function selectItem(name) {
                        for (var i in sourcesBox.model) {
                            if (sourcesBox.model[i] === name) {
                                currentIndex = i;
                                return;
                            }
                        }
                        //None found, attempt to select first item
                        currentIndex = 0
                    }
                }

                IconButtonFlat {
                    id: cropBtn
                    visible: !appFullScreen && !isMobile() && !chatdrawer.visible && parent.width > 440
                    text: "\ue3bc"
                    onClicked: fitToAspectRatio()
                }

                IconButtonFlat {
                    id: statsBtn
                    visible: !isMobile() && root.playbackStatsAvailable()
                    highlighted: root.showPlaybackStats
                    text: "\ue88e"
                    onClicked: {
                        root.showPlaybackStats = !root.showPlaybackStats
                        if (root.showPlaybackStats) {
                            statsPanel.refresh()
                        }
                    }
                }

                IconButtonFlat {
                    id: fsBtn
                    visible: !isMobile()
                    text: !appFullScreen ? "\ue5d0" : "\ue5d1"
                    onClicked: appFullScreen = !appFullScreen
                }
            }
        }
    }

    ChatDrawer {
        parent: root
        id: chatdrawer
        onRaidReceived: {
            if (Settings.autoRaidRedirect && channel && !isVod) {
                rootWindow.openChannelName(channel)
            }
        }
        Labs.Settings {
            property alias chatVisible: chatdrawer.opened
            property alias chatWidth: chatdrawer.width
        }
    }
}
