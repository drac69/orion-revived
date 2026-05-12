import QtQuick 2.5
import QtQuick.Controls 2.1
import app.orion 1.0


MouseArea {
    property alias menu : contextMenu
    property var source : parent
    property string copyAllText: ""
    property string copyAllLabel: "Copy Message"

    QtObject {
        id: d
        property int selectStart
        property int selectEnd
        property int curPos

        function storeSelection() {
            selectStart = source.selectionStart;
            selectEnd = source.selectionEnd;
            curPos = source.cursorPosition;
        }
        function restoreSelection() {
            source.cursorPosition = curPos;
            source.select(selectStart, selectEnd);
        }
    }

    anchors.fill: source
    acceptedButtons: Qt.RightButton
    propagateComposedEvents: true
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor

    onClicked: {
        d.storeSelection();
        contextMenu.x = mouse.x;
        contextMenu.y = mouse.y;
        contextMenu.open();
        mouse.accepted = true
    }
    onPressAndHold: {
        if (mouse.source === Qt.MouseEventNotSynthesized) {
            d.storeSelection();
            contextMenu.x = mouse.x;
            contextMenu.y = mouse.y;
            contextMenu.open();
            mouse.accepted = true
        } else {
            mouse.accepted = false
        }
    }
    Menu {
        id: contextMenu

        onAboutToShow: d.restoreSelection()
        onOpened: d.restoreSelection()
        MenuItem {
            text: "Cut"
            visible: !source.readOnly
            onTriggered: {
                source.cut()
            }
        }
        MenuItem {
            text: "Copy"
            enabled: source.selectedText !== ""
            onTriggered: {
                source.copy()
            }
        }
        MenuItem {
            text: copyAllLabel
            visible: copyAllText !== ""
            onTriggered: Settings.copyToClipboard(copyAllText)
        }
        MenuItem {
            text: "Paste"
            visible: !source.readOnly
            onTriggered: {
                source.paste()
            }
        }
    }
}
