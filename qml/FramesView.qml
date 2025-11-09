import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: framesPage
    
    signal clearFrames()
    signal overwriteChanged(bool checked)
    signal interpretChanged(bool checked)
    
    // Track overwrite mode state
    property bool overwriteMode: false
    
    // Track if DBC files are loaded (controlled from C++)
    property bool hasDBCFiles: false
    
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
                color: ThemeManager.surfaceColor
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
            
            CheckBox {
                id: chkOverwrite
                text: qsTr("Overwrite")
                font.pixelSize: 14
                onCheckedChanged: {
                    overwriteMode = checked
                    overwriteChanged(checked)
                }
                contentItem: Text {
                    text: chkOverwrite.text
                    font: chkOverwrite.font
                    color: ThemeManager.textColor
                    leftPadding: chkOverwrite.indicator.width + chkOverwrite.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            CheckBox {
                id: chkInterpret
                text: qsTr("Interpret")
                font.pixelSize: 14
                enabled: hasDBCFiles
                onCheckedChanged: {
                    if (enabled) {
                        interpretChanged(checked)
                    }
                }
                contentItem: Text {
                    text: chkInterpret.text
                    font: chkInterpret.font
                    color: chkInterpret.enabled ? ThemeManager.textColor : ThemeManager.secondaryTextColor
                    leftPadding: chkInterpret.indicator.width + chkInterpret.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Item {
                Layout.fillWidth: true
            }
            
            Button {
                text: qsTr("Clear")
                font.pixelSize: 14
                onClicked: clearFrames()
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ThemeManager.buttonTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : ThemeManager.buttonColor)
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
                        height: 70
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
                        
                        ColumnLayout {
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
                            
                            Label {
                                Layout.fillWidth: true
                                text: "Data [" + length + "]: " + dataHex
                                font.pixelSize: 12
                                font.family: "Monospace"
                                color: ThemeManager.textColor
                                elide: Text.ElideRight
                            }
                            
                            Label {
                                Layout.fillWidth: true
                                text: "Delta: " + timestamp + " s"
                                font.pixelSize: 10
                                color: ThemeManager.tertiaryTextColor
                            }
                        }
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
                    // Update existing frame
                    framesModel.set(i, {
                        "timestamp": timestamp,
                        "frameId": frameId,
                        "extended": extended,
                        "remote": remote,
                        "direction": direction,
                        "bus": bus,
                        "length": length,
                        "dataHex": dataHex
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
                    "dataHex": dataHex
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
                "dataHex": dataHex
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
