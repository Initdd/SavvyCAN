import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 360
    height: 640
    title: "SavvyCAN Mobile"

    property bool graphVisible: false

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
            return 24
        }
        return 0
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
    
    // Graph overlay (slides up from bottom)
    Rectangle {
        id: graphOverlay
        anchors.fill: parent
        visible: graphVisible
        color: ThemeManager.backgroundColor
        z: 100 // Above everything else
        
        // Slide in/out animation
        transform: Translate {
            id: graphTranslate
            y: graphVisible ? 0 : mainWindow.height
            
            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
        
        GraphView {
            id: graphView
            objectName: "graphView"
            anchors.fill: parent
        }
    }
    
    // Floating Action Button (FAB) - always visible in bottom-left
    Rectangle {
        id: fab
        width: 56
        height: 56
        radius: 28
        color: graphVisible ? ThemeManager.secondaryBackgroundColor : ThemeManager.accentColor
        border.color: graphVisible ? ThemeManager.borderColor : ThemeManager.accentColor
        border.width: 2
        z: 101 // Above graph overlay
        visible: true
        
        // Position in bottom-left corner
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.bottomMargin: 16
        
        // Simple shadow using multiple rectangles
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"
            border.color: "#40000000"
            border.width: 2
            z: -1
        }
        
        // Icon
        Image {
            anchors.centerIn: parent
            source: graphVisible ? "qrc:/icons/images/exit_graph.svg" : "qrc:/icons/images/open_graph.svg"
            width: 28
            height: 28
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
        }
        
        // Click to toggle graph
        MouseArea {
            anchors.fill: parent
            onClicked: {
                mainWindow.graphVisible = !mainWindow.graphVisible
            }
            
            // Visual feedback
            onPressed: {
                fab.scale = 0.95
            }
            onReleased: {
                fab.scale = 1.0
            }
        }
        
        // Scale animation
        Behavior on scale {
            NumberAnimation {
                duration: 100
            }
        }
        
        // Pulse animation when graph has signals
        SequentialAnimation on opacity {
            running: graphController && graphController.signalDefined() && !graphVisible
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 1000 }
            NumberAnimation { to: 1.0; duration: 1000 }
        }
    }
}
