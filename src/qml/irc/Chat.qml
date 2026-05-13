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
import aldrog.twitchtube.ircchat 1.0

import app.orion 1.0

Item {
    id: root

    signal messageReceived(string user, variant message, string chatColor, bool subscriber, bool turbo, bool isAction, var badges, bool isChannelNotice, string systemMessage, bool isWhisper)
    signal setEmotePath(string value)
    signal notify(string message)
    signal clear()
    signal emoteSetIDsChanged(var emoteSetIDs)
    signal bulkDownloadComplete()
    signal channelBadgeBetaUrlsLoaded(string channel, var badgeSetData)
    signal bttvEmotesLoaded(string channel, var emotesByCode)
    signal ffzEmotesLoaded(string channel, var emotesByCode)
    signal raidReceived(string channel)

    property alias isAnonymous: chat.anonymous
    property var channel: undefined
    property var channelId: undefined
    property var singleShot: undefined
    property var replayMode: false

    Component.onCompleted: {
        chat.hookupChannelProviders()
        chat.initProviders()
    }

    Connections {
        target: ChannelManager

        onLogin: {
            //console.log("Login command: ", username, password)
            chat.name = username
            chat.password = password.length > 0 ? "oauth:" + password : ""

            chat.reopenSocket()
        }
    }

    Connections {
        target: Emotes

        onChannelBadgeBetaUrlsLoaded: {
            console.log("onChannelBadgeBetaUrlsLoaded", "channel", channel, "badgeSetData", badgeSetData);
            root.channelBadgeBetaUrlsLoaded(channel, badgeSetData);
        }
    }

    function enterChannelCommon(channelName, channelId) {
        root.channel = channelName
        root.channelId = channelId
        if (channelId) {
            Emotes.loadChannelBetaBadgeUrls(channelId);
            Emotes.loadChannelBitsUrls(channelId);
        }
        Emotes.loadChannelBttvEmotes(channelName);
        Emotes.loadChannelFfzEmotes(channelName);
    }

    function joinChannel(channelName, channelId) {
        chat.join(channelName, channelId)
        enterChannelCommon(channelName, channelId);
        if (root.replayMode) {
            chat.replayStop();
        }
        root.replayMode = false;
        messageReceived("notice", null, "", false, false, false, [], true, "Joined channel #" + channelName, false)
    }

    function replayChat(channelName, channelId, vodId, startEpochTime, startPos) {
        chat.replay(channelName, channelId, vodId, startEpochTime, startPos)
        enterChannelCommon(channelName, channelId);
        root.replayMode = true
        messageReceived("notice", null, "", false, false, false, [], true, "VOD chat replay is unavailable through Twitch's current supported APIs. Open this VOD on Twitch for native replay chat.", false)
    }

    function replaySeek(newOffset) {
        chat.replaySeek(newOffset);
    }

    function replayUpdate(newOffset) {
        chat.replayUpdate(newOffset);
    }

    function leaveChannel() {
        chat.leave()
    }

    function sendChatMessage(message, relevantEmotes) {
        chat.sendMessage(message, relevantEmotes)
    }

    function bulkDownloadEmotes(emotes) {
        return chat.bulkDownloadEmotes(emotes);
    }

    function downloadBttvEmotesGlobal() {
        return chat.downloadBttvEmotesGlobal();
    }

    function downloadBttvEmotesChannel() {
        return chat.downloadBttvEmotesChannel();
    }

    function downloadFfzEmotesGlobal() {
        return chat.downloadFfzEmotesGlobal();
    }

    function downloadFfzEmotesChannel() {
        return chat.downloadFfzEmotesChannel();
    }

    function reconnect() {
        chat.reopenSocket()
    }

    function getBadgeLocalUrl(key) {
        return chat.getBadgeLocalUrl(key);
    }

    IrcChat {
        id: chat

        onConnectedChanged: {
            if (connected) {
                if (root.channel) {
                    if (root.replayMode) {
                        console.log("Reconnected; chat replay may resume")
                    } else {
                        console.log("Connected to chat")
                    }
                }
            } else {
                console.log("Disconnected from chat")
            }
        }

        onMessageReceived: {
            root.setEmotePath(emoteDirPath)
            root.messageReceived(user, message, chatColor, subscriber, turbo, isAction, badges, isChannelNotice, systemMessage, isWhisper)
        }

        onNoticeReceived: {
            console.log("Notification received", message);
            root.messageReceived("channel", [], null, null, false, false, {}, true, message, false)
        }

        onRaidReceived: {
            root.raidReceived(channel)
        }

        onEmoteSetIDsChanged: {
            root.emoteSetIDsChanged(emoteSetIDs)
        }

        onBulkDownloadComplete: {
            root.bulkDownloadComplete();
        }

        onBttvEmotesLoaded: {
            root.bttvEmotesLoaded(channel, emotesByCode);
        }

        onFfzEmotesLoaded: {
            root.ffzEmotesLoaded(channel, emotesByCode);
        }
    }
}
