import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material 6.5

Page {
    id: framesPage
    
    signal clearFrames()
    signal overwriteChanged(bool checked)
    signal interpretChanged(bool checked)
    
    // Track overwrite mode state
    property bool overwriteMode: false
    
    // Track if DBC files are loaded (controlled from C++)
    property bool hasDBCFiles: false
    
    // Track whether all rows are expanded
    property bool allExpanded: false
    
    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }
    
    // QML ListModel for CAN frames
    ListModel {
        id: framesModel
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Status label
        Label {
            id: statusLabel
            Layout.fillWidth: true
            text: "Status: Not Connected"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            background: Rectangle {
                color: statusLabel.text.indexOf("Not Connected") < 0 ? "#2ECC71" : ThemeManager.backgroundColor
                border.color: ThemeManager.borderColor
                border.width: 1
                radius: 4
            }
            padding: 8
            color: ThemeManager.textColor
        }
        
        // Display options and controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Button {
                id: chkOverwrite
                width: 36
                height: 28
                onClicked: {
                    overwriteMode = !overwriteMode
                    overwriteChanged(overwriteMode)
                }
                contentItem: Image {
                    source: overwriteMode ? "qrc:/icons/images/stack.svg" : "qrc:/icons/images/unstack.svg"
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                }
                ToolTip {
                    text: overwriteMode ? qsTr("Collapse All") : qsTr("Expand All")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: ThemeManager.borderColor 
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                id: chkInterpret
                width: 36
                height: 28
                enabled: hasDBCFiles
                onClicked: {
                    if (enabled) {
                        var newState = !chkInterpret.checked
                        chkInterpret.checked = newState
                        interpretChanged(newState)
                    }
                }
                contentItem: Image {
                    source: "qrc:/icons/images/interpret.svg"
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    opacity: enabled ? 1.0 : 0.5
                }
                ToolTip {
                    text: qsTr("Interpret CAN frames using DBC files")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: ThemeManager.borderColor 
                    border.width: 1
                    radius: 4
                }
            }
            
            Item {
                Layout.fillWidth: true
            }
            
            Button {
                id: btnExpandAll
                width: 36
                height: 28
                onClicked: {
                    var setTo = !allExpanded
                    for (var i = 0; i < framesModel.count; i++) {
                        framesModel.set(i, { "expanded": setTo })
                    }
                    allExpanded = setTo
                }
                contentItem: Image {
                    source: allExpanded ? "qrc:/icons/images/colapse.svg" : "qrc:/icons/images/expand.svg"
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                }
                ToolTip {
                    text: allExpanded ? qsTr("Collapse All") : qsTr("Expand All")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: ThemeManager.borderColor 
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                id: btnClear
                width: 36
                height: 28
                onClicked: clearFrames()
                contentItem: Image {
                    source: "qrc:/icons/images/clear.svg"
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                }
                ToolTip { text: qsTr("Clear") }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
            }
        }
        
        // CAN Frames List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            border.color: ThemeManager.borderColor
            border.width: 1
            color: ThemeManager.secondaryBackgroundColor
            
            ScrollView {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                
                ListView {
                    id: canFramesListView
                    anchors.fill: parent
                    model: framesModel
                    spacing: 2
                    
                    Component.onCompleted: {
                        console.log("ListView completed. Model count:", framesModel.count)
                    }
                    
                    delegate: Rectangle {
                        width: canFramesListView.width
                        // row height grows when expanded to fit contentColumn implicitHeight
                        height: expanded ? Math.max(70, contentColumn.implicitHeight + 8) : 70
                        color: index % 2 ? ThemeManager.frameEvenRow : ThemeManager.frameOddRow
                        border.color: ThemeManager.frameBorder
                        border.width: 1

                        required property int index
                        required property string timestamp
                        required property string frameId
                        required property bool extended
                        required property bool remote
                        required property string direction
                        required property int bus
                        required property int length
                        required property string dataHex
                        // whether this row is expanded to show full text (model role)
                        required property bool expanded

                        ColumnLayout {
                            id: contentColumn
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Label {
                                    text: "ID: " + frameId
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: ThemeManager.textColor
                                }

                                Label {
                                    text: "[Ext]"
                                    font.pixelSize: 10
                                    color: ThemeManager.secondaryTextColor
                                    visible: extended
                                }

                                Label {
                                    text: "[RTR]"
                                    font.pixelSize: 10
                                    color: ThemeManager.secondaryTextColor
                                    visible: remote
                                }

                                Item { Layout.fillWidth: true }
                                Label {
                                    text: "Bus " + bus
                                    font.pixelSize: 11
                                    color: ThemeManager.secondaryTextColor
                                }

                                Label {
                                    text: direction
                                    font.pixelSize: 11
                                    color: direction === "Rx" ? ThemeManager.rxColor : ThemeManager.txColor
                                }
                            }

                            // Data text: show one line with elide when collapsed, wrap and show full content when expanded
                            Text {
                                id: dataText
                                Layout.fillWidth: true
                                text: "Data [" + length + "]: " + dataHex
                                font.pixelSize: 12
                                font.family: "Monospace"
                                color: ThemeManager.textColor
                                wrapMode: expanded ? Text.WordWrap : Text.NoWrap
                                elide: expanded ? Text.ElideNone : Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                // clicking is handled by the full-row MouseArea below
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "Delta: " + timestamp + " s"
                                font.pixelSize: 10
                                color: ThemeManager.tertiaryTextColor
                            }
                        }

                        // clip children so when collapsed wrapped text doesn't overflow into next row
                        clip: true

                        // whole-row click toggles expansion
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: framesModel.set(index, { "expanded": !expanded })
                        }

                        // dynamic height handled by binding above
                    }
                    
                    // Show message when empty
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("No frames received yet.\nConnect to a CAN device to see frames.")
                        font.pixelSize: 14
                        color: ThemeManager.secondaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        visible: canFramesListView.count === 0
                    }
                }
            }
        }
        
        // Frame count label
        Label {
            id: frameCountLabel
            Layout.fillWidth: true
            text: "Frames: 0"
            font.pixelSize: 12
            color: ThemeManager.secondaryTextColor
            horizontalAlignment: Text.AlignRight
        }
    }
    
    // Functions to update from C++
    function updateStatus(status) {
        statusLabel.text = status
    }
    
    function updateFrameCount(count) {
        frameCountLabel.text = "Frames: " + count
    }
    
    function setOverwriteChecked(checked) {
        chkOverwrite.checked = checked
    }
    
    function setInterpretChecked(checked) {
        chkInterpret.checked = checked
    }
    
    function setHasDBCFiles(hasFiles) {
        hasDBCFiles = hasFiles
        // Auto-uncheck interpret if no DBC files
        if (!hasFiles) {
            chkInterpret.checked = false
        }
    }
    
    // Function to add a new CAN frame to the list
    function addCANFrame(timestamp, frameId, extended, remote, direction, bus, length, dataHex) {
        console.log("addCANFrame called:", frameId, "bus:", bus, "len:", length, "data:", dataHex)
        
        if (overwriteMode) {
            // In overwrite mode, find and replace existing frame with same ID and bus
            var found = false
            for (var i = 0; i < framesModel.count; i++) {
                if (framesModel.get(i).frameId === frameId && framesModel.get(i).bus === bus) {
                    // Update existing frame (preserve expanded state if present)
                    var prevExpanded = framesModel.get(i).expanded ? framesModel.get(i).expanded : false
                    framesModel.set(i, {
                        "timestamp": timestamp,
                        "frameId": frameId,
                        "extended": extended,
                        "remote": remote,
                        "direction": direction,
                        "bus": bus,
                        "length": length,
                        "dataHex": dataHex,
                        "expanded": prevExpanded
                    })
                    found = true
                    console.log("  Updated existing frame at index", i)
                    break
                }
            }
            
            // If not found, add as new frame
            if (!found) {
                framesModel.append({
                    "timestamp": timestamp,
                    "frameId": frameId,
                    "extended": extended,
                    "remote": remote,
                    "direction": direction,
                    "bus": bus,
                    "length": length,
                    "dataHex": dataHex,
                    "expanded": false
                })
                console.log("  Appended new frame. Total count:", framesModel.count)
            }
        } else {
            // Normal mode: just append
            framesModel.append({
                "timestamp": timestamp,
                "frameId": frameId,
                "extended": extended,
                "remote": remote,
                "direction": direction,
                "bus": bus,
                "length": length,
                "dataHex": dataHex,
                "expanded": false
            })
            
            // Limit the number of frames to prevent performance issues
            if (framesModel.count > 1000) {
                framesModel.remove(0)
                console.log("  Removed oldest frame (limit reached)")
            }
            
            console.log("  Appended frame. Total count:", framesModel.count)
        }
        
        // Update the frame count
        updateFrameCount(framesModel.count)
    }
    
    // Function to clear all frames
    function clearFramesList() {
        framesModel.clear()
        updateFrameCount(0)
    }
}
