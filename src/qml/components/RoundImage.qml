import QtQuick 2.5
import QtGraphicalEffects 1.0
import "../util.js" as Util

// Reusable round image component

Rectangle {
    id: root
    property string source: ""
    property string fallbackSource: "qrc:/icon/orion.ico"
    color: "black"
    radius: width / 2
    
    Image {
        id: img
        property string requestedSource: Util.imageSourceWithFailureFallback(root.source, root.fallbackSource)
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
                Util.rememberFailedImageSource(requestedSource)
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
