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
    property bool hasSignals: false

    // Keep reference to the single series
    property var currentSeries: null

    Component.onCompleted: {
        console.log("GraphView Component.onCompleted");
        if (graphController) {
            console.log("  GraphController available");
            // Connect to graph controller signals
            console.log("  Connecting to graphController.signalChanged...");
            graphController.signalChanged.connect(onSignalChanged);
            console.log("  Connecting to graphController.dataUpdated...");
            graphController.dataUpdated.connect(onDataUpdated);
            console.log("  Connecting to graphController.rangesChanged...");
            graphController.rangesChanged.connect(onRangesChanged);
            console.log("  All connections established");

            // Initial check
            onSignalChanged();
        } else {
            console.log("  ERROR: GraphController NOT available!");
        }
    }

    // Handle signal changed (added/removed/updated)
    function onSignalChanged() {
        console.log("=== onSignalChanged called ===");

        if (graphController) {
            hasSignals = graphController.signalDefined();
        }

        // Clear existing series
        chartView.removeAllSeries();
        currentSeries = null;

        if (graphController.signalDefined()) {
            var name = graphController.getSignalName();
            var color = graphController.getSignalColor();
            console.log("  Signal name:", name);
            console.log("  Signal color:", color);

            console.log("  Creating LineSeries...");
            // Create a new series for this signal
            var series = chartView.createSeries(ChartView.SeriesTypeLine, name, xAxis, yAxis);
            series.color = color;
            series.width = 2;
            series.useOpenGL = true; // Enable OpenGL for better performance

            // Store reference
            currentSeries = series;
            chartView.visible = true;

            // Update ranges
            updateRanges();

            // Load initial data if any
            onDataUpdated();
        } else {
            console.log("  No signal defined");
            chartView.visible = false;
        }
    }

    // Handle data updated
    function onDataUpdated() {
        graphController.updateSeries(chartView.series(0));
    }

    // Handle ranges changed
    function onRangesChanged() {
        updateRanges();
    }

    // Update axis ranges
    function updateRanges() {
        if (!graphController || !graphController.signalDefined()) {
            return;
        }

        // Get time range
        var timeRange = graphController.getTimeRangeMap();
        xAxis.min = timeRange.min;
        xAxis.max = timeRange.max;

        // Get value range
        var valueRange = graphController.getValueRangeMap();
        yAxis.min = valueRange.min;
        yAxis.max = valueRange.max;
    }

    function removeSignal() {
        if (graphController) {
            graphController.removeSignal();
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
                width: 36
                height: 28
                onClicked: removeSignal()
                enabled: hasSignals
                icon.source: "qrc:/icons/images/clear.svg"
                ToolTip {
                    text: qsTr("Clear the current signal from the graph")
                }
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")) : "transparent"
                    border.color: ThemeManager.borderColor
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                width: 36
                height: 28
                onClicked: {
                    // Close the graph overlay
                    var framesView = graphPage.parent;
                    while (framesView && !framesView.hasOwnProperty('graphVisible')) {
                        framesView = framesView.parent;
                    }
                    if (framesView) {
                        framesView.graphVisible = false;
                    }
                }

                icon.source: "qrc:/icons/images/exit_graph.svg"
                icon.color: ThemeManager.errorColor

                ToolTip {
                    text: qsTr("Close Graph")
                }
                background: Rectangle {
                    color: parent.pressed ? ThemeManager.buttonPressedColor : (parent.hovered ? ThemeManager.buttonHoverColor : "transparent")
                    border.color: ThemeManager.errorColor
                    border.width: 1
                    radius: 4
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
            clip: true

            ChartView {
                id: chartView
                anchors.centerIn: parent
                width: parent.height
                height: parent.width
                rotation: -90
                antialiasing: true
                backgroundColor: ThemeManager.secondaryBackgroundColor
                legend.visible: true
                legend.alignment: Qt.AlignBottom

                // Remove margins
                margins.top: 0
                margins.bottom: 0
                margins.left: 0
                margins.right: 0

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
                    chartView.legend.color = ThemeManager.backgroundColor;
                    chartView.legend.labelColor = ThemeManager.textColor;
                }

                // Mouse/Touch area for panning
                MouseArea {
                    id: chartMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton

                    property real lastX: 0
                    property real lastY: 0
                    property bool isPanning: false

                    onPressed: function (mouse) {
                        lastX = mouse.x;
                        lastY = mouse.y;
                        isPanning = true;
                        chartView.plotAreaColor = Qt.rgba(0.8, 0.8, 0.8, 0.1);
                    }

                    onPositionChanged: function (mouse) {
                        if (isPanning) {
                            var dx = mouse.x - lastX;
                            var dy = mouse.y - lastY;

                            // Calculate pan amount in axis units
                            var xRange = xAxis.max - xAxis.min;
                            var yRange = yAxis.max - yAxis.min;
                            var xPan = -(dx / chartView.plotArea.width) * xRange;
                            var yPan = (dy / chartView.plotArea.height) * yRange;

                            // Apply pan
                            chartView.scrollLeft(xPan);
                            chartView.scrollUp(yPan);

                            lastX = mouse.x;
                            lastY = mouse.y;
                        }
                    }

                    onReleased: {
                        isPanning = false;
                        chartView.plotAreaColor = "transparent";
                    }

                    onCanceled: {
                        isPanning = false;
                        chartView.plotAreaColor = "transparent";
                    }
                }

                // Pinch to zoom
                PinchArea {
                    anchors.fill: parent

                    property real initialZoomX: 1.0
                    property real initialZoomY: 1.0

                    onPinchStarted: {
                        chartView.plotAreaColor = Qt.rgba(0.8, 0.8, 0.8, 0.1);
                        initialZoomX = 1.0;
                        initialZoomY = 1.0;
                    }

                    onPinchUpdated: function (pinch) {
                        // Calculate zoom factor change since last update
                        var zoomFactorX = pinch.scale / initialZoomX;
                        var zoomFactorY = pinch.scale / initialZoomY;

                        // Apply zoom centered on pinch center
                        var centerX = pinch.center.x;
                        var centerY = pinch.center.y;

                        // Convert pixel coordinates to axis values
                        var xRatio = centerX / chartView.plotArea.width;
                        var yRatio = centerY / chartView.plotArea.height;

                        var xRange = xAxis.max - xAxis.min;
                        var yRange = yAxis.max - yAxis.min;

                        var centerXValue = xAxis.min + xRatio * xRange;
                        var centerYValue = yAxis.max - yRatio * yRange;

                        // Calculate new ranges
                        var newXRange = xRange / zoomFactorX;
                        var newYRange = yRange / zoomFactorY;

                        // Keep center point fixed
                        xAxis.min = centerXValue - xRatio * newXRange;
                        xAxis.max = centerXValue + (1 - xRatio) * newXRange;
                        yAxis.min = centerYValue - (1 - yRatio) * newYRange;
                        yAxis.max = centerYValue + yRatio * newYRange;

                        initialZoomX = pinch.scale;
                        initialZoomY = pinch.scale;
                    }

                    onPinchFinished: {
                        chartView.plotAreaColor = "transparent";
                    }
                }
            }

            // Empty state message
            Label {
                anchors.centerIn: parent
                text: qsTr("No signals added yet.\n\nClick the '+' button to add signals to the graph.")
                font.pixelSize: 14
                color: ThemeManager.secondaryTextColor
                horizontalAlignment: Text.AlignHCenter
                visible: !hasSignals
            }
        }

        // Graph info/stats
        Label {
            Layout.fillWidth: true
            text: hasSignals ? qsTr("Signal: %1 | Time range: %2s").arg(graphController ? graphController.getSignalName() : "").arg(xAxis.max.toFixed(2)) : qsTr("No active signals")
            font.pixelSize: 11
            color: ThemeManager.secondaryTextColor
            horizontalAlignment: Text.AlignLeft
        }
    }

    // Public functions to add series dynamically
    function addLineSeries(name, color) {
        var series = chartView.createSeries(ChartView.SeriesTypeLine, name, xAxis, yAxis);
        series.color = color;
        series.width = 2;
        return series;
    }

    function removeLineSeries(series) {
        chartView.removeSeries(series);
    }

    function clearChart() {
        chartView.removeAllSeries();
    }

    function updateAxisRanges(xMin, xMax, yMin, yMax) {
        xAxis.min = xMin;
        xAxis.max = xMax;
        yAxis.min = yMin;
        yAxis.max = yMax;
    }

    function resetZoom() {
        chartView.zoomReset();
    }

    // Function called from C++ to show signal picker
    property int pickerFrameId: 0
    property int pickerBus: 0
    property string pickerMessageName: ""
    property var pickerSignals: []

    function showSignalPicker(frameId, bus, messageName, signals) {
        console.log("showSignalPicker called:", messageName, "signals:", signals.length);
        pickerFrameId = frameId;
        pickerBus = bus;
        pickerMessageName = messageName;
        pickerSignals = signals;
        signalPickerDialog.open();
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
                                    text: "Bit: " + modelData.startBit + " | Size: " + modelData.signalSize + " | " + (modelData.isLittleEndian ? "LE" : "BE") + " | " + (modelData.isSigned ? "Signed" : "Unsigned")
                                    font.pixelSize: 12
                                    color: ThemeManager.secondaryTextColor
                                }
                            }

                            background: Rectangle {
                                color: parent.hovered ? ThemeManager.hoverColor : "transparent"
                            }

                            onClicked: {
                                console.log("Selected signal:", modelData.name);
                                graphController.addSignal(pickerFrameId, pickerBus, modelData.startBit, modelData.signalSize, modelData.isSigned, modelData.isLittleEndian, modelData.name, modelData.min, modelData.max);
                                signalPickerDialog.close();
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: "Cancel"
                    onClicked: signalPickerDialog.close()
                }
            }
        }
    }
}
