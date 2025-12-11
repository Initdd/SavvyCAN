import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material 6.5
import QtQuick.Effects

Page {
    id: framesPage

    property bool debugLogging: true
    property bool graphVisible: false

    Component.onCompleted: {
        if (debugLogging) {
            console.log("FramesView onCompleted - checking mainWindowQML...");
            console.log("  mainWindowQML available?", typeof mainWindowQML !== 'undefined');
            if (typeof mainWindowQML !== 'undefined') {
                console.log("  mainWindowQML is:", mainWindowQML);
            }
        }
    }

    signal clearFrames
    signal overwriteChanged(bool checked)
    signal interpretChanged(bool checked)

    // Track overwrite mode state
    property bool overwriteMode: false

    // Track if DBC files are loaded (controlled from C++)
    property bool hasDBCFiles: false

    // Track interpret mode state
    property bool interpretMode: false

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
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                height: 28
                icon.source: "qrc:/icons/images/unstack.svg"
                onClicked: {
                    overwriteMode = !overwriteMode;
                    overwriteChanged(overwriteMode);
                }
                ToolTip {
                    text: overwriteMode ? qsTr("Collapse All") : qsTr("Expand All")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: overwriteMode ? ThemeManager.accentColor : ThemeManager.borderColor
                    border.width: overwriteMode ? 2 : 1
                    radius: 4
                }
            }

            Button {
                id: chkInterpret
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                height: 28
                enabled: hasDBCFiles
                checkable: true
                checked: false
                icon.source: "qrc:/icons/images/interpret.svg"
                onClicked: {
                    if (enabled) {
                        interpretMode = checked;
                        interpretChanged(checked);
                    }
                }
                ToolTip {
                    text: qsTr("Interpret CAN frames using DBC files")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: parent.checked ? ThemeManager.accentColor : ThemeManager.borderColor
                    border.width: parent.checked ? 2 : 1
                    radius: 4
                }
            }

            Button {
                id: btnGraph
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                height: 28
                icon.source: "qrc:/icons/images/open_graph.svg"
                onClicked: {
                    graphVisible = !graphVisible;
                }
                ToolTip {
                    text: qsTr("Create Graph")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: graphVisible ? ThemeManager.accentColor : ThemeManager.borderColor
                    border.width: graphVisible ? 2 : 1
                    radius: 4
                }
            }

            Button {
                id: btnExpandAll
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                height: 28
                icon.source: allExpanded ? "qrc:/icons/images/colapse.svg" : "qrc:/icons/images/expand.svg"
                onClicked: {
                    var setTo = !allExpanded;
                    for (var i = 0; i < framesModel.count; i++) {
                        framesModel.set(i, {
                            "expanded": setTo
                        });
                    }
                    allExpanded = setTo;
                }
                ToolTip {
                    text: allExpanded ? qsTr("Collapse All") : qsTr("Expand All")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                id: btnClear
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                height: 28
                icon.source: "qrc:/icons/images/clear.svg"
                onClicked: clearFrames()

                ToolTip {
                    text: qsTr("Clear")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
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
                        if (debugLogging)
                            console.log("ListView completed. Model count:", framesModel.count);
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

                                Item {
                                    Layout.fillWidth: true
                                }
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

                            // Helper function to parse signals from dataHex
                            function getSignalLines() {
                                var lines = dataHex.split('\n');
                                var signals = [];
                                var inSignals = false;

                                for (var i = 0; i < lines.length; i++) {
                                    var line = lines[i].trim();
                                    // Skip the hex data line and message name
                                    if (line.startsWith('<') && line.endsWith('>')) {
                                        inSignals = true;
                                        continue;
                                    }
                                    // Check if this looks like a signal line (has ':' and value)
                                    if (inSignals && line.indexOf(':') > 0) {
                                        signals.push(line);
                                    }
                                }
                                return signals;
                            }

                            // Data text: show one line with elide when collapsed
                            Text {
                                id: dataText
                                Layout.fillWidth: true
                                text: {
                                    var lines = dataHex.split('\n');
                                    return "Data [" + length + "]: " + lines[0];
                                }
                                font.pixelSize: 12
                                font.family: "Monospace"
                                color: ThemeManager.textColor
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Show signals when expanded (if interpret mode is on)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                visible: expanded && interpretMode && contentColumn.getSignalLines().length > 0

                                Repeater {
                                    model: expanded ? contentColumn.getSignalLines() : []

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 26
                                        color: "transparent"
                                        radius: 3

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData
                                                font.pixelSize: 11
                                                font.family: "Monospace"
                                                color: ThemeManager.textColor
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            RoundButton {
                                                width: 8
                                                height: 8
                                                z: 10

                                                onClicked: {
                                                    // Extract signal name from the line (format: "SignalName: value")
                                                    var signalLine = modelData;
                                                    var colonIndex = signalLine.indexOf(':');
                                                    if (colonIndex > 0) {
                                                        var signalName = signalLine.substring(0, colonIndex).trim();
                                                        console.log("=== Signal plus button clicked ===");
                                                        console.log("  Signal name:", signalName);
                                                        console.log("  Frame ID:", frameId);
                                                        console.log("  Bus:", bus);

                                                        // Parse frameId which is a hex string
                                                        var frameIdNum = parseInt(frameId, 16);

                                                        // Call C++ to add this specific signal to graph
                                                        if (typeof mainWindowQML !== 'undefined' && mainWindowQML !== null) {
                                                            mainWindowQML.handleAddSignalToGraph(frameIdNum, bus, signalName);
                                                        } else {
                                                            console.log("  ERROR: mainWindowQML is not available!");
                                                        }
                                                    }
                                                }

                                                background: Rectangle {
                                                    radius: width
                                                    color: parent.pressed ? Qt.darker(ThemeManager.accentColor, 1.2) : ThemeManager.accentColor
                                                }

                                                contentItem: Text {
                                                    text: "+"
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    color: "white"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }
                                }
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

                        // Tap to toggle expansion (doesn't interfere with scrolling)
                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: function (eventPoint, button) {
                                // Check if tap is outside the signals area
                                var tapY = eventPoint.position.y;
                                var signalsStartY = contentColumn.height - 30;  // Approximate signals area

                                // Only toggle if not tapping on signals
                                if (!expanded || tapY < signalsStartY) {
                                    framesModel.set(index, {
                                        "expanded": !expanded
                                    });
                                }
                            }
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
    }

    // Functions to update from C++
    function updateStatus(status) {
        statusLabel.text = status;
    }

    function updateFrameCount(count) {
        frameCountLabel.text = "Frames: " + count;
    }

    function setOverwriteChecked(checked) {
        chkOverwrite.checked = checked;
    }

    function setInterpretChecked(checked) {
        chkInterpret.checked = checked;
        interpretMode = checked;
    }

    function setHasDBCFiles(hasFiles) {
        hasDBCFiles = hasFiles;
        // Auto-uncheck interpret if no DBC files
        if (!hasFiles) {
            chkInterpret.checked = false;
            interpretMode = false;
        }
    }

    // Function to add a new CAN frame to the list
    function addCANFrame(timestamp, frameId, extended, remote, direction, bus, length, dataHex) {
        if (debugLogging)
            console.log("addCANFrame called:", frameId, "bus:", bus, "len:", length, "data:", dataHex);

        if (overwriteMode) {
            // In overwrite mode, find and replace existing frame with same ID and bus
            var found = false;
            for (var i = 0; i < framesModel.count; i++) {
                if (framesModel.get(i).frameId === frameId && framesModel.get(i).bus === bus) {
                    // Update existing frame (preserve expanded state if present)
                    var prevExpanded = framesModel.get(i).expanded ? framesModel.get(i).expanded : false;
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
                    });
                    found = true;
                    if (debugLogging)
                        console.log("  Updated existing frame at index", i);
                    break;
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
                });
                if (debugLogging)
                    console.log("  Appended new frame. Total count:", framesModel.count);
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
            });

            // Limit the number of frames to prevent performance issues
            if (framesModel.count > 1000) {
                framesModel.remove(0);
                if (debugLogging)
                    console.log("  Removed oldest frame (limit reached)");
            }

            if (debugLogging)
                console.log("  Appended frame. Total count:", framesModel.count);
        }

        // Update the frame count
        updateFrameCount(framesModel.count);
    }

    // Function to clear all frames
    function clearFramesList() {
        framesModel.clear();
        updateFrameCount(0);
    }
}
