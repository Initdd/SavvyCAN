import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: connectionDialog
    title: qsTr("New Connection")
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel

    width: 500
    height: 600

    property string selectedType: "SocketCAN"
    property string hostAddress: ""
    property string port: ""
    property string devicePath: ""
    property string socketCanHost: ""
    property int baudRate: 115200
    property int canSpeed: 500000
    property var availablePorts: []

    signal scanPorts
    signal dialogOpened
    signal dialogClosed

    background: Rectangle {
        color: ThemeManager.backgroundColor
        border.color: ThemeManager.borderColor
        border.width: 1
        radius: 4
    }

    header: Rectangle {
        color: ThemeManager.groupBoxBackground // Use your dark color
        height: 40
        width: parent.width
        border.color: ThemeManager.borderColor
        border.width: 1
        radius: 4
        RowLayout {
            anchors.fill: parent
            Label {
                text: connectionDialog.title
                color: ThemeManager.textColor
                font.pixelSize: 16
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                leftPadding: 16
            }
        }
    }

    footer: DialogButtonBox {
        id: dialogButtons
        standardButtons: connectionDialog.standardButtons

        background: Rectangle {
            color: ThemeManager.groupBoxBackground
            border.color: ThemeManager.borderColor
            border.width: 1
            radius: 4
        }

        // Note: Do NOT call accept()/reject() here - let the button clicks
        // propagate naturally to trigger the Dialog's onAccepted/onRejected

        delegate: Button {
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
    contentItem: ScrollView {
        implicitWidth: 500
        implicitHeight: 600
        clip: true

        ColumnLayout {
            width: parent.width - 20
            anchors.margins: 10
            x: 10
            spacing: 10

            // Connection type selector
            GroupBox {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                title: qsTr("Connection Type")

                background: Rectangle {
                    color: ThemeManager.groupBoxBackground
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }

                label: Label {
                    x: parent.leftPadding
                    width: parent.availableWidth
                    text: parent.title
                    color: ThemeManager.textColor
                    font.pixelSize: 14
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RadioButton {
                        id: rbSocketCAN
                        text: qsTr("SocketCAN (Network)")
                        checked: true
                        onCheckedChanged: if (checked)
                            connectionDialog.selectedType = "SocketCAN"

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: rbSocketCAN.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: rbSocketCAN.checked ? ThemeManager.accentColor : ThemeManager.borderColor
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: ThemeManager.accentColor
                                visible: rbSocketCAN.checked
                            }
                        }

                        contentItem: Text {
                            text: rbSocketCAN.text
                            font: rbSocketCAN.font
                            color: ThemeManager.textColor
                            leftPadding: rbSocketCAN.indicator.width + rbSocketCAN.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    RadioButton {
                        id: rbSerial
                        text: qsTr("GVRET Serial (USB)")
                        onCheckedChanged: if (checked)
                            connectionDialog.selectedType = "SERIAL"

                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            x: rbSerial.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 10
                            border.color: rbSerial.checked ? ThemeManager.accentColor : ThemeManager.borderColor
                            border.width: 2
                            color: "transparent"

                            Rectangle {
                                width: 10
                                height: 10
                                x: 5
                                y: 5
                                radius: 5
                                color: ThemeManager.accentColor
                                visible: rbSerial.checked
                            }
                        }

                        contentItem: Text {
                            text: rbSerial.text
                            font: rbSerial.font
                            color: ThemeManager.textColor
                            leftPadding: rbSerial.indicator.width + rbSerial.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // SocketCAN settings
            GroupBox {

                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                title: qsTr("SocketCAN Settings")
                visible: rbSocketCAN.checked

                background: Rectangle {
                    color: ThemeManager.groupBoxBackground
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }

                label: Label {
                    x: parent.leftPadding
                    width: parent.availableWidth
                    text: parent.title
                    color: ThemeManager.textColor
                    font.pixelSize: 14
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 3
                    columnSpacing: 10
                    rowSpacing: 10

                    Label {
                        text: qsTr("Host:Port:")
                        color: ThemeManager.textColor
                        font.pixelSize: 13
                    }

                    ComboBox {
                        id: cbSocketHost
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        editable: true
                        model: connectionDialog.availablePorts
                        currentIndex: -1  // No default selection
                        displayText: currentIndex === -1 ? qsTr("e.g., 192.168.1.100:29536") : currentText
                        onCurrentTextChanged: {
                            if (currentIndex !== -1) {
                                connectionDialog.socketCanHost = currentText;
                            }
                        }
                        onEditTextChanged: {
                            connectionDialog.socketCanHost = editText;
                        }

                        indicator: Canvas {
                            id: socketHostCanvas
                            x: cbSocketHost.width - width - cbSocketHost.rightPadding
                            y: cbSocketHost.topPadding + (cbSocketHost.availableHeight - height) / 2
                            width: 12
                            height: 8
                            contextType: "2d"

                            Connections {
                                target: cbSocketHost
                                function onPressedChanged() {
                                    socketHostCanvas.requestPaint();
                                }
                            }

                            onPaint: {
                                context.reset();
                                context.moveTo(0, 0);
                                context.lineTo(width, 0);
                                context.lineTo(width / 2, height);
                                context.closePath();
                                context.fillStyle = ThemeManager.textColor;
                                context.fill();
                            }
                        }

                        contentItem: Text {
                            leftPadding: 8
                            rightPadding: cbSocketHost.indicator.width + cbSocketHost.spacing
                            text: cbSocketHost.editable ? cbSocketHost.editText : cbSocketHost.displayText
                            font: cbSocketHost.font
                            color: ThemeManager.textColor
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            color: ThemeManager.inputBackgroundColor
                            border.color: cbSocketHost.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                            border.width: 1
                            radius: 3
                        }

                        popup: Popup {
                            y: cbSocketHost.height - 1
                            width: cbSocketHost.width
                            implicitHeight: contentItem.implicitHeight
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: Math.min(contentHeight, 200)
                                model: cbSocketHost.popup.visible ? cbSocketHost.delegateModel : null
                                currentIndex: cbSocketHost.highlightedIndex

                                ScrollIndicator.vertical: ScrollIndicator {}
                            }

                            background: Rectangle {
                                color: ThemeManager.inputBackgroundColor
                                border.color: ThemeManager.borderColor
                                border.width: 1
                                radius: 3
                            }
                        }

                        // Filter to show only SocketCANd devices
                        delegate: ItemDelegate {
                            width: cbSocketHost.width
                            text: modelData
                            visible: modelData.indexOf("SocketCANd:") >= 0 || modelData.indexOf("GVRET Remote:") >= 0
                            height: visible ? implicitHeight : 0
                            contentItem: Text {
                                text: parent.text
                                color: ThemeManager.textColor
                                font: parent.font
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.highlighted ? ThemeManager.highlightColor : ThemeManager.inputBackgroundColor
                            }
                        }
                    }

                    Button {
                        text: qsTr("Scan")
                        onClicked: connectionDialog.scanPorts()
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

            // Serial settings
            GroupBox {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                title: qsTr("Serial Settings")
                visible: rbSerial.checked

                background: Rectangle {
                    color: ThemeManager.groupBoxBackground
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }

                label: Label {
                    x: parent.leftPadding
                    width: parent.availableWidth
                    text: parent.title
                    color: ThemeManager.textColor
                    font.pixelSize: 14
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 3
                    columnSpacing: 10
                    rowSpacing: 10

                    Label {
                        text: qsTr("Device:")
                        color: ThemeManager.textColor
                        font.pixelSize: 13
                    }

                    ComboBox {
                        id: cbSerialDevice
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        editable: true
                        model: connectionDialog.availablePorts
                        onCurrentTextChanged: connectionDialog.devicePath = currentText

                        indicator: Canvas {
                            id: serialDeviceCanvas
                            x: cbSerialDevice.width - width - cbSerialDevice.rightPadding
                            y: cbSerialDevice.topPadding + (cbSerialDevice.availableHeight - height) / 2
                            width: 12
                            height: 8
                            contextType: "2d"

                            Connections {
                                target: cbSerialDevice
                                function onPressedChanged() {
                                    serialDeviceCanvas.requestPaint();
                                }
                            }

                            onPaint: {
                                context.reset();
                                context.moveTo(0, 0);
                                context.lineTo(width, 0);
                                context.lineTo(width / 2, height);
                                context.closePath();
                                context.fillStyle = ThemeManager.textColor;
                                context.fill();
                            }
                        }

                        contentItem: Text {
                            leftPadding: 8
                            rightPadding: cbSerialDevice.indicator.width + cbSerialDevice.spacing
                            text: cbSerialDevice.editable ? cbSerialDevice.editText : cbSerialDevice.displayText
                            font: cbSerialDevice.font
                            color: ThemeManager.textColor
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            color: ThemeManager.inputBackgroundColor
                            border.color: cbSerialDevice.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                            border.width: 1
                            radius: 3
                        }

                        popup: Popup {
                            y: cbSerialDevice.height - 1
                            width: cbSerialDevice.width
                            implicitHeight: contentItem.implicitHeight
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: Math.min(contentHeight, 200)
                                model: cbSerialDevice.popup.visible ? cbSerialDevice.delegateModel : null
                                currentIndex: cbSerialDevice.highlightedIndex

                                ScrollIndicator.vertical: ScrollIndicator {}
                            }

                            background: Rectangle {
                                color: ThemeManager.inputBackgroundColor
                                border.color: ThemeManager.borderColor
                                border.width: 1
                                radius: 3
                            }
                        }

                        delegate: ItemDelegate {
                            width: cbSerialDevice.width
                            text: modelData
                            contentItem: Text {
                                text: parent.text
                                color: ThemeManager.textColor
                                font: parent.font
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.highlighted ? ThemeManager.highlightColor : ThemeManager.inputBackgroundColor
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: qsTr("No devices found")
                            visible: cbSerialDevice.count === 0
                            color: ThemeManager.placeholderTextColor
                        }
                    }

                    Button {
                        text: qsTr("Scan")
                        onClicked: connectionDialog.scanPorts()
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

                    Label {
                        text: qsTr("Baud Rate:")
                        color: ThemeManager.textColor
                        font.pixelSize: 13
                    }

                    ComboBox {
                        id: cbBaudRate
                        Layout.fillWidth: true
                        Layout.columnSpan: 2
                        model: ["9600", "19200", "38400", "57600", "115200", "230400", "460800", "921600"]
                        currentIndex: 4 // 115200
                        onCurrentTextChanged: connectionDialog.baudRate = parseInt(currentText)

                        indicator: Canvas {
                            id: baudRateCanvas
                            x: cbBaudRate.width - width - cbBaudRate.rightPadding
                            y: cbBaudRate.topPadding + (cbBaudRate.availableHeight - height) / 2
                            width: 12
                            height: 8
                            contextType: "2d"

                            Connections {
                                target: cbBaudRate
                                function onPressedChanged() {
                                    baudRateCanvas.requestPaint();
                                }
                            }

                            onPaint: {
                                context.reset();
                                context.moveTo(0, 0);
                                context.lineTo(width, 0);
                                context.lineTo(width / 2, height);
                                context.closePath();
                                context.fillStyle = ThemeManager.textColor;
                                context.fill();
                            }
                        }

                        contentItem: Text {
                            leftPadding: 8
                            rightPadding: cbBaudRate.indicator.width + cbBaudRate.spacing
                            text: cbBaudRate.displayText
                            font: cbBaudRate.font
                            color: ThemeManager.textColor
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            color: ThemeManager.inputBackgroundColor
                            border.color: cbBaudRate.activeFocus ? ThemeManager.inputFocusBorderColor : ThemeManager.inputBorderColor
                            border.width: 1
                            radius: 3
                        }

                        popup: Popup {
                            y: cbBaudRate.height - 1
                            width: cbBaudRate.width
                            implicitHeight: contentItem.implicitHeight
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: Math.min(contentHeight, 200)
                                model: cbBaudRate.popup.visible ? cbBaudRate.delegateModel : null
                                currentIndex: cbBaudRate.highlightedIndex

                                ScrollIndicator.vertical: ScrollIndicator {}
                            }

                            background: Rectangle {
                                color: ThemeManager.inputBackgroundColor
                                border.color: ThemeManager.borderColor
                                border.width: 1
                                radius: 3
                            }
                        }

                        delegate: ItemDelegate {
                            width: cbBaudRate.width
                            text: modelData
                            contentItem: Text {
                                text: parent.text
                                color: ThemeManager.textColor
                                font: parent.font
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.highlighted ? ThemeManager.highlightColor : ThemeManager.inputBackgroundColor
                            }
                        }
                    }
                }
            }
        }

        onAccepted: {
            // Connection parameters will be read by C++
            console.log("Connection dialog accepted:", selectedType, hostAddress, port);
        }

        onOpened: {
            // Notify C++ that dialog is now open
            dialogOpened();
            // Auto-scan for devices when dialog opens
            scanPorts();
        }

        onClosed: {
            // Notify C++ that dialog is now closed
            dialogClosed();
        }

        // Function to update available ports from C++
        function setAvailablePorts(ports) {
            availablePorts = ports;

            // Auto-select first matching device based on connection type
            if (ports.length > 0) {
                if (rbSerial.checked) {
                    // Find first serial device (not network)
                    for (var i = 0; i < ports.length; i++) {
                        if (ports[i].indexOf("SocketCANd:") < 0 && ports[i].indexOf("GVRET Remote:") < 0) {
                            cbSerialDevice.currentIndex = i;
                            break;
                        }
                    }
                } else if (rbSocketCAN.checked) {
                    // Find first SocketCANd device
                    for (var i = 0; i < ports.length; i++) {
                        if (ports[i].indexOf("SocketCANd:") >= 0 || ports[i].indexOf("GVRET Remote:") >= 0) {
                            cbSocketHost.currentIndex = i;
                            break;
                        }
                    }
                }
            }
        }
    }
}
