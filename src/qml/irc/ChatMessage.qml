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
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.1
import QtQuick.Controls.Material 2.1
import "../components"
import "../util.js" as Util

import app.orion 1.0

Item {
    id: root
    property string user
    property var msg
    property bool isAction
    property string emoteDirPath
    property bool isChannelNotice
    property bool isWhisper
    property string systemMessage
    property real fontSize: Settings.textScaleFactor * 12
    property var badgeEntries: badgeEntries

    property bool showUsernameLine: !isChannelNotice || !systemMessage || (msg && msg.length > 0)
    property bool showSystemMessageLine: isChannelNotice && systemMessage != ""

    property var visibleBadgeEntries: showUsernameLine? badgeEntries : []
    property bool mentionedCurrentUser: mentionsCurrentUser()
    property bool highlightedUser: userHighlighted()

    height: childrenRect.height

    function colorUserRef(str) {
        var hasRef = false;
        var res = str.replace(/@\w{4,25}\b/g, function(ref) {
            var u = ref.substring(1).toLowerCase();
            if (chat.colors[u]) {
                hasRef = true;
                return "<a href=\"ref:" + u + "\" style=\"text-decoration:none\"><font color=\"" + chat.colors[u] + "\">" + ref + "</font></a>";
            }
            return ref;
        });
        if (hasRef && res.length && (res.charAt(0) === " ")) {
            res = "&nbsp;" + res.substring(1);
        }
        return hasRef ? res : str;
    }

    onFontSizeChanged: {
        // defer updatePositions so that bindings to the font size have a chance to recalculate before the re-layout
        Qt.callLater(function() {
            if (_messageLineFlow && _messageLineFlow.updatePositions)
                _messageLineFlow.updatePositions()
        })
    }

    function messagePartText(part) {
        if (typeof part === "string") {
            return part
        }
        if (!part) {
            return ""
        }

        var text = part.originalText || ""
        if (part.textSuffix) {
            text += part.textSuffix
        }
        return text
    }

    function messageText() {
        var text = ""
        if (msg) {
            for (var i = 0; i < msg.length; i++) {
                text += messagePartText(msg[i])
            }
        }
        return text
    }

    function copyText() {
        if (showSystemMessageLine && !showUsernameLine) {
            return systemMessage
        }

        var text = messageText()
        if (isAction) {
            return user + " " + text
        }
        return user + ": " + text
    }

    function escapeRegExp(str) {
        return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    function mentionsCurrentUser() {
        var currentUser = ChannelManager.username()
        if (!currentUser) {
            return false
        }

        var pattern = new RegExp("(^|\\W)@" + escapeRegExp(currentUser) + "\\b", "i")
        return pattern.test(messageText())
    }

    function userHighlighted() {
        var highlightUsers = Settings.chatHighlightUsers
        if (!highlightUsers) {
            return false
        }

        var currentUser = user.toLowerCase()
        var entries = highlightUsers.split(/[\r\n,]+/)
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i].trim().replace(/^@+/, "").toLowerCase()
            if (entry !== "" && entry === currentUser) {
                return true
            }
        }
        return false
    }

    Rectangle {
        anchors.fill: parent
        z: -2
        visible: mentionedCurrentUser || highlightedUser
        color: mentionedCurrentUser
               ? (Settings.lightTheme ? Qt.rgba(1.0, 0.78, 0.18, 0.18) : Qt.rgba(1.0, 0.78, 0.18, 0.14))
               : (Settings.lightTheme ? Qt.rgba(0.15, 0.55, 1.0, 0.16) : Qt.rgba(0.25, 0.65, 1.0, 0.14))
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: {
            chatMessageMenu.x = mouse.x
            chatMessageMenu.y = mouse.y
            chatMessageMenu.open()
            mouse.accepted = true
        }
    }

    Menu {
        id: chatMessageMenu
        MenuItem {
            text: "Copy Message"
            onTriggered: Settings.copyToClipboard(root.copyText())
        }
    }

    Label {
        id: _systemMessageLine
        anchors {
            left: parent.left
            right: parent.right
            margins: {
                leftMargin: 2
                rightMargin: 2
            }
        }
        font.bold: true
        horizontalAlignment: Qt.AlignHCenter

        visible: showSystemMessageLine
        text: root.systemMessage
        font.pointSize: fontSize
        wrapMode: Text.Wrap

        height: showSystemMessageLine? contentHeight : 0
    }

    CustomFlow {
      id: _messageLineFlow
      verticalAlignment: Qt.AlignVCenter

      anchors {
          top: _systemMessageLine.bottom
          left: parent.left
          right: parent.right
          margins: {
              leftMargin: 2
              rightMargin: 2
          }
      }

      Repeater {
        model: visibleBadgeEntries

        Loader {
          property var badgeEntry: visibleBadgeEntries[index]
          sourceComponent: {
            return badgeItem
          }
        }
      }

      Label {
        id: userName
        // if this ChatMessage is a channel notice with no user message text, don't show a user chat line
        visible: showUsernameLine
        verticalAlignment: Text.AlignVCenter
        font.pointSize: fontSize
        color: chat.colors[user.toLowerCase()]
        text: user + (isAction ? " " : ": ")
        font.bold: true
        textFormat: Text.PlainText

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: linkActivation("user:" + user)
        }
      }

      Repeater {
        model: msg
        Loader {
          property var msgItem: msg[index]
          sourceComponent: {
            if(typeof msg[index] == "string") {
              if (colorUserRef(msg[index]) !== msg[index]) {
                return msgUserRefLink;
              } else if (Util.isUrl(msg[index])) {
                return msgLink;
              } else {
                // put adjacent emotes together
                if (msg[index] === " " && typeof(msg[index-1]) !== "string" && typeof(msg[index+1]) !== "string") {
                  return null
                }
                return msgText;
              }
            } else {
              if (msg[index].imageProvider == "bits") {
                  return bitsImgThing;
              } else {
                  return imgThing;
              }
            }
          }
        }
      }
    }

    property Component msgText: Component {
      Label {
        verticalAlignment: Text.AlignVCenter
        color: Material.foreground
        font.pointSize: fontSize
        text: msgItem
        textFormat: Text.PlainText
      }
    }
    property Component msgLink: Component {
      Label {
        verticalAlignment: Text.AlignVCenter
        font.pointSize: fontSize
        color: Material.foreground
        linkColor: "#4286f4"
        text: Util.makeUrl(msgItem)
        onLinkActivated: linkActivation(link)
        textFormat: Text.StyledText
        MouseArea {
            visible: parent.hoveredLink
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.NoButton
        }
      }
    }
    property Component msgUserRefLink: Component {
      Label {
        verticalAlignment: Text.AlignVCenter
        color: Material.foreground
        linkColor: "#4286f4"
        font.pointSize: fontSize
        text: colorUserRef(Util.makeUrl(msgItem))
        onLinkActivated: linkActivation(link)
        textFormat: Text.RichText
        property int lastUserMessage: hoveredLink ? findLastUserMessage(hoveredLink) : -1
        onLastUserMessageChanged: list.markIndex(lastUserMessage)
        MouseArea {
            visible: parent.lastUserMessage !== -1
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.NoButton
        }
      }
    }
    property Component imgThing: Component {
      MouseArea {
          id: _emoteImgMouseArea
          hoverEnabled: true
          width: childrenRect.width
          height: childrenRect.height
          cursorShape: Qt.PointingHandCursor
          onClicked: addEmoteToChat(msgItem.originalText)

          Row {
              width: _emoteImg.width + _emoteImgSuffixText.width
              height: _emoteImg.height

              Image {
                id: _emoteImg

                width: sourceSize.width/(Settings.hiDpi() ? 2.0 : 1.0) * Settings.textScaleFactor
                height: sourceSize.height/(Settings.hiDpi() ? 2.0 : 1.0) * Settings.textScaleFactor

                source: "image://" + msgItem.imageProvider + "/" + msgItem.imageId;
                asynchronous: true
              }

              Label {
                  id: _emoteImgSuffixText
                  visible: !!msgItem.textSuffix
                  text: msgItem.textSuffix || ""
                  color: msgItem.textSuffixColor || Material.foreground
                  font.bold: true
                  font.pointSize: fontSize
                  verticalAlignment: Text.AlignVCenter
                  height: _emoteImg.height
              }
          }

          EmoteTooltip {
              visible: _emoteImgMouseArea.containsMouse && msgItem.originalText != null
              text: msgItem.originalText
          }
      }
    }
    property Component bitsImgThing: Component {
      MouseArea {
          id: _animatedImgMouseArea
          hoverEnabled: true
          width: _animatedImg.width + _animatedImgSuffixText.width
          height: _animatedImg.height
          cursorShape: Qt.PointingHandCursor
          onClicked: addEmoteToChat(msgItem.originalText);

          Row {
              AnimatedImage {
                id: _animatedImg

                // AnimatedImage doesn't provide a sourceSize properly even when status == AnimatedImage.Ready
                width: 28 * Settings.textScaleFactor
                height: 28 * Settings.textScaleFactor
                asynchronous: true

                source: msgItem.sourceUrl
              }

              Label {
                  id: _animatedImgSuffixText
                  text: msgItem.textSuffix
                  color: msgItem.textSuffixColor
                  font.bold: true
                  font.pointSize: fontSize
                  verticalAlignment: Text.AlignVCenter
                  height: _animatedImg.height
              }
          }

          EmoteTooltip {
              visible: _animatedImgMouseArea.containsMouse && msgItem.originalText != null
              text: msgItem.originalText
          }
      }
    }

    property Component badgeItem: Component {
      MouseArea {
          id: _badgeImgMouseArea
          hoverEnabled: true
          width: _badgeImg.width + 2
          height: _badgeImg.height
          Image {
            id: _badgeImg
            source: badgeEntry.url;
            width: sourceSize.width / badgeEntry.devicePixelRatio * Settings.textScaleFactor
            height: sourceSize.height / badgeEntry.devicePixelRatio * Settings.textScaleFactor
            asynchronous: true

//            onStatusChanged: {
//                if (status == Image.Ready) {
//                    _messageLineFlow.updatePositions();
//                }
//            }

            EmoteTooltip {
                visible: _badgeImgMouseArea.containsMouse && badgeEntry.name != null
                text: badgeEntry.name
            }
          }

          property bool clickable: badgeEntry.click_action == "visit_url"

          cursorShape: clickable ? Qt.PointingHandCursor : Qt.ArrowCursor

          onClicked: {
              console.log("badge clicked, action", badgeEntry.click_action);
              if (badgeEntry.click_action == "visit_url") {
                  var link = badgeEntry.click_url;
                  console.log("Launching url", link);
                  Qt.openUrlExternally(link);
              }
          }
      }
    }

    function findLastUserMessage(link) {
        var u = link.replace('ref:',"").toLowerCase();
        for (var i = delegateIndex; i >= 0; i--) {
            if (list.model.content[i].user.toLowerCase() === u) {
                return i
            }
        }
        return -1
    }

    function linkActivation(link)
    {
        if (link.substr(0,5) === "user:")
        {
            _input.remove(_input.selectionStart, _input.selectionEnd);
            var clickedUser = link.replace('user:',"");
            var text = ""
            if (isWhisper) {
                text = "/w " + clickedUser + " ";
            } else {
                text = "@" + clickedUser;
                text = _input.text === "" ? text + ', ' : ' ' + text;
            }
            _input.insert(_input.selectionStart, text);
            _input.forceActiveFocus()
        } else if (link.substr(0, 4) === "ref:") {
            var i = findLastUserMessage(link)
            if (i != -1) {
                list.moveToIndex(i)
                list.fadoutIndex(i)
            }
        } else {
            Qt.openUrlExternally(link)
        }
    }
}
