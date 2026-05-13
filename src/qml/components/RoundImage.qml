import QtQuick 2.5
import QtGraphicalEffects 1.0

// Reusable round image component

Rectangle {
    id: root
    property string source: ""
    property string fallbackSource: "qrc:/icon/orion.ico"
    color: "black"
    radius: width / 2
    
    Image {
        id: img
        property string requestedSource: root.source
        source: requestedSource
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: false
        onRequestedSourceChanged: source = requestedSource
        onStatusChanged: {
            if (status === Image.Error && requestedSource
                    && String(source) === requestedSource
                    && String(source) !== root.fallbackSource) {
                source = root.fallbackSource
            }
        }
    }
    
    OpacityMask {
        anchors {
            fill: root
            margins: root.border.width
        }

        source: img
        maskSource: parent
    }
}
