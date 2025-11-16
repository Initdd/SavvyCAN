import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

Page {
    id: graphPage
    
    // Toggle to enable/disable QML debug logs from this view
    property bool debugLogging: true
    
    // Apply theme background
    background: Rectangle {
        color: ThemeManager.backgroundColor
    }
    
    // Track if we have any signals to graph
    property bool hasSignals: graphController ? graphController.signalCount > 0 : false
    
    // Keep references to created series
    property var seriesMap: ({})
    
    Component.onCompleted: {
        console.log("GraphView Component.onCompleted")
        if (graphController) {
            console.log("  GraphController available, signalCount:", graphController.signalCount)
            // Connect to graph controller signals
            console.log("  Connecting to graphController.signalAdded...")
            graphController.signalAdded.connect(onSignalAdded)
            console.log("  Connecting to graphController.signalRemoved...")
            graphController.signalRemoved.connect(onSignalRemoved)
            console.log("  Connecting to graphController.dataUpdated...")
            graphController.dataUpdated.connect(onDataUpdated)
            console.log("  Connecting to graphController.rangesChanged...")
            graphController.rangesChanged.connect(onRangesChanged)
            console.log("  Connecting to graphController.signalCountChanged...")
            graphController.signalCountChanged.connect(onSignalCountChanged)
            console.log("  All connections established")
        } else {
            console.log("  ERROR: GraphController NOT available!")
        }
    }
    
    // Handle new signal added
    function onSignalAdded(index) {
        console.log("=== onSignalAdded called with index:", index, "===")
        var name = graphController.getSignalName(index)
        var color = graphController.getSignalColor(index)
        console.log("  Signal name:", name)
        console.log("  Signal color:", color)
        
        console.log("  Creating LineSeries...")
        // Create a new series for this signal
        var series = chartView.createSeries(ChartView.SeriesTypeLine, name, xAxis, yAxis)
        series.color = color
        series.width = 2
        series.useOpenGL = true // Enable OpenGL for better performance
        console.log("  Series created")
        
        // Store reference
        seriesMap[index] = series
        console.log("  Stored in map. Series count:", Object.keys(seriesMap).length)
        
        // Update ranges
        console.log("  Updating ranges...")
        updateRanges()
        console.log("=== onSignalAdded complete ===")
    }
    
    // Handle signal removed
    function onSignalRemoved(index) {
    if (debugLogging) console.log("Signal removed at index:", index)
        
        if (seriesMap[index]) {
            chartView.removeSeries(seriesMap[index])
            delete seriesMap[index]
        }
        
        // Rebuild map with updated indices
        var newMap = {}
        for (var i = 0; i < graphController.signalCount; i++) {
            if (seriesMap[i]) {
                newMap[i] = seriesMap[i]
            }
        }
        seriesMap = newMap
        
        updateRanges()
    }
    
    // Handle data updated
    function onDataUpdated() {
        // Update all series with new data
        for (var index in seriesMap) {
            var series = seriesMap[index]
            var data = graphController.getSignalDataVariant(parseInt(index))
            
            if (data && data.length > 0) {
                // Clear old data
                series.removePoints(0, series.count)
                
                // Add new data points
                for (var i = 0; i < data.length; i++) {
                    series.append(data[i].x, data[i].y)
                }
            }
        }
    }
    
    // Handle ranges changed
    function onRangesChanged() {
        updateRanges()
    }
    
    // Handle signal count changed (detects when all signals are cleared)
    function onSignalCountChanged() {
        if (debugLogging) console.log("Signal count changed to:", graphController.signalCount)
        
        // If count is 0, clear all series from the chart
        if (graphController.signalCount === 0) {
            if (debugLogging) console.log("  Clearing all series from chart")
            chartView.removeAllSeries()
            seriesMap = {}
        }
    }
    
    // Update axis ranges
    function updateRanges() {
        if (!graphController || graphController.signalCount === 0) {
            return
        }
        
        // Get time range
        var timeRange = graphController.getTimeRangeMap()
        xAxis.min = timeRange.min
        xAxis.max = timeRange.max
        
        // Get value range
        var valueRange = graphController.getValueRangeMap()
        yAxis.min = valueRange.min
        yAxis.max = valueRange.max
    }
    
    function removeSignal(index) {
        if (graphController) {
            graphController.removeSignal(index)
        }
    }
    
    function clearAllSignals() {
        if (graphController) {
            graphController.clearAllSignals()
            
            // Clear all series
            chartView.removeAllSeries()
            seriesMap = {}
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Header with controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Label {
                text: qsTr("CAN Signal Graph")
                font.pixelSize: 18
                font.bold: true
                color: ThemeManager.textColor
            }
            
            Item {
                Layout.fillWidth: true
            }
            
            Button {
                text: qsTr("+ Signal")
                onClicked: addSignalRequested()
                enabled: false // Will be enabled when we can select from frames
                ToolTip {
                    text: qsTr("Long-press a frame in the Frames tab to add it to the graph")
                }
                background: Rectangle {
                    color: parent.enabled ? 
                           (parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : ThemeManager.accentColor)) :
                           ThemeManager.buttonDisabledColor
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : ThemeManager.secondaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                text: qsTr("Clear")
                onClicked: clearAllSignals()
                enabled: hasSignals
                ToolTip {
                    text: qsTr("Remove all signals from graph")
                }
                background: Rectangle {
                    color: parent.enabled ? 
                           (parent.pressed ? ThemeManager.buttonPressedColor : 
                           (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")) :
                           "transparent"
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? ThemeManager.textColor : ThemeManager.secondaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        // Chart area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: ThemeManager.secondaryBackgroundColor
            border.color: ThemeManager.borderColor
            border.width: 1
            radius: 4
            
            ChartView {
                id: chartView
                anchors.fill: parent
                anchors.margins: 5
                antialiasing: true
                backgroundColor: ThemeManager.secondaryBackgroundColor
                legend.visible: true
                legend.alignment: Qt.AlignBottom
                
                // Customize theme
                theme: ChartView.ChartThemeDark
                
                // X-axis (time)
                ValueAxis {
                    id: xAxis
                    titleText: "Time (s)"
                    min: 0
                    max: 10
                    tickCount: 6
                    labelFormat: "%.2f"
                    color: ThemeManager.textColor
                    labelsColor: ThemeManager.textColor
                }
                
                // Y-axis (value)
                ValueAxis {
                    id: yAxis
                    titleText: "Value"
                    min: 0
                    max: 255
                    tickCount: 6
                    color: ThemeManager.textColor
                    labelsColor: ThemeManager.textColor
                }
                
                // Enable zoom and pan
                Component.onCompleted: {
                    // Touch/mouse interactions
                    chartView.legend.color = ThemeManager.backgroundColor
                    chartView.legend.labelColor = ThemeManager.textColor
                }
                
                // Mouse/Touch area for panning
                MouseArea {
                    id: chartMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    
                    property real lastX: 0
                    property real lastY: 0
                    property bool isPanning: false
                    
                    onPressed: function(mouse) {
                        lastX = mouse.x
                        lastY = mouse.y
                        isPanning = true
                        chartView.plotAreaColor = Qt.rgba(0.8, 0.8, 0.8, 0.1)
                    }
                    
                    onPositionChanged: function(mouse) {
                        if (isPanning) {
                            var dx = mouse.x - lastX
                            var dy = mouse.y - lastY
                            
                            // Calculate pan amount in axis units
                            var xRange = xAxis.max - xAxis.min
                            var yRange = yAxis.max - yAxis.min
                            var xPan = -(dx / chartView.plotArea.width) * xRange
                            var yPan = (dy / chartView.plotArea.height) * yRange
                            
                            // Apply pan
                            chartView.scrollLeft(xPan)
                            chartView.scrollUp(yPan)
                            
                            lastX = mouse.x
                            lastY = mouse.y
                        }
                    }
                    
                    onReleased: {
                        isPanning = false
                        chartView.plotAreaColor = "transparent"
                    }
                    
                    onCanceled: {
                        isPanning = false
                        chartView.plotAreaColor = "transparent"
                    }
                }
                
                // Pinch to zoom
                PinchArea {
                    anchors.fill: parent
                    
                    property real initialZoomX: 1.0
                    property real initialZoomY: 1.0
                    
                    onPinchStarted: {
                        chartView.plotAreaColor = Qt.rgba(0.8, 0.8, 0.8, 0.1)
                        initialZoomX = 1.0
                        initialZoomY = 1.0
                    }
                    
                    onPinchUpdated: function(pinch) {
                        // Calculate zoom factor change since last update
                        var zoomFactorX = pinch.scale / initialZoomX
                        var zoomFactorY = pinch.scale / initialZoomY
                        
                        // Apply zoom centered on pinch center
                        var centerX = pinch.center.x
                        var centerY = pinch.center.y
                        
                        // Convert pixel coordinates to axis values
                        var xRatio = centerX / chartView.plotArea.width
                        var yRatio = centerY / chartView.plotArea.height
                        
                        var xRange = xAxis.max - xAxis.min
                        var yRange = yAxis.max - yAxis.min
                        
                        var centerXValue = xAxis.min + xRatio * xRange
                        var centerYValue = yAxis.max - yRatio * yRange
                        
                        // Calculate new ranges
                        var newXRange = xRange / zoomFactorX
                        var newYRange = yRange / zoomFactorY
                        
                        // Keep center point fixed
                        xAxis.min = centerXValue - xRatio * newXRange
                        xAxis.max = centerXValue + (1 - xRatio) * newXRange
                        yAxis.min = centerYValue - (1 - yRatio) * newYRange
                        yAxis.max = centerYValue + yRatio * newYRange
                        
                        initialZoomX = pinch.scale
                        initialZoomY = pinch.scale
                    }
                    
                    onPinchFinished: {
                        chartView.plotAreaColor = "transparent"
                    }
                }
            }
            
            // Empty state message
            Label {
                anchors.centerIn: parent
                text: qsTr("No signals added yet.\n\nLong-press a frame in the Frames tab\nto add it to the graph.")
                font.pixelSize: 14
                color: ThemeManager.secondaryTextColor
                horizontalAlignment: Text.AlignHCenter
                visible: !hasSignals
            }
        }
        
        // Signal list (shows what's currently graphed)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: ThemeManager.secondaryBackgroundColor
            border.color: ThemeManager.borderColor
            border.width: 1
            radius: 4
            visible: hasSignals
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 2
                
                Label {
                    text: qsTr("Active Signals:")
                    font.pixelSize: 12
                    font.bold: true
                    color: ThemeManager.textColor
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ListView {
                        id: signalListView
                        model: graphController ? graphController.signalCount : 0
                        spacing: 2
                        
                        delegate: Rectangle {
                            width: signalListView.width
                            height: 30
                            color: index % 2 ? ThemeManager.frameEvenRow : ThemeManager.frameOddRow
                            radius: 2
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5
                                
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 2
                                    color: graphController ? graphController.getSignalColor(index) : "gray"
                                }
                                
                                Label {
                                    Layout.fillWidth: true
                                    text: graphController ? graphController.getSignalName(index) : ""
                                    font.pixelSize: 11
                                    color: ThemeManager.textColor
                                    elide: Text.ElideRight
                                }
                                
                                Button {
                                    text: "×"
                                    width: 24
                                    height: 24
                                    onClicked: removeSignal(index)
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? ThemeManager.buttonPressedColor : 
                                               (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                                        radius: 2
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: ThemeManager.textColor
                                        font.pixelSize: 16
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Graph info/stats
        Label {
            Layout.fillWidth: true
            text: hasSignals ? 
                  qsTr("Signals: %1 | Time range: %2s").arg(graphController ? graphController.signalCount : 0).arg(xAxis.max.toFixed(2)) :
                  qsTr("No active signals")
            font.pixelSize: 11
            color: ThemeManager.secondaryTextColor
            horizontalAlignment: Text.AlignLeft
        }
    }
    
    // Public functions to add series dynamically
    function addLineSeries(name, color) {
        var series = chartView.createSeries(ChartView.SeriesTypeLine, name, xAxis, yAxis)
        series.color = color
        series.width = 2
        return series
    }
    
    function removeLineSeries(series) {
        chartView.removeSeries(series)
    }
    
    function clearChart() {
        chartView.removeAllSeries()
    }
    
    function updateAxisRanges(xMin, xMax, yMin, yMax) {
        xAxis.min = xMin
        xAxis.max = xMax
        yAxis.min = yMin
        yAxis.max = yMax
    }
    
    function resetZoom() {
        chartView.zoomReset()
    }
    
    // Function called from C++ to show signal picker
    property int pickerFrameId: 0
    property int pickerBus: 0
    property string pickerMessageName: ""
    property var pickerSignals: []
    
    function showSignalPicker(frameId, bus, messageName, signals) {
        console.log("showSignalPicker called:", messageName, "signals:", signals.length)
        pickerFrameId = frameId
        pickerBus = bus
        pickerMessageName = messageName
        pickerSignals = signals
        signalPickerDialog.open()
    }
    
    // Signal picker dialog
    Dialog {
        id: signalPickerDialog
        title: "Select Signal to Graph"
        width: Math.min(parent.width * 0.9, 400)
        height: Math.min(parent.height * 0.8, 500)
        anchors.centerIn: parent
        modal: true
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            
            Label {
                Layout.fillWidth: true
                text: "Frame: 0x" + pickerFrameId.toString(16).toUpperCase() + " (" + pickerMessageName + ")"
                font.bold: true
                wrapMode: Text.Wrap
                color: ThemeManager.textColor
            }
            
            Label {
                Layout.fillWidth: true
                text: "Select which signal to graph:"
                color: ThemeManager.textColor
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: ThemeManager.secondaryBackgroundColor
                border.color: ThemeManager.borderColor
                border.width: 1
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    
                    ListView {
                        id: signalPickerListView
                        anchors.fill: parent
                        model: pickerSignals
                        spacing: 5
                        
                        delegate: ItemDelegate {
                            width: ListView.view.width
                            
                            contentItem: ColumnLayout {
                                spacing: 2
                                
                                Label {
                                    text: modelData.name
                                    font.bold: true
                                    color: ThemeManager.textColor
                                }
                                
                                Label {
                                    text: "Bit: " + modelData.startBit + 
                                          " | Size: " + modelData.signalSize + 
                                          " | " + (modelData.isLittleEndian ? "LE" : "BE") + 
                                          " | " + (modelData.isSigned ? "Signed" : "Unsigned")
                                    font.pixelSize: 12
                                    color: ThemeManager.secondaryTextColor
                                }
                            }
                            
                            background: Rectangle {
                                color: parent.hovered ? ThemeManager.hoverColor : "transparent"
                            }
                            
                            onClicked: {
                                console.log("Selected signal:", modelData.name)
                                graphController.addSignal(
                                    pickerFrameId,
                                    pickerBus,
                                    modelData.startBit,
                                    modelData.signalSize,
                                    modelData.isSigned,
                                    modelData.isLittleEndian,
                                    modelData.name
                                )
                                signalPickerDialog.close()
                            }
                        }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancel"
                    onClicked: signalPickerDialog.close()
                }
            }
        }
    }
}
