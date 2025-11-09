import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: connectionsPage
    
    signal newConnection()
    signal removeConnection()
    signal resetConnection()
    signal saveBusSettings()
    signal connectionSelectionChanged(int row)
    signal createConnection(string type, string host, string port, string device, int baudRate, int canSpeed)
    signal scanSerialPorts()
    signal connectionDialogOpened()
    signal connectionDialogClosed()
    
    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }
    
    // Simple model for connections list
    ListModel {
        id: connectionsModel
    }
    
    // Connection dialog
    ConnectionDialog {
        id: connectionDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 400)
        
        onAccepted: {
            // Pass appropriate parameters based on connection type
            var hostParam = selectedType === "SocketCAN" ? socketCanHost : hostAddress
            var deviceParam = selectedType === "SERIAL" ? devicePath : ""
            
            createConnection(
                selectedType,
                hostParam,
                port,
                deviceParam,
                baudRate,
                canSpeed
            )
        }
        
        onScanPorts: {
            scanSerialPorts()
        }
        
        onDialogOpened: {
            connectionDialogOpened()
        }
        
        onDialogClosed: {
            connectionDialogClosed()
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Connections table
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            border.color: ThemeManager.borderColor
            border.width: 1
            color: ThemeManager.secondaryBackgroundColor
            
            ListView {
                id: connectionsListView
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                
                model: connectionsModel
                
                // Show placeholder text when empty
                Label {
                    anchors.centerIn: parent
                    text: qsTr("No connections.\nClick 'New Connection' to add one.")
                    font.pixelSize: 14
                    color: ThemeManager.secondaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    visible: connectionsListView.count === 0
                }
                
                highlight: Rectangle {
                    color: ThemeManager.highlightColor
                    opacity: 0.3
                }
                highlightFollowsCurrentItem: true
                
                delegate: ItemDelegate {
                    width: connectionsListView.width
                    height: 60
                    
                    background: Rectangle {
                        color: parent.highlighted ? ThemeManager.highlightColor : "transparent"
                    }
                    
                    contentItem: ColumnLayout {
                        spacing: 4
                        
                        Text {
                            Layout.fillWidth: true
                            text: model.name || "Connection " + (index + 1)
                            font.pixelSize: 16
                            font.bold: true
                            color: ThemeManager.textColor
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: (model.status || "Disconnected") + " • " + (model.port || "No port")
                            font.pixelSize: 12
                            color: model.status === "Connected" ? ThemeManager.connectedColor : ThemeManager.disconnectedColor
                            elide: Text.ElideRight
                        }
                    }
                    
                    onClicked: {
                        connectionsListView.currentIndex = index
                        connectionSelectionChanged(index)
                    }
                }
                
                ScrollBar.vertical: ScrollBar {}
            }
        }
        
        // Connection control buttons
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            
            Button {
                Layout.fillWidth: true
                text: qsTr("New Connection")
                font.pixelSize: 14
                onClicked: connectionDialog.open()
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
            
            Button {
                Layout.fillWidth: true
                text: qsTr("Remove")
                font.pixelSize: 14
                onClicked: removeConnection()
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
            
            Button {
                Layout.fillWidth: true
                Layout.columnSpan: 2
                text: qsTr("Reset Connection")
                font.pixelSize: 14
                onClicked: resetConnection()
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
        
        // Bus settings group
        GroupBox {
            id: groupBus
            Layout.fillWidth: true
            title: qsTr("Bus Settings")
            font.pixelSize: 14
            enabled: false
            
            background: Rectangle {
                color: ThemeManager.groupBoxBackground
                border.color: ThemeManager.borderColor
                border.width: 1
                radius: 4
            }
            
            label: Label {
                x: groupBus.leftPadding
                width: groupBus.availableWidth
                text: groupBus.title
                color: ThemeManager.textColor
                font: groupBus.font
            }
            
            GridLayout {
                anchors.fill: parent
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                
                Label {
                    text: qsTr("Speed:")
                    font.pixelSize: 14
                    color: ThemeManager.textColor
                }
                
                ComboBox {
                    id: cbBusSpeed
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    model: ["125000", "250000", "500000", "1000000"]
                    currentIndex: 2
                }
                
                Label {
                    text: qsTr("Listen Only:")
                    font.pixelSize: 14
                    color: ThemeManager.textColor
                }
                
                CheckBox {
                    id: ckListenOnly
                    Layout.fillWidth: true
                }
                
                Label {
                    text: qsTr("Enable Bus:")
                    font.pixelSize: 14
                    color: ThemeManager.textColor
                }
                
                CheckBox {
                    id: ckEnableBus
                    Layout.fillWidth: true
                }
            }
        }
        
        // Save button
        Button {
            id: btnSaveBus
            Layout.fillWidth: true
            text: qsTr("Save Bus Settings")
            font.pixelSize: 14
            enabled: false
            onClicked: saveBusSettings()
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
        
        // Spacer
        Item {
            Layout.fillHeight: true
        }
    }
    
    // Functions to update from C++
    function enableBusSettings(enable) {
        groupBus.enabled = enable
        btnSaveBus.enabled = enable
    }
    
    function setBusSpeed(speed) {
        var speedStr = speed.toString()
        var index = cbBusSpeed.model.indexOf(speedStr)
        if (index >= 0) {
            cbBusSpeed.currentIndex = index
        }
    }
    
    function setListenOnly(listenOnly) {
        ckListenOnly.checked = listenOnly
    }
    
    function setEnableBus(enable) {
        ckEnableBus.checked = enable
    }
    
    function getBusSpeed() {
        return parseInt(cbBusSpeed.currentText)
    }
    
    function getListenOnly() {
        return ckListenOnly.checked
    }
    
    function getEnableBus() {
        return ckEnableBus.checked
    }
    
    // Functions to manage connections list
    function addConnection(name, status, port, type) {
        connectionsModel.append({
            "name": name,
            "status": status,
            "port": port,
            "type": type
        })
    }
    
    function clearConnections() {
        connectionsModel.clear()
    }
    
    function updateConnection(index, name, status, port, type) {
        if (index >= 0 && index < connectionsModel.count) {
            connectionsModel.set(index, {
                "name": name,
                "status": status,
                "port": port,
                "type": type
            })
        }
    }
    
    function setAvailableSerialPorts(ports) {
        connectionDialog.setAvailablePorts(ports)
    }
}
