import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: senderPage

    signal enableAll
    signal disableAll
    signal clearGrid
    signal cellChanged(int row, int column, string value)
    signal addSender
    signal requestDBCMessages
    signal requestDBCSignals(string messageName)
    signal dbcSignalValueChanged(int senderIndex, string messageName, string signalName, var value)

    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }

    property var dbcMessages: []
    property var dbcSignals: []
    property string currentDBCMessage: ""
    property var signalValues: ({}) // Store signal values keyed by signal name

    // ListModel for sender entries
    ListModel {
        id: senderListModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header with title and add button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: qsTr("Frame Senders")
                font.pixelSize: 18
                font.bold: true
                color: ThemeManager.textColor
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("+ Add")
                font.pixelSize: 14
                onClicked: addSenderItem()
                highlighted: true
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ThemeManager.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : ThemeManager.buttonColor)
                    border.color: ThemeManager.borderColor
                    border.width: 2
                    radius: 4
                }
            }
        }

        // Sender list
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
                    id: senderListView
                    anchors.fill: parent
                    model: senderListModel
                    spacing: 8

                    delegate: Rectangle {
                        width: senderListView.width - 10
                        height: senderDetailsColumn.implicitHeight + 20
                        color: ThemeManager.surfaceColor
                        border.color: model.enabled ? ThemeManager.senderEnabledBorder : ThemeManager.senderDisabledBorder
                        border.width: 2
                        radius: 8

                        x: 5

                        ColumnLayout {
                            id: senderDetailsColumn
                            width: parent.width
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 16
                            }
                            spacing: 12

                            // Header row with enable checkbox and delete button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Layout.alignment: Qt.AlignVCenter

                                CheckBox {
                                    id: enableCheckBox
                                    text: checked ? qsTr("Enabled") : qsTr("Disabled")
                                    font.pixelSize: 14
                                    font.bold: true
                                    checked: model.enabled
                                    onCheckedChanged: {
                                        // Use Qt.callLater to break binding loop and ensure model is updated first
                                        Qt.callLater(function() {
                                            if (model.enabled !== checked) {
                                                console.log("Checkbox changed for row", index, "to", checked);
                                                cellChanged(index, 0, checked.toString());
                                            }
                                        });
                                    }
                                    contentItem: Text {
                                        text: enableCheckBox.text
                                        font: enableCheckBox.font
                                        color: ThemeManager.textColor
                                        leftPadding: enableCheckBox.indicator.width + enableCheckBox.spacing
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: "×"
                                    font.pixelSize: 20
                                    font.bold: true
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    background: Rectangle {
                                        radius: 6
                                        color: "transparent"
                                        border.color: ThemeManager.errorColor
                                        border.width: 1
                                    }
                                    onClicked: removeSenderItem(index)

                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: ThemeManager.errorColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        anchors.centerIn: parent
                                    }

                                    hoverEnabled: true
                                    opacity: hovered ? 0.8 : 1
                                }
                            }

                            Rectangle { // Divider line for better separation
                                Layout.fillWidth: true
                                height: 1
                                color: ThemeManager.dividerColor
                                opacity: 0.4
                            }

                            // DBC Mode UI
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                // Capture sender index to avoid shadowing in nested Repeaters
                                readonly property int senderIndex: index

                                // Message selection
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Label {
                                        text: qsTr("Message:")
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: ThemeManager.textColor
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ComboBox {
                                        id: messageComboBox
                                        Layout.fillWidth: true
                                        model: dbcMessages
                                        textRole: "name"
                                        font.pixelSize: 13
                                        displayText: currentIndex >= 0 && dbcMessages.length > 0 ? dbcMessages[currentIndex].name : ""

                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0 && dbcMessages.length > 0) {
                                                var msg = dbcMessages[currentIndex];
                                                // Store message name in the model
                                                senderListModel.setProperty(index, "messageName", msg.name);
                                                // Update frame ID from selected message
                                                cellChanged(index, 2, "0x" + msg.id.toString(16));
                                                // Request signals for this message
                                                requestDBCSignals(msg.name);
                                            }
                                        }

                                        Component.onCompleted: {
                                            // Try to restore previous selection if messageName is set
                                            if (model.messageName) {
                                                for (var i = 0; i < dbcMessages.length; i++) {
                                                    if (dbcMessages[i].name === model.messageName) {
                                                        currentIndex = i;
                                                        break;
                                                    }
                                                }
                                            }
                                        }

                                        contentItem: Text {
                                            leftPadding: 10
                                            rightPadding: messageComboBox.indicator.width + messageComboBox.spacing
                                            text: messageComboBox.displayText
                                            font: messageComboBox.font
                                            color: "white"
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            color: ThemeManager.inputBackgroundColor
                                            border.color: parent.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                                            border.width: 1
                                            radius: 5
                                        }

                                        delegate: ItemDelegate {
                                            width: messageComboBox.width
                                            text: modelData.name || ""
                                            highlighted: messageComboBox.highlightedIndex === index

                                            contentItem: Text {
                                                text: parent.text
                                                color: parent.highlighted ? ThemeManager.backgroundColor : ThemeManager.textColor
                                                font: messageComboBox.font
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                                leftPadding: 10
                                            }

                                            background: Rectangle {
                                                color: parent.highlighted ? ThemeManager.accentColor : "transparent"
                                            }
                                        }

                                        popup: Popup {
                                            y: messageComboBox.height - 1
                                            width: messageComboBox.width
                                            height: Math.min(contentItem.implicitHeight + 2, 300)
                                            padding: 1

                                            contentItem: ListView {
                                                clip: true
                                                implicitHeight: contentHeight
                                                model: messageComboBox.popup.visible ? messageComboBox.delegateModel : null
                                                currentIndex: messageComboBox.highlightedIndex

                                                ScrollIndicator.vertical: ScrollIndicator {}
                                            }

                                            background: Rectangle {
                                                border.color: ThemeManager.borderColor
                                                border.width: 1
                                                color: ThemeManager.secondaryBackgroundColor
                                                radius: 2
                                            }
                                        }
                                    }
                                }

                                // Signals list (dynamically populated based on selected message)
                                Label {
                                    text: qsTr("Signal Values:")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: ThemeManager.textColor
                                    visible: dbcSignals.length > 0
                                }

                                Repeater {
                                    model: dbcSignals

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        
                                        // Store sender index and last valid value for this signal
                                        property int currentSenderIdx: parent.parent.parent.senderIndex
                                        property var lastValidValue: null

                                        Label {
                                            text: modelData.name + ":"
                                            font.pixelSize: 12
                                            color: ThemeManager.textColor
                                            Layout.preferredWidth: 100
                                            elide: Text.ElideRight
                                        }

                                        // Check if signal has enum values
                                        ComboBox {
                                            id: signalCombo
                                            Layout.fillWidth: true
                                            visible: modelData.hasEnumValues
                                            editable: true
                                            model: modelData.enumValues
                                            textRole: "name"
                                            font.pixelSize: 12
                                            displayText: currentIndex >= 0 ? model[currentIndex].name : editText
                                            
                                            // Debounce timer for manual text input
                                            Timer {
                                                id: sendEnumTimer
                                                interval: 300
                                                repeat: false
                                                onTriggered: {
                                                    if (signalCombo.editText.length === 0) {
                                                        return; // Don't send if field is empty
                                                    }
                                                    var msgName = senderListModel.get(parent.currentSenderIdx).messageName || "";
                                                    var editText = signalCombo.editText;
                                                    
                                                    // Try to find the enum value by name
                                                    var foundValue = null;
                                                    for (var i = 0; i < model.length; i++) {
                                                        if (model[i].name === editText) {
                                                            foundValue = model[i].value;
                                                            break;
                                                        }
                                                    }
                                                    
                                                    // If found in enum, use the numeric value; otherwise try to parse as number
                                                    var finalValue = (foundValue !== null) ? foundValue : parseFloat(editText);
                                                    if (!isNaN(finalValue)) {
                                                        dbcSignalValueChanged(parent.currentSenderIdx, msgName, modelData.name, finalValue);
                                                        parent.lastValidValue = finalValue;
                                                    }
                                                }
                                            }
                                            
                                            onCurrentIndexChanged: {
                                                // Dropdown selection - send immediately
                                                if (currentIndex >= 0 && model && model[currentIndex]) {
                                                    sendEnumTimer.stop();
                                                    var msgName = senderListModel.get(parent.currentSenderIdx).messageName || "";
                                                    var enumValue = model[currentIndex];
                                                    // Use the numeric value from the enum
                                                    dbcSignalValueChanged(parent.currentSenderIdx, msgName, modelData.name, enumValue.value);
                                                    parent.lastValidValue = enumValue.value;
                                                }
                                            }
                                            
                                            onEditTextChanged: {
                                                // Manual text input - debounce to avoid sending while typing
                                                if (editable && editText) {
                                                    sendEnumTimer.restart();
                                                }
                                            }

                                            // Set initial value from enum or allow custom input
                                            Component.onCompleted: {
                                                editText = modelData.defaultValue || "0";
                                            }

                                            contentItem: TextField {
                                                leftPadding: 8
                                                rightPadding: signalCombo.indicator.width + signalCombo.spacing
                                                text: signalCombo.editable ? signalCombo.editText : signalCombo.displayText
                                                font: signalCombo.font
                                                color: ThemeManager.textColor
                                                verticalAlignment: Text.AlignVCenter
                                                readOnly: !signalCombo.editable
                                                selectByMouse: true

                                                background: Rectangle {
                                                    color: "transparent"
                                                }
                                            }

                                            background: Rectangle {
                                                color: ThemeManager.inputBackgroundColor
                                                border.color: parent.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                                                border.width: 1
                                                radius: 4
                                            }

                                            delegate: ItemDelegate {
                                                width: signalCombo.width
                                                text: modelData.name || ""
                                                highlighted: signalCombo.highlightedIndex === index

                                                contentItem: Text {
                                                    text: parent.text
                                                    color: parent.highlighted ? ThemeManager.backgroundColor : ThemeManager.textColor
                                                    font: signalCombo.font
                                                    elide: Text.ElideRight
                                                    verticalAlignment: Text.AlignVCenter
                                                    leftPadding: 8
                                                }

                                                background: Rectangle {
                                                    color: parent.highlighted ? ThemeManager.accentColor : "transparent"
                                                }
                                            }

                                            popup: Popup {
                                                y: signalCombo.height - 1
                                                width: signalCombo.width
                                                height: Math.min(contentItem.implicitHeight + 2, 200)
                                                padding: 1

                                                contentItem: ListView {
                                                    clip: true
                                                    implicitHeight: contentHeight
                                                    model: signalCombo.popup.visible ? signalCombo.delegateModel : null
                                                    currentIndex: signalCombo.highlightedIndex

                                                    ScrollIndicator.vertical: ScrollIndicator {}
                                                }

                                                background: Rectangle {
                                                    border.color: ThemeManager.borderColor
                                                    border.width: 1
                                                    color: ThemeManager.secondaryBackgroundColor
                                                    radius: 2
                                                }
                                            }
                                        }

                                        TextField {
                                            id: numericValueField
                                            Layout.fillWidth: true
                                            visible: !modelData.hasEnumValues
                                            text: modelData.defaultValue || "0"
                                            font.pixelSize: 12
                                            placeholderText: "Value"
                                            color: ThemeManager.textColor
                                            placeholderTextColor: ThemeManager.secondaryTextColor
                                            padding: 6
                                            
                                            // Initialize last valid value
                                            Component.onCompleted: {
                                                parent.lastValidValue = parseFloat(text) || 0;
                                            }
                                            
                                            // Debounce timer - waits 300ms after user stops typing before sending
                                            Timer {
                                                id: sendValueTimer
                                                interval: 300
                                                repeat: false
                                                onTriggered: {
                                                    // Use last valid value if field is empty, otherwise parse current text
                                                    var textValue = numericValueField.text.trim();
                                                    var valueToSend;
                                                    
                                                    if (textValue.length === 0) {
                                                        // Field is empty, use last valid value
                                                        valueToSend = parent.lastValidValue !== null ? parent.lastValidValue : 0;
                                                    } else {
                                                        var parsed = parseFloat(textValue);
                                                        if (isNaN(parsed)) {
                                                            // Invalid number, use last valid value
                                                            valueToSend = parent.lastValidValue !== null ? parent.lastValidValue : 0;
                                                        } else {
                                                            // Valid number, use it and update last valid value
                                                            valueToSend = parsed;
                                                            parent.lastValidValue = parsed;
                                                        }
                                                    }
                                                    
                                                    var msgName = senderListModel.get(parent.currentSenderIdx).messageName || "";
                                                    dbcSignalValueChanged(parent.currentSenderIdx, msgName, modelData.name, valueToSend);
                                                }
                                            }
                                            
                                            onTextChanged: {
                                                // Restart timer whenever text changes
                                                sendValueTimer.restart();
                                            }
                                            
                                            onEditingFinished: {
                                                // Immediately send if user presses Enter
                                                sendValueTimer.stop();
                                                var textValue = text.trim();
                                                var valueToSend;
                                                
                                                if (textValue.length === 0) {
                                                    valueToSend = parent.lastValidValue !== null ? parent.lastValidValue : 0;
                                                } else {
                                                    var parsed = parseFloat(textValue);
                                                    if (isNaN(parsed)) {
                                                        valueToSend = parent.lastValidValue !== null ? parent.lastValidValue : 0;
                                                    } else {
                                                        valueToSend = parsed;
                                                        parent.lastValidValue = parsed;
                                                    }
                                                }
                                                
                                                var msgName = senderListModel.get(parent.currentSenderIdx).messageName || "";
                                                dbcSignalValueChanged(parent.currentSenderIdx, msgName, modelData.name, valueToSend);
                                            }

                                            background: Rectangle {
                                                color: ThemeManager.inputBackgroundColor
                                                border.color: parent.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                                                border.width: 1
                                                radius: 4
                                            }
                                        }

                                        Label {
                                            text: modelData.unit || ""
                                            font.pixelSize: 11
                                            color: ThemeManager.secondaryTextColor
                                            visible: modelData.unit && modelData.unit.length > 0
                                        }
                                    }
                                }
                            }

                            // Interval and count row
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 12
                                rowSpacing: 8

                                Label {
                                    text: qsTr("Interval:")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: ThemeManager.textColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    text: model.interval.toString()
                                    font.pixelSize: 13
                                    placeholderText: "100"
                                    color: ThemeManager.textColor
                                    placeholderTextColor: ThemeManager.secondaryTextColor
                                    padding: 6
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    background: Rectangle {
                                        color: ThemeManager.inputBackgroundColor
                                        border.color: parent.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                                        border.width: 1
                                        radius: 5

                                        // Faint patch behind placeholder
                                        Rectangle {
                                            visible: parent.parent.placeholderText && parent.parent.text.length === 0
                                            anchors {
                                                left: parent.left
                                                top: parent.top
                                                margins: 4
                                            }
                                            height: 14
                                            width: parent.width / 3
                                            color: ThemeManager.inputBackgroundColor
                                        }
                                    }
                                    onEditingFinished: {
                                        if (model.interval !== parseInt(text)) {
                                            cellChanged(index, 5, text);
                                        }
                                    }
                                }

                                Label {
                                    text: qsTr("Count:")
                                    font.pixelSize: 13
                                    color: ThemeManager.secondaryTextColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Label {
                                    text: model.count.toString()
                                    font.pixelSize: 13
                                    color: ThemeManager.secondaryTextColor
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }

                    // Show message when empty
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("No senders configured.\nTap '+ Add' to create a new sender.")
                        font.pixelSize: 14
                        color: ThemeManager.secondaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        visible: senderListView.count === 0
                    }
                }
            }
        }

        // Control buttons
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10
            rowSpacing: 10

            Button {
                Layout.fillWidth: true
                text: qsTr("Enable All")
                font.pixelSize: 14
                onClicked: enableAll()
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ThemeManager.buttonTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : ThemeManager.buttonColor)
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("Disable All")
                font.pixelSize: 14
                onClicked: disableAll()
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ThemeManager.buttonTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : ThemeManager.buttonColor)
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("Clear All")
                font.pixelSize: 14
                onClicked: {
                    if (senderListModel.count > 0) {
                        clearGrid();
                        senderListModel.clear();
                    }
                }
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ThemeManager.buttonTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : ThemeManager.buttonColor)
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
            }
        }
    }

    // Functions to manage the sender list
    function addSenderItem() {
        var newIndex = senderListModel.count;
        senderListModel.append({
            "enabled": false,
            "bus": 0,
            "frameId": "0x100",
            "length": 8,
            "data": "00 00 00 00 00 00 00 00",
            "interval": 100,
            "count": 0,
            "messageName": "" // For DBC mode
        });
        // Notify C++ side
        addSender();
    }

    function removeSenderItem(index) {
        if (index >= 0 && index < senderListModel.count) {
            senderListModel.remove(index);
            // TODO: Notify C++ to update sendingData array
        }
    }

    function updateSenderItem(index, enabled, bus, frameId, length, data, interval, count) {
        if (index >= 0 && index < senderListModel.count) {
            var messageName = senderListModel.get(index).messageName || "";
            senderListModel.set(index, {
                "enabled": enabled,
                "bus": bus,
                "frameId": frameId,
                "length": length,
                "data": data,
                "interval": interval,
                "count": count,
                "messageName": messageName
            });
        }
    }

    function clearSenderList() {
        senderListModel.clear();
    }

    function getSenderCount() {
        return senderListModel.count;
    }

    // DBC mode functions
    function setDBCMessages(messages) {
        console.log("setDBCMessages called with", messages.length, "messages");
        dbcMessages = messages;
        console.log("dbcMessages now has", dbcMessages.length, "items");
    }

    function setDBCSignals(signals) {
        console.log("setDBCSignals called with", signals.length, "signals");
        dbcSignals = signals;
    }
}
