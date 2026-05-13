import QtQuick 2.0
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import "../components"
import "../util.js" as Util
import "../"

RoundButton {
    id: _emoteButton
    property bool emotePickerDownloadsInProgress : false
    property var setsToDownload
    property var lastSet
    property var lastEmoteSets
    property int curDownloading
    property ListModel setsVisible: ListModel { }
    property string unicodeEmojiImageBase: "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/"
    property var unicodeEmoji: [
        { "name": "😀 grinning face", "text": "😀" },
        { "name": "😁 beaming face", "text": "😁" },
        { "name": "😄 smiling eyes", "text": "😄" },
        { "name": "😆 laughing", "text": "😆" },
        { "name": "😂 joy", "text": "😂" },
        { "name": "🤣 rofl", "text": "🤣" },
        { "name": "🙂 slight smile", "text": "🙂" },
        { "name": "😊 blush", "text": "😊" },
        { "name": "😉 wink", "text": "😉" },
        { "name": "😍 heart eyes", "text": "😍" },
        { "name": "😘 kiss", "text": "😘" },
        { "name": "😋 yum", "text": "😋" },
        { "name": "😜 playful", "text": "😜" },
        { "name": "🤪 zany", "text": "🤪" },
        { "name": "😎 sunglasses", "text": "😎" },
        { "name": "🤔 thinking", "text": "🤔" },
        { "name": "🤨 raised eyebrow", "text": "🤨" },
        { "name": "😐 neutral", "text": "😐" },
        { "name": "😬 grimace", "text": "😬" },
        { "name": "🙄 eye roll", "text": "🙄" },
        { "name": "😳 flushed", "text": "😳" },
        { "name": "🥺 pleading", "text": "🥺" },
        { "name": "😅 sweat smile", "text": "😅" },
        { "name": "😇 innocent", "text": "😇" },
        { "name": "🤗 hug", "text": "🤗" },
        { "name": "🤫 shush", "text": "🤫" },
        { "name": "🤭 hand over mouth", "text": "🤭" },
        { "name": "🤯 mind blown", "text": "🤯" },
        { "name": "😭 sob", "text": "😭" },
        { "name": "😢 cry", "text": "😢" },
        { "name": "😤 triumph", "text": "😤" },
        { "name": "😡 angry", "text": "😡" },
        { "name": "😱 scream", "text": "😱" },
        { "name": "🥳 party", "text": "🥳" },
        { "name": "😴 sleeping", "text": "😴" },
        { "name": "🤡 clown", "text": "🤡" },
        { "name": "💀 skull", "text": "💀" },
        { "name": "👋 wave", "text": "👋" },
        { "name": "👍 thumbs up", "text": "👍" },
        { "name": "👎 thumbs down", "text": "👎" },
        { "name": "👌 ok hand", "text": "👌" },
        { "name": "✌️ peace", "text": "✌️" },
        { "name": "🤞 fingers crossed", "text": "🤞" },
        { "name": "🤝 handshake", "text": "🤝" },
        { "name": "👏 clap", "text": "👏" },
        { "name": "🙌 raised hands", "text": "🙌" },
        { "name": "🤲 palms up", "text": "🤲" },
        { "name": "🙏 pray", "text": "🙏" },
        { "name": "💪 flex", "text": "💪" },
        { "name": "🧠 brain", "text": "🧠" },
        { "name": "🫶 heart hands", "text": "🫶" },
        { "name": "👀 eyes", "text": "👀" },
        { "name": "🧡 orange heart", "text": "🧡" },
        { "name": "💛 yellow heart", "text": "💛" },
        { "name": "💚 green heart", "text": "💚" },
        { "name": "💙 blue heart", "text": "💙" },
        { "name": "🖤 black heart", "text": "🖤" },
        { "name": "🤍 white heart", "text": "🤍" },
        { "name": "💯 hundred", "text": "💯" },
        { "name": "🔥 fire", "text": "🔥" },
        { "name": "✨ sparkles", "text": "✨" },
        { "name": "⭐ star", "text": "⭐" },
        { "name": "🌟 glowing star", "text": "🌟" },
        { "name": "⚡ lightning", "text": "⚡" },
        { "name": "💥 boom", "text": "💥" },
        { "name": "💫 dizzy", "text": "💫" },
        { "name": "🎉 celebration", "text": "🎉" },
        { "name": "🎊 confetti", "text": "🎊" },
        { "name": "🎁 gift", "text": "🎁" },
        { "name": "❤️ heart", "text": "❤️" },
        { "name": "💜 purple heart", "text": "💜" },
        { "name": "💔 broken heart", "text": "💔" },
        { "name": "🏅 medal", "text": "🏅" },
        { "name": "🥇 first place", "text": "🥇" },
        { "name": "☕ coffee", "text": "☕" },
        { "name": "🍕 pizza", "text": "🍕" },
        { "name": "🍿 popcorn", "text": "🍿" },
        { "name": "🍻 cheers", "text": "🍻" },
        { "name": "💎 gem", "text": "💎" },
        { "name": "🎯 bullseye", "text": "🎯" },
        { "name": "🎲 dice", "text": "🎲" },
        { "name": "🎮 game", "text": "🎮" },
        { "name": "🕹️ joystick", "text": "🕹️" },
        { "name": "🏆 trophy", "text": "🏆" },
        { "name": "📣 megaphone", "text": "📣" },
        { "name": "🔔 bell", "text": "🔔" },
        { "name": "✅ check mark", "text": "✅" },
        { "name": "❌ cross mark", "text": "❌" },
        { "name": "❗ exclamation", "text": "❗" },
        { "name": "❓ question", "text": "❓" }
    ]
    
    property bool pickerLoaded: false
    property var pickerChannelLoaded: null
    onPressed: {
        if (!_emotePicker.visible) {
            _emotePicker.show();
        } else {
            _emotePicker.startClosing();
        }
    }

    highlighted: _emotePicker.visible
    font.family: "Material Icons"
    flat: true
    text: "\ue87c"

    Component.onCompleted: addUnicodeEmoji()

    function appendVisibleItem(imageUrl, emoteName, insertText, emojiText) {
        setsVisible.append({
            "imageUrl": imageUrl,
            "emoteName": emoteName,
            "insertText": insertText || emoteName,
            "emojiText": emojiText || ""
        });
    }

    function unicodeEmojiImageUrl(text) {
        var codepoints = [];
        for (var i = 0; i < text.length; i++) {
            var code = text.charCodeAt(i);
            if (code >= 0xD800 && code <= 0xDBFF && i + 1 < text.length) {
                var low = text.charCodeAt(++i);
                code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00);
            }
            if (code === 0xFE0F) {
                continue;
            }
            codepoints.push(code.toString(16));
        }
        return unicodeEmojiImageBase + codepoints.join("-") + ".png";
    }

    function addUnicodeEmoji() {
        for (var i = 0; i < unicodeEmoji.length; i++) {
            var emoji = unicodeEmoji[i];
            appendVisibleItem(unicodeEmojiImageUrl(emoji.text), emoji.name, emoji.text, emoji.text);
        }
        _emotePicker.updateFilter();
    }

    Connections {
        target: chat
        onChannelChanged: Qt.callLater(loadEmotes);
    }
    
    function showLastSet() {
        //console.log("showing last set", lastSet);
        switch(lastSet) {
        case "bttvGlobal":
            for (var i in chat.lastBttvGlobalEmotes) {
                appendVisibleItem("image://bttvemote/" + chat.lastBttvGlobalEmotes[i], i);
            }
            break;
        case "bttvChannel":
            for (var i in chat.lastBttvChannelEmotes) {
                appendVisibleItem("image://bttvemote/" + chat.lastBttvChannelEmotes[i], i);
            }
            break;
        case "ffzGlobal":
            for (var i in chat.lastFfzGlobalEmotes) {
                appendVisibleItem("image://ffzemote/" + chat.lastFfzGlobalEmotes[i], i);
            }
            break;
        case "ffzChannel":
            for (var i in chat.lastFfzChannelEmotes) {
                appendVisibleItem("image://ffzemote/" + chat.lastFfzChannelEmotes[i], i);
            }
            break;
        default:
            var lastSetMap = lastEmoteSets[lastSet];
            for (var i in lastSetMap) {
                appendVisibleItem("image://emote/" + i, Util.decodeHtml(Util.inverseRegex(lastSetMap[i])));
            }
            break;
        }
        _emotePicker.updateFilter();
    }
    
    function clearChannelSpecificEmotes() {
        //console.log("clearChannelSpecificEmotes()")
        var channelEmotes = chat.lastBttvChannelEmotes;
        var ffzChannelEmotes = chat.lastFfzChannelEmotes;
        if (channelEmotes != null || ffzChannelEmotes != null) {
            for (var i = 0; i < setsVisible.count; ) {
                var obj = setsVisible.get(i);
                if ((channelEmotes != null && channelEmotes.hasOwnProperty(obj.emoteName)) ||
                        (ffzChannelEmotes != null && ffzChannelEmotes.hasOwnProperty(obj.emoteName))) {
                    //console.log("remove channel emote", obj.emoteName, i);
                    setsVisible.remove(i);
                } else {
                    i++;
                }
            }
        }
        _emoteButton.pickerChannelLoaded = null;
    }
    
    function nextDownload() {
        if (emotePickerDownloadsInProgress) {
            if (curDownloading < setsToDownload.length) {
                var curSetID = setsToDownload[curDownloading];
                lastSet = curSetID;
                curDownloading ++;
                console.log("Downloading emote set #", curDownloading, curSetID);
                if (curSetID == "bttvGlobal") {
                    chat.downloadBttvEmotesGlobal();
                } else if (curSetID == "bttvChannel") {
                    chat.downloadBttvEmotesChannel();
                } else if (curSetID == "ffzGlobal") {
                    chat.downloadFfzEmotesGlobal();
                } else if (curSetID == "ffzChannel") {
                    chat.downloadFfzEmotesChannel();
                } else {
                    var curSetMap = lastEmoteSets[curSetID];
                    var curSetList = [];
                    for (var i in curSetMap) {
                        curSetList.push(i);
                    }
                    chat.bulkDownloadEmotes(curSetList);
                }
            } else {
                console.log("Emote set downloads complete");
                emotePickerDownloadsInProgress = false;
                _emotePicker.loading = false;
            }
        }
    }
    
    function startDownload(emoteSets) {
        curDownloading = 0;
        setsToDownload = [];
        if (emoteSets != null) {
            lastEmoteSets = emoteSets;
            for (var i in emoteSets) {
                setsToDownload.push(i);
            }
            setsToDownload.push("bttvGlobal");
            setsToDownload.push("ffzGlobal");
        }
        if (chat.lastBttvChannelEmotes != null) {
            setsToDownload.push("bttvChannel");
        }
        if (chat.lastFfzChannelEmotes != null) {
            setsToDownload.push("ffzChannel");
        }
        //console.log("Starting download of emote sets", setsToDownload);
        emotePickerDownloadsInProgress = true;
        
        nextDownload();
    }
    
    Connections {
        target: chat
        onBulkDownloadComplete: {
            //console.log("outer download complete");
            if (_emoteButton.emotePickerDownloadsInProgress) {
                //console.log("handling emote picker set finished");
                _emoteButton.showLastSet();
                _emoteButton.nextDownload();
            }
        }
    }
}
