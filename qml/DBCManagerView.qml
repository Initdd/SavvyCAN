import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Page {
    id: dbcManagerPage
    
    signal loadDBCFile(string filePath)
    signal removeDBCFile(int index)
    signal refreshDBCList()
    
    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }
    
    // ListModel for DBC files
    ListModel {
        id: dbcFilesModel
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Header
        Label {
            text: qsTr("DBC File Manager")
            font.pixelSize: 18
            font.bold: true
            color: ThemeManager.textColor
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        
        // Info label
        Label {
            text: qsTr("Load and manage DBC files for CAN frame interpretation")
            font.pixelSize: 12
            color: ThemeManager.secondaryTextColor
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
        
        // DBC Files List
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
                    id: dbcFilesListView
                    anchors.fill: parent
                    model: dbcFilesModel
                    spacing: 8
                    
                    delegate: Rectangle {
                        width: dbcFilesListView.width - 10
                        height: fileDetailsColumn.implicitHeight + 20
                        color: ThemeManager.surfaceColor
                        border.color: ThemeManager.borderColor
                        border.width: 1
                        radius: 4
                        
                        x: 5
                        
                        required property int index
                        required property string filename
                        required property string fullPath
                        required property int messageCount
                        required property int associatedBus
                        
                        ColumnLayout {
                            id: fileDetailsColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            
                            // Filename and remove button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                Label {
                                    text: filename
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: ThemeManager.textColor
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }
                                
                                Button {
                                    text: "×"
                                    font.pixelSize: 18
                                    font.bold: true
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: removeDBCFileItem(index)
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: ThemeManager.errorColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: parent.pressed ? ThemeManager.buttonPressedColor : 
                                               (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                                        border.color: ThemeManager.errorColor
                                        border.width: 1
                                        radius: 4
                                    }
                                }
                            }
                            
                            // File info
                            Label {
                                text: "Messages: " + messageCount
                                font.pixelSize: 12
                                color: ThemeManager.secondaryTextColor
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                text: "Bus: " + (associatedBus === -1 ? "All" : associatedBus)
                                font.pixelSize: 12
                                color: ThemeManager.secondaryTextColor
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                text: fullPath
                                font.pixelSize: 10
                                color: ThemeManager.tertiaryTextColor
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                    
                    // Show message when empty
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("No DBC files loaded.\nTap 'Load DBC File' to add one.")
                        font.pixelSize: 14
                        color: ThemeManager.secondaryTextColor
                        horizontalAlignment: Text.AlignHCenter
                        visible: dbcFilesListView.count === 0
                    }
                }
            }
        }
        
        // File count label
        Label {
            id: fileCountLabel
            Layout.fillWidth: true
            text: "Loaded files: 0"
            font.pixelSize: 12
            color: ThemeManager.secondaryTextColor
            horizontalAlignment: Text.AlignRight
        }
        
        // Buttons row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Button {
                text: qsTr("Load DBC File")
                font.pixelSize: 14
                Layout.fillWidth: true
                onClicked: fileDialog.open()
                highlighted: true
                
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ThemeManager.buttonTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.accentColor : 
                           (parent.hovered ? Qt.lighter(ThemeManager.accentColor, 1.2) : ThemeManager.accentColor)
                    border.color: ThemeManager.accentColor
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: qsTr("Refresh")
                font.pixelSize: 14
                Layout.fillWidth: true
                onClicked: refreshDBCList()
                
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
    }
    
    // File dialog for loading DBC files
    FileDialog {
        id: fileDialog
        title: "Select DBC File"
        nameFilters: ["DBC files (*.dbc)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            // Remove "file://" prefix if present
            if (path.startsWith("file://")) {
                path = path.substring(7)
            }
            
            // Save the URI for persistence (before actually loading it)
            if (typeof dbcPersistenceManager !== 'undefined' && dbcPersistenceManager) {
                var fullUri = selectedFile.toString()
                console.log("DBCManagerView: Saving DBC URI for persistence: " + fullUri)
                dbcPersistenceManager.saveDbcUri(fullUri)
            }
            
            loadDBCFile(path)
        }
    }
    
    // Functions to update from C++
    function updateFileCount(count) {
        fileCountLabel.text = "Loaded files: " + count
    }
    
    function clearFilesList() {
        dbcFilesModel.clear()
    }
    
    function addDBCFile(filename, fullPath, messageCount, associatedBus) {
        dbcFilesModel.append({
            "filename": filename,
            "fullPath": fullPath,
            "messageCount": messageCount,
            "associatedBus": associatedBus
        })
        updateFileCount(dbcFilesModel.count)
    }
    
    function removeDBCFileItem(index) {
        // Get the file path before removing from model
        if (index >= 0 && index < dbcFilesModel.count) {
            var fullPath = dbcFilesModel.get(index).fullPath
            
            // Remove from persistence (convert path back to URI if needed)
            if (typeof dbcPersistenceManager !== 'undefined' && dbcPersistenceManager) {
                // Convert file path back to URI format for persistence manager
                var uri = fullPath
                if (!uri.startsWith("content://") && !uri.startsWith("file://")) {
                    uri = "file://" + fullPath
                }
                console.log("DBCManagerView: Removing DBC URI from persistence: " + uri)
                dbcPersistenceManager.removeDbcUri(uri)
            }
            
            dbcFilesModel.remove(index)
            removeDBCFile(index)
            updateFileCount(dbcFilesModel.count)
        }
    }
    
    // Load saved DBC files from persistence
    function loadSavedDbcFiles() {
        if (typeof dbcPersistenceManager === 'undefined' || !dbcPersistenceManager) {
            console.log("DBCManagerView: Persistence manager not available, skipping auto-load")
            return
        }
        
        console.log("DBCManagerView: Cleaning up invalid URIs...")
        var invalidUris = dbcPersistenceManager.cleanupInvalidUris()
        if (invalidUris.length > 0) {
            console.log("DBCManagerView: Removed " + invalidUris.length + " invalid URIs")
        }
        
        var savedUris = dbcPersistenceManager.getSavedDbcUris()
        console.log("DBCManagerView: Found " + savedUris.length + " saved DBC file URIs")
        
        for (var i = 0; i < savedUris.length; i++) {
            var uriString = savedUris[i]
            console.log("DBCManagerView: Loading saved DBC file: " + uriString)
            
            // Convert URI to path for loading
            var path = uriString
            if (path.startsWith("file://")) {
                path = path.substring(7)
            }
            
            // Load the DBC file
            loadDBCFile(path)
        }
        
        if (savedUris.length > 0) {
            console.log("DBCManagerView: Finished loading " + savedUris.length + " saved DBC files")
        }
    }
}
