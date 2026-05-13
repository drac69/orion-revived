import QtQuick 2.5
import QtQuick.Controls 2.1
import QtQuick.Controls.Material 2.1
import app.orion 1.0

ToolBar {
    id: root

    property int currentIndex: 0
    signal indexRequested(int index)

    width: 56
    Material.foreground: Material.Grey

    Column {
        anchors.fill: parent

        Repeater {
            model: [
                { "index": 0, "label": "Channels", "icon": "\ue8b6" },
                { "index": 1, "label": "Followed", "icon": "\ue87d" },
                { "index": 2, "label": "Games", "icon": "\ue021" },
                { "index": 3, "label": "VODs", "icon": "\ue63a" },
                { "index": 4, "label": "Player", "icon": "\ue038" },
                { "index": 5, "label": "Settings", "icon": "\ue8b8" }
            ]

            ToolButton {
                id: button

                width: root.width
                height: 56
                checkable: true
                checked: root.currentIndex === modelData.index
                focusPolicy: Qt.NoFocus
                text: modelData.icon
                font.family: "Material Icons"
                font.pointSize: 18
                Material.foreground: checked ? Material.accent : Material.Grey

                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: modelData.label

                onClicked: root.indexRequested(modelData.index)

                background: Rectangle {
                    color: button.checked ? Material.accent : "transparent"
                    opacity: button.checked ? 0.16 : 1
                }

                Rectangle {
                    visible: modelData.index === 5 && !Settings.hasAccessToken
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    color: Material.accent
                    radius: width * 0.5
                    width: 13
                    height: 13

                    Text {
                        anchors.centerIn: parent
                        text: "i"
                        font.bold: true
                        font.pixelSize: 9
                        color: Material.foreground
                    }
                }
            }
        }
    }
}
