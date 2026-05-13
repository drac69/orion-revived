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
import QtQuick.Layouts 1.1
import "components"
import app.orion 1.0

Page {
    id: root
    padding: 20

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height
        contentWidth: width
        ScrollIndicator.vertical: ScrollIndicator { visible: isMobile() }
        ScrollBar.vertical: ResponsiveScrollBar { visible: !isMobile() }
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 15

            GroupBox {
                title: "Twitch login"
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter

                RowLayout {
                    width: parent.width

                    Label {
                        id: twitchName
                        text: ChannelManager.username() || "Not logged in"
                        Layout.fillWidth: true
                        clip: true
                    }

                    Button {
                        id: connectButton
                        property bool loggedIn: Settings.hasAccessToken
                        highlighted: loggedIn
                        font.pointSize: 9
                        text: loggedIn ? "Log out" : "Log in"
                        onClicked: {
                            if (!loggedIn) {
                                LoginService.start();
                                var url = "https://id.twitch.tv/oauth2/authorize?response_type=token&client_id=" + Network.getClientId()
                                        + "&redirect_uri=http://localhost:8979"
                                        + "&scope=user%3Aread%3Afollows%20user%3Aread%3Asubscriptions%20user%3Aread%3Ablocked_users%20user%3Amanage%3Ablocked_users%20chat%3Aread%20chat%3Aedit"
                                        + "&force_verify=true";
                                Qt.openUrlExternally(url);
                            }
                            else {
                                Settings.accessToken = ""
                                ChannelManager.checkFavourites()
                                twitchName.text = "Not logged in"
                            }
                        }

                        Connections {
                            target: ChannelManager
                            onUserNameUpdated: {
                                twitchName.text = name
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: "Notification settings"
                visible: !isMobile()
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter

                Column {
                    width: parent.width

                    Switch {
                        id: alertOption
                        checked: Settings.alert

                        onClicked: {
                            Settings.alert = checked
                        }
                        text: "Enable notifications"
                    }

                    Switch {
                        id: notificationsOption
                        enabled: alertOption.checked

                        checked: Settings.offlineNotifications
                        onClicked: {
                            Settings.offlineNotifications = !Settings.offlineNotifications
                        }
                        text: "Show offline notifications"
                    }

                    Switch {
                        enabled: alertOption.checked
                        checked: Settings.chatNotifications
                        onClicked: Settings.chatNotifications = checked
                        text: "Chat mention notifications"
                    }
                    OptionCombo {
                        id: alertPosition
                        width: parent.width
                        visible: Qt.platform.os === "windows"
                        enabled: alertOption.checked
                        text: "Notification corner"
                        model: ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]
                        Component.onCompleted: currentIndex = Settings.alertPosition
                        onActivated: Settings.alertPosition = index

                        Connections {
                            target: Settings
                            onAlertPositionChanged: alertPosition.currentIndex = Settings.alertPosition
                        }
                    }
                    OptionCombo {
                        id: alertScreen
                        width: parent.width
                        visible: Qt.platform.os === "windows"
                        enabled: alertOption.checked
                        text: "Notification screen"
                        model: Settings.screenNames()
                        Component.onCompleted: currentIndex = Settings.alertScreen
                        onActivated: Settings.alertScreen = index

                        Connections {
                            target: Settings
                            onAlertScreenChanged: alertScreen.currentIndex = Settings.alertScreen
                        }
                    }
                }
            }

            GroupBox {
                title: "Video Player" + (Settings.backends.length === 1 ? " (" + playerOption.currentName + ")" : "")
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter


                Column {
                    width: parent.width

                    Switch {
                        text: "Toggle pause by clicking"
                        checked: Settings.clickTogglePause
                        onClicked: Settings.clickTogglePause = checked
                    }

                    Switch {
                        text: "Prevent screensaver while playing"
                        checked: Settings.inhibitScreensaver
                        onClicked: Settings.inhibitScreensaver = checked
                    }

                    Switch {
                        text: "Audio compressor"
                        visible: Settings.backend === "mpv"
                        checked: Settings.audioCompressor
                        onClicked: Settings.audioCompressor = checked
                    }

                    OptionCombo {
                        id: qualityOption
                        text: "Default stream quality"
                        width: parent.width
                        model: ["source", "1080p60", "1080p", "720p60", "720p", "480p", "360p", "160p", "audio_only"]

                        Component.onCompleted: selectItem(Settings.quality)

                        onActivated: Settings.quality = model[currentIndex]

                        function selectItem(name) {
                            for (var i in model) {
                                if (model[i] === name) {
                                    currentIndex = i
                                    return
                                }
                            }
                            currentIndex = 0
                        }
                    }

                    Switch {
                        text: "Remember quality per channel"
                        checked: Settings.rememberChannelQuality
                        onClicked: Settings.rememberChannelQuality = checked
                    }

                    Switch {
                        text: "Low latency playback"
                        checked: Settings.lowLatencyPlayback
                        onClicked: Settings.lowLatencyPlayback = checked
                    }

                    OptionCombo {
                        width: parent.width
                        id: playerOption
                        text: "Player"
                        property var currentName: model[currentIndex]
                        property var backendNames: {
                            "qtav": "QtAV",
                            "mpv": "mpv",
                            "multimedia": "Qt Multimedia"
                        }

                        function refreshModel() {
                            model = Settings.backends.map(function(v) { return backendNames[v] || v; })
                            selectItem(Settings.backend)
                            visible = Settings.backends.length > 1
                        }

                        Component.onCompleted: refreshModel()

                        Connections {
                            target: Settings
                            onBackendChanged: playerOption.selectItem(Settings.backend)
                            onBackendsChanged: playerOption.refreshModel()
                        }

                        onActivated: {
                            if (Settings.backend !== Settings.backends[currentIndex]) {
                                Settings.backend = Settings.backends[currentIndex]
                            }
                        }
                        function selectItem(name) {
                            for (var i in Settings.backends) {
                                if (Settings.backends[i] === name) {
                                    currentIndex = i;
                                    return;
                                }
                            }
                            //None found, attempt to select first item
                            currentIndex = 0
                        }
                    }

                    OptionCombo {
                        id: hwaccelOption
                        text: "Hardware Acceleration"
                        width: parent.width

                        property var renderer: app.view.playerView.renderer

                        visible: model.length > 1
                        Component.onCompleted: {
                            initialize()
                        }

                        onActivated: {
                            if (Settings.decoder !== model[currentIndex]) {
                                renderer.setDecoder(currentIndex)
                                view.playerView.loadAndPlay()
                                Settings.decoder = model[currentIndex]
                            }
                        }

                        function initialize() {
                            var decoder = renderer.getDecoder()
                            model = decoder
                            selectItem(Settings.decoder)
                            renderer.setDecoder(currentIndex)
                        }

                        function selectItem(name) {
                            for (var i in model) {
                                if (model[i] === name) {
                                    currentIndex = i;
                                    return;
                                }
                            }
                            //None found, attempt to select first item
                            currentIndex = 0
                        }

                        Connections {
                            target: app.view.playerView
                            onRendererChanged: {
                                hwaccelOption.initialize()
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width

                        OptionCombo {
                            id: openglOption
                            text: "OpenGL (needs restart)"
                            model: {
                                var opengl = [ ]
                                if (Qt.platform.os === "windows") {
                                    opengl = ["angle (d3d11)", "angle", "angle (d3d9)", "angle (warp)"]
                                } else {
                                    opengl = ["opengl es"]
                                }
                                opengl = opengl.concat(["desktop", "software"])
                                return opengl
                            }
                            Layout.fillWidth: true
                            property var defaultValue

                            onActivated: {
                                Settings.opengl = model[currentIndex]
                            }

                            Component.onCompleted: {
                                defaultValue = Settings.opengl
                                selectItem(defaultValue)
                            }

                            function selectItem(name) {
                                for (var i in model) {
                                    if (model[i] === name) {
                                        currentIndex = i;
                                        return;
                                    }
                                }
                                //None found, attempt to select first item
                                currentIndex = 0
                            }
                        }

                        Button {
                            text: "Reset"
                            font.pointSize: 9
                            onClicked: {
                                openglOption.selectItem(openglOption.defaultValue)
                            }
                        }
                    }

                }
            }

            GroupBox {
                title: "User interface"
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter

                Column {
                    width: parent.width

                    Switch {
                        id: themeOption
                        text: "Enable dark theme"
                        checked: !Settings.lightTheme
                        onClicked: Settings.lightTheme = !checked
                    }

                    Switch {
                        visible: !isMobile()
                        id: keepOnTopOption
                        text: "Keep on top"
                        checked: Settings.keepOnTop
                        onClicked: Settings.keepOnTop = checked
                    }

                    Switch {
                        text: "Compact navigation"
                        checked: Settings.compactNavigation
                        onClicked: Settings.compactNavigation = checked
                    }

                    Switch {
                        visible: !isMobile()
                        text: "Side navigation"
                        checked: Settings.sideNavigation
                        onClicked: Settings.sideNavigation = checked
                    }

                    Switch {
                        visible: !isMobile()
                        text: "Allow multiple instances"
                        checked: Settings.multipleInstances
                        onClicked: Settings.multipleInstances = checked
                    }

                    Switch {
                        text: "Start minimized"
                        checked: Settings.minimizeOnStartup
                        onClicked: Settings.minimizeOnStartup = checked
                    }

                    RowLayout {
                        width: parent.width

                        OptionCombo {
                            id: fontOption
                            text: "Font"
                            model: Qt.fontFamilies()
                            Layout.fillWidth: true

                            property string fontName: Settings.font || appFont.name
                            onFontNameChanged: {
                                setCurrentIndex(fontName)
                            }

                            function setCurrentIndex(name) {
                                for (var i=0; i < model.length; i++) {
                                    if (model[i] === name) {
                                        fontOption.selection = i
                                        break;
                                    }
                                }
                            }

                            onActivated: {
                                Settings.font = model[index]
                            }
                        }

                        Button {
                            text: "Reset"
                            font.pointSize: 9
                            onClicked: {
                                Settings.font = appFont.name
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: "Logs"
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter

                Column {
                    width: parent.width

                    TextArea {
                        width: parent.width
                        height: 160
                        text: LogBuffer.text
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.NoWrap
                        font.family: "monospace"
                        font.pointSize: 9
                    }

                    RowLayout {
                        width: parent.width

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Copy"
                            font.pointSize: 9
                            enabled: LogBuffer.text.length > 0
                            onClicked: Settings.copyToClipboard(LogBuffer.text)
                        }

                        Button {
                            text: "Clear"
                            font.pointSize: 9
                            enabled: LogBuffer.text.length > 0
                            onClicked: LogBuffer.clear()
                        }
                    }
                }
            }

            GroupBox {
                title: "Chat"
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter
                Column {
                    width: parent.width

                    Switch {
                        text: "Enable auto-scroll smoothing"
                        checked: Settings.autoScrollSmoothing
                        onClicked: Settings.autoScrollSmoothing = checked
                    }
                    Switch {
                        text: "Follow raids automatically"
                        checked: Settings.autoRaidRedirect
                        onClicked: Settings.autoRaidRedirect = checked
                    }
                    Switch {
                        text: "Use pastel colors"
                        checked: Settings.pastelColors
                        onClicked: Settings.pastelColors = checked
                    }

                    Label {
                        text: "Chat background opacity"
                        font.bold: true
                    }

                    Slider {
                        width: parent.width
                        from: 0.0
                        to: 1.0
                        stepSize: 0.05
                        value: Settings.chatOpacity
                        onValueChanged: Settings.chatOpacity = value
                    }

                    Label {
                        text: "Highlighted chat users"
                        font.bold: true
                    }

                    TextArea {
                        width: parent.width
                        height: 90
                        text: Settings.chatHighlightUsers
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        onActiveFocusChanged: {
                            if (activeFocus)
                                Settings.showVirtualKeyboard()
                        }
                        onTextChanged: {
                            if (Settings.chatHighlightUsers !== text) {
                                Settings.chatHighlightUsers = text
                            }
                        }
                    }

                    Label {
                        text: "Filtered chat terms"
                        font.bold: true
                    }

                    TextArea {
                        width: parent.width
                        height: 90
                        text: Settings.chatBlacklist
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        onActiveFocusChanged: {
                            if (activeFocus)
                                Settings.showVirtualKeyboard()
                        }
                        onTextChanged: {
                            if (Settings.chatBlacklist !== text) {
                                Settings.chatBlacklist = text
                            }
                        }
                    }

                    OptionCombo {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        //Layout.fillWidth: true
                        id: chatEdgeOption
                        text: "Chat position"
                        visible: !isMobile()
                        model: ["Left", "Right", "Bottom", "Top"]
                        selection: Settings.chatEdge
                        onActivated: Settings.chatEdge = index
                    }
                }
            }

            GroupBox {
                title: "Version info"
                padding: 10
                Layout.fillWidth: true
                Layout.maximumWidth: 500
                Layout.alignment: Qt.AlignCenter
                Label {
                    text: Qt.application.name + " " + Qt.application.version
                }
            }
        }
    }
}
