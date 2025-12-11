import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 360
    height: 640
    title: "SavvyCAN Mobile"

    // Apply theme colors
    color: ThemeManager.backgroundColor

    header: TabBar {
        id: tabBar
        currentIndex: swipeView.currentIndex
        topPadding: safeAreaTop
        background: Rectangle {
            color: ThemeManager.tabBarBackground
        }

        TabButton {
            text: qsTr("Connections")
            font.pixelSize: 16
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: parent.checked ? ThemeManager.accentColor : ThemeManager.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        TabButton {
            text: qsTr("Frames")
            font.pixelSize: 16
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: parent.checked ? ThemeManager.accentColor : ThemeManager.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        TabButton {
            text: qsTr("Send")
            font.pixelSize: 16
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: parent.checked ? ThemeManager.accentColor : ThemeManager.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        TabButton {
            text: qsTr("DBC")
            font.pixelSize: 16
            contentItem: Text {
                text: parent.text
                font: parent.font
                color: parent.checked ? ThemeManager.accentColor : ThemeManager.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Safe area insets for notch/status bar
    readonly property real safeAreaTop: {
        if (Qt.platform.os === "android" || Qt.platform.os === "ios") {
            return 24;
        }
        return 0;
    }

    SwipeView {
        id: swipeView
        anchors.fill: parent
        currentIndex: tabBar.currentIndex

        ConnectionsView {
            id: connectionsView
            objectName: "connectionsView"
        }

        FramesView {
            id: framesView
            objectName: "framesView"
            // Disable noisy QML logs by default
            debugLogging: false
        }

        SenderView {
            id: senderView
            objectName: "senderView"
        }

        DBCManagerView {
            id: dbcManagerView
            objectName: "dbcManagerView"
        }
    }
}
