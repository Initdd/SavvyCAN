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
        spacing: 5

        // Header with controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

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
                width: parent.width
                height: parent.height
                rotation: 0
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
                    // text: "Time (s) (time range: NN s)"
                    titleText: qsTr("Time (s) (time range: %1s)").arg((xAxis.max - xAxis.min).toFixed(2))
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
}
