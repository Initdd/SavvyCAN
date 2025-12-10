import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Page {
    id: dbcManagerPage
    
    signal loadDBCFile(string filePath)
    signal removeDBCFile(int index)
    signal refreshDBCList()
    
    // Loading state
    property bool isLoading: false
    
    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }
    
    // Connect to file selection signal from native picker
    Component.onCompleted: {
        if (typeof dbcPersistenceManager !== 'undefined' && dbcPersistenceManager) {
            dbcPersistenceManager.fileSelected.connect(function(uriString) {
                if (uriString && uriString.length > 0) {
                    console.log("DBCManagerView: File selected from native picker: " + uriString)
                    
                    // Convert URI to path for loading
                    var path = uriString
                    if (path.startsWith("file://")) {
                        path = path.substring(7)
                    }
                    
                    // Load the DBC file
                    loadDBCFile(path)
                }
            })
        }
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
            padding: 8
        }
        
        // DBC Files List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            border.color: ThemeManager.borderColor
            border.width: 1
            color: ThemeManager.secondaryBackgroundColor
            
            // Loading overlay
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                visible: isLoading
                z: 100
                
                Column {
                    anchors.centerIn: parent
                    spacing: 15
                    
                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: isLoading
                        width: 64
                        height: 64
                        
                        contentItem: Item {
                            implicitWidth: 64
                            implicitHeight: 64
                            
                            Item {
                                id: busyItem
                                width: 64
                                height: 64
                                opacity: isLoading ? 1 : 0
                                
                                Behavior on opacity {
                                    OpacityAnimator {
                                        duration: 250
                                    }
                                }
                                
                                RotationAnimator {
                                    target: busyItem
                                    running: isLoading
                                    from: 0
                                    to: 360
                                    loops: Animation.Infinite
                                    duration: 1250
                                }
                                
                                Repeater {
                                    id: repeater
                                    model: 6
                                    
                                    Rectangle {
                                        x: busyItem.width / 2 - width / 2
                                        y: busyItem.height / 2 - height / 2
                                        width: busyItem.width / 7
                                        height: width
                                        radius: width / 2
                                        color: ThemeManager.accentColor
                                        transform: [
                                            Translate {
                                                y: -Math.min(busyItem.width, busyItem.height) * 0.5 + width / 2
                                            },
                                            Rotation {
                                                angle: index / repeater.count * 360
                                                origin.x: width / 2
                                                origin.y: height / 2
                                            }
                                        ]
                                        opacity: 1.0 - index / repeater.count
                                    }
                                }
                            }
                        }
                    }
                    
                    Label {
                        text: qsTr("Loading DBC file...")
                        font.pixelSize: 14
                        color: "white"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            
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
                onClicked: {
                    // Use native Android file picker with proper permissions
                    if (typeof dbcPersistenceManager !== 'undefined' && dbcPersistenceManager) {
                        console.log("DBCManagerView: Opening native file picker")
                        dbcPersistenceManager.openNativeFilePicker()
                    } else {
                        console.warn("DBCManagerView: Persistence manager not available")
                        // Fallback to Qt file dialog
                        fileDialog.open()
                    }
                }
                enabled: !isLoading
                highlighted: true
                
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: parent.enabled ? ThemeManager.textColor : ThemeManager.tertiaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled ? 
                           (parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")) :
                           "transparent"
                    border.color: parent.enabled ? ThemeManager.accentColor : ThemeManager.borderColor
                    border.width: 2
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
    
    // File dialog for loading DBC files (fallback for non-Android or if native picker fails)
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
            
            console.log("DBCManagerView: File selected via Qt FileDialog: " + path)
            loadDBCFile(path)
        }
    }
    
    // Functions to update from C++
    function updateFileCount(count) {
        fileCountLabel.text = "Loaded files: " + count
    }
    
    function setLoading(loading) {
        isLoading = loading
        console.log("DBCManagerView: Loading state changed to:", loading)
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
            
            // Show user-friendly message about removed files
            var fileNames = []
            for (var j = 0; j < invalidUris.length; j++) {
                var filename = dbcPersistenceManager.getFilenameFromUri(invalidUris[j])
                fileNames.push(filename)
            }
            
            // Log detailed message about removed files
            console.warn("DBCManagerView: Lost permissions for " + invalidUris.length + " DBC file(s): " + fileNames.join(", "))
            console.warn("DBCManagerView: This can happen after device reboot or when Android revokes permissions")
            console.warn("DBCManagerView: Please re-add these files using the 'Add DBC File' button")
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
