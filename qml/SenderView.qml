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

    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }

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
                                        if (model.enabled !== checked) {
                                            cellChanged(index, 0, checked.toString());
                                        }
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

                            // ID and Bus row
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 12
                                rowSpacing: 8

                                Label {
                                    text: qsTr("ID:")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: ThemeManager.textColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    text: model.frameId
                                    font.pixelSize: 13
                                    placeholderText: "0x100"
                                    color: ThemeManager.textColor
                                    placeholderTextColor: ThemeManager.secondaryTextColor
                                    padding: 6

                                    background: Rectangle {
                                        id: bg
                                        color: ThemeManager.inputBackgroundColor
                                        border.color: parent.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                                        border.width: 1
                                        radius: 5

                                        // This item creates a faint patch behind the placeholder to hide border lines
                                        Rectangle {
                                            id: placeholderPatch
                                            visible: parent.placeholderText && parent.text.length === 0
                                            anchors {
                                                left: parent.left
                                                top: parent.top
                                                margins: 4
                                            }
                                            height: 14
                                            width: parent.width / 3    // adjust width as needed
                                            color: ThemeManager.inputBackgroundColor   // same as background, so it's invisible
                                        }
                                    }
                                }



                                Label {
                                    text: qsTr("Bus:")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: ThemeManager.textColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextField {
                                    Layout.preferredWidth: 60
                                    text: model.bus.toString()
                                    font.pixelSize: 13
                                    placeholderText: "0"
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
                                        if (model.bus !== parseInt(text)) {
                                            cellChanged(index, 1, text);
                                        }
                                    }
                                }
                            }

                            // Data row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Layout.alignment: Qt.AlignVCenter

                                Label {
                                    text: qsTr("Data:")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: ThemeManager.textColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    text: model.data
                                    font.pixelSize: 13
                                    font.family: "Monospace"
                                    placeholderText: "00 11 22 33 44 55 66 77"
                                    color: ThemeManager.textColor
                                    placeholderTextColor: ThemeManager.secondaryTextColor
                                    padding: 6
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
                                            width: parent.width / 2
                                            color: ThemeManager.inputBackgroundColor
                                        }
                                    }
                                    onEditingFinished: {
                                        if (model.data !== text) {
                                            cellChanged(index, 4, text);
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
            "count": 0
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
            senderListModel.set(index, {
                "enabled": enabled,
                "bus": bus,
                "frameId": frameId,
                "length": length,
                "data": data,
                "interval": interval,
                "count": count
            });
        }
    }

    function clearSenderList() {
        senderListModel.clear();
    }

    function getSenderCount() {
        return senderListModel.count;
    }
}
