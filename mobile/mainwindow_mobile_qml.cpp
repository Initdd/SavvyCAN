#include "mainwindow_mobile_qml.h"
#include "connections/canconfactory.h"
#include "dbc/dbchandler.h"
#include "graphcontroller.h"
#include <QDebug>
#include <QQmlProperty>
#include <QTimer>
#include <QDir>
#include <QFileInfo>
#include <QNetworkDatagram>

#ifdef Q_OS_ANDROID
#include "android_stubs/qserialport.h"
#else
#include <QSerialPortInfo>
#endif

MainWindowMobileQML *MainWindowMobileQML::selfRef = nullptr;

MainWindowMobileQML::MainWindowMobileQML(QQmlApplicationEngine *engine, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
    , m_rootObject(nullptr)
    , m_framesView(nullptr)
    , m_connectionsView(nullptr)
    , m_senderView(nullptr)
    , m_dbcManagerView(nullptr)
    , m_graphView(nullptr)
    , frameModel(nullptr)
    , canManager(nullptr)
    , graphController(nullptr)
    , senderTimer(nullptr)
    , updateTimer(nullptr)
    , m_connectionUpdateTimer(nullptr)
    , m_statusText("Status: Not Connected")
    , m_frameCount(0)
    , m_selectedConnectionIndex(-1)
    , m_connectionDialogOpen(false)
{
    selfRef = this;
    
    // Initialize model
    frameModel = new CANFrameModel(this);
    
    // Initialize graph controller
    graphController = new GraphController(this);
    
    // Expose to QML BEFORE loading QML
    m_engine->rootContext()->setContextProperty("mainWindowQML", this);
    m_engine->rootContext()->setContextProperty("frameModel", frameModel);
    m_engine->rootContext()->setContextProperty("graphController", graphController);
    
    qDebug() << "MainWindowMobileQML: Context properties set, ready to load QML";
}

void MainWindowMobileQML::connectQMLSignals()
{
    qDebug() << "MainWindowMobileQML: Connecting to QML signals...";
    
    // Get root object from QML
    const QList<QObject *> rootObjects = m_engine->rootObjects();
    if (!rootObjects.isEmpty()) {
        m_rootObject = rootObjects.first();
        
        // Get references to QML views
        m_framesView = m_rootObject->findChild<QObject*>("framesView");
        m_connectionsView = m_rootObject->findChild<QObject*>("connectionsView");
        m_senderView = m_rootObject->findChild<QObject*>("senderView");
        m_dbcManagerView = m_rootObject->findChild<QObject*>("dbcManagerView");
        m_graphView = m_rootObject->findChild<QObject*>("graphView");
        
        qDebug() << "QML views found:";
        qDebug() << "  framesView:" << (m_framesView ? "YES" : "NO");
        qDebug() << "  connectionsView:" << (m_connectionsView ? "YES" : "NO");
        qDebug() << "  senderView:" << (m_senderView ? "YES" : "NO");
        qDebug() << "  dbcManagerView:" << (m_dbcManagerView ? "YES" : "NO");
        qDebug() << "  graphView:" << (m_graphView ? "YES" : "NO");
        
        // Connect QML signals to C++ slots
        if (m_framesView) {
            connect(m_framesView, SIGNAL(clearFrames()), this, SLOT(clearFrames()));
            connect(m_framesView, SIGNAL(overwriteChanged(bool)), this, SLOT(handleOverwriteChanged(bool)));
            connect(m_framesView, SIGNAL(interpretChanged(bool)), this, SLOT(handleInterpretChanged(bool)));
        }
        
        if (m_connectionsView) {
            connect(m_connectionsView, SIGNAL(newConnection()), this, SLOT(handleNewConn()));
            connect(m_connectionsView, SIGNAL(removeConnection()), this, SLOT(handleRemoveConn()));
            connect(m_connectionsView, SIGNAL(resetConnection()), this, SLOT(handleResetConn()));
            connect(m_connectionsView, SIGNAL(saveBusSettings()), this, SLOT(handleSaveBus()));
            connect(m_connectionsView, SIGNAL(connectionSelectionChanged(int)), this, SLOT(handleConnectionSelection(int)));
            connect(m_connectionsView, SIGNAL(createConnection(QString,QString,QString,QString,int,int)), 
                    this, SLOT(handleCreateConnection(QString,QString,QString,QString,int,int)));
            connect(m_connectionsView, SIGNAL(scanSerialPorts()), this, SLOT(handleScanSerialPorts()));
            connect(m_connectionsView, SIGNAL(connectionDialogOpened()), this, SLOT(handleConnectionDialogOpened()));
            connect(m_connectionsView, SIGNAL(connectionDialogClosed()), this, SLOT(handleConnectionDialogClosed()));
        }
        
        if (m_senderView) {
            connect(m_senderView, SIGNAL(enableAll()), this, SLOT(handleEnableAll()));
            connect(m_senderView, SIGNAL(disableAll()), this, SLOT(handleDisableAll()));
            connect(m_senderView, SIGNAL(clearGrid()), this, SLOT(handleClearGrid()));
            connect(m_senderView, SIGNAL(addSender()), this, SLOT(handleAddSender()));
            connect(m_senderView, SIGNAL(cellChanged(int,int,QString)), this, SLOT(handleSenderCellChange(int,int,QString)));
        }
        
        if (m_dbcManagerView) {
            connect(m_dbcManagerView, SIGNAL(loadDBCFile(QString)), this, SLOT(handleLoadDBCFile(QString)));
            connect(m_dbcManagerView, SIGNAL(removeDBCFile(int)), this, SLOT(handleRemoveDBCFile(int)));
            connect(m_dbcManagerView, SIGNAL(refreshDBCList()), this, SLOT(handleRefreshDBCList()));
        }
    }
    
    // Get CAN manager singleton
    canManager = CANConManager::getInstance();
    
    // Initialize sender data
    sendingData.resize(10);
    for (int i = 0; i < sendingData.size(); i++) {
        sendingData[i].enabled = false;
        sendingData[i].bus = 0;
        sendingData[i].setFrameId(0);
        sendingData[i].setExtendedFrameFormat(false);
        sendingData[i].setFrameType(QCanBusFrame::DataFrame);
        sendingData[i].count = 0;
    }
    sendingLastTimeStamp = 0;
    
    // Setup timer for periodic sending
    senderTimer = new QTimer(this);
    connect(senderTimer, &QTimer::timeout, this, &MainWindowMobileQML::handleSenderTick);
    senderTimer->start(10); // 10ms tick
    sendingElapsed.start();
    
    // Setup timer for GUI updates (to batch frame updates for performance)
    updateTimer = new QTimer(this);
    connect(updateTimer, &QTimer::timeout, this, &MainWindowMobileQML::tickGUIUpdate);
    updateTimer->setInterval(250); // Update GUI every 250ms
    updateTimer->start();
    
    setupConnections();
    updateStatus();
    
    // Initialize DBC file list and interpret checkbox state after a small delay
    // to ensure QML views are fully loaded
    // First try to load saved DBC files from persistence, then update the UI
    QTimer::singleShot(500, this, [this]() {
        qDebug() << "MainWindowMobileQML: Starting DBC persistence auto-load";
        
        // Try to load saved DBC files from persistence
        if (m_dbcManagerView) {
            qDebug() << "MainWindowMobileQML: Calling loadSavedDbcFiles on QML";
            bool success = QMetaObject::invokeMethod(m_dbcManagerView, "loadSavedDbcFiles", 
                Qt::AutoConnection);
            if (!success) {
                qWarning() << "MainWindowMobileQML: Failed to invoke loadSavedDbcFiles";
            }
        } else {
            qWarning() << "MainWindowMobileQML: m_dbcManagerView not available";
        }
        
        // After a brief delay, update the DBC UI with whatever files are now loaded
        QTimer::singleShot(200, this, [this]() {
            DBCHandler* dbcHandler = DBCHandler::getReference();
            if (dbcHandler && dbcHandler->getFileCount() > 0) {
                qDebug() << "Initializing DBC UI with" << dbcHandler->getFileCount() << "files";
                updateDBCFileList();
                updateInterpretCheckboxState();
            } else {
                qDebug() << "No DBC files loaded after persistence check";
                // Just ensure the interpret checkbox is disabled
                if (m_framesView) {
                    QMetaObject::invokeMethod(m_framesView, "setHasDBCFiles", 
                        Qt::AutoConnection,
                        Q_ARG(QVariant, false));
                }
            }
        });
    });
    
    // Set up UDP broadcast receivers for device discovery
    rxBroadcastGVRET = new QUdpSocket(this);
    rxBroadcastGVRET->bind(QHostAddress::AnyIPv4, 17222, QAbstractSocket::ShareAddress);
    connect(rxBroadcastGVRET, &QUdpSocket::readyRead, this, &MainWindowMobileQML::readPendingDatagrams);
    
    rxBroadcastKayak = new QUdpSocket(this);
    rxBroadcastKayak->bind(QHostAddress::AnyIPv4, 42000, QAbstractSocket::ShareAddress);
    connect(rxBroadcastKayak, &QUdpSocket::readyRead, this, &MainWindowMobileQML::readPendingDatagrams);
    
    qDebug() << "UDP broadcast listeners initialized (GVRET on 17222, Kayak on 42000)";
}

MainWindowMobileQML::~MainWindowMobileQML()
{
    if (senderTimer) {
        senderTimer->stop();
    }
    if (updateTimer) {
        updateTimer->stop();
    }
}

void MainWindowMobileQML::handleDroppedFile(const QString &filename)
{
    // Stub for Android - file dropping not typically used
    Q_UNUSED(filename);
}

MainWindowMobileQML* MainWindowMobileQML::getReference()
{
    return selfRef;
}

CANFrameModel* MainWindowMobileQML::getCANFrameModel()
{
    return frameModel;
}

void MainWindowMobileQML::setStatusText(const QString &text)
{
    if (m_statusText != text) {
        m_statusText = text;
        emit statusTextChanged();
        
        // Update QML
        if (m_framesView) {
            QMetaObject::invokeMethod(m_framesView, "updateStatus", Q_ARG(QVariant, text));
        }
    }
}

void MainWindowMobileQML::setFrameCount(int count)
{
    if (m_frameCount != count) {
        m_frameCount = count;
        emit frameCountChanged();
        
        // Update QML
        if (m_framesView) {
            QMetaObject::invokeMethod(m_framesView, "updateFrameCount", Q_ARG(QVariant, count));
        }
    }
}

void MainWindowMobileQML::clearFrames()
{
    // Clear the QML ListModel
    if (m_framesView) {
        QMetaObject::invokeMethod(m_framesView, "clearFramesList");
    }
    
    // Also clear the C++ model
    frameModel->clearFrames();
    setFrameCount(0);
    
    // Clear timestamp tracking for timedelta calculation
    lastFrameTimestamp.clear();
}

void MainWindowMobileQML::handleOverwriteChanged(bool checked)
{
    // Enable/disable overwrite mode in the frame model
    // When enabled, only the newest frame for each ID is kept
    frameModel->setOverwriteMode(checked);
    
    // Clear existing frames in QML when enabling overwrite mode
    // to start fresh with just one frame per ID
    if (checked && m_framesView) {
        QMetaObject::invokeMethod(m_framesView, "clearFramesList");
        // Also clear timestamp tracking to reset timedeltas
        lastFrameTimestamp.clear();
    }
}

void MainWindowMobileQML::handleInterpretChanged(bool checked)
{
    qDebug() << "Interpret mode changed to:" << checked;
    frameModel->setInterpretMode(checked);
    
    // When interpret mode changes, we need to refresh the QML display
    // to show interpreted vs raw data for existing frames
    // Clear the QML list and re-add all frames with the new interpretation
    if (m_framesView && frameModel->rowCount() > 0) {
        qDebug() << "Refreshing frames view with interpret mode:" << (checked ? "ON" : "OFF");
        
        // Clear the QML frames list
        QMetaObject::invokeMethod(m_framesView, "clearFramesList");
        
        // Clear timestamp tracking to reset timedeltas
        lastFrameTimestamp.clear();
        
        // Re-add all frames from the model with new interpretation
        // Get a reference to the filtered frames
        const QVector<CANFrame>* filteredFramesPtr = frameModel->getFilteredListReference();

        // Limit to 1000 frames to avoid UI lag. Ensure matching types to avoid std::min template ambiguity.
        int framesToShow = std::min(static_cast<int>(filteredFramesPtr->count()), 1000);
        qDebug() << "Re-rendering" << framesToShow << "frames";

        QVector<CANFrame> framesToDisplay;
        for (int i = 0; i < framesToShow; i++) {
            framesToDisplay.append(filteredFramesPtr->at(i));
        }
        
        // Now process and add them to QML with interpretation
        DBCHandler* dbcHandler = DBCHandler::getReference();
        
        for (const CANFrame& frame : framesToDisplay) {
            // Calculate timedelta (time since last frame with same ID+bus)
            uint64_t idAugmented = frame.frameId() + (frame.bus << 29ull);
            uint64_t currentTimestamp = frame.timeStamp().microSeconds();
            uint64_t timeDelta = 0;
            
            if (lastFrameTimestamp.contains(idAugmented)) {
                timeDelta = currentTimestamp - lastFrameTimestamp[idAugmented];
            }
            lastFrameTimestamp[idAugmented] = currentTimestamp;
            
            // Format timestamp as delta time
            QString timestamp;
            if (timeDelta == 0) {
                timestamp = "0";
            } else {
                timestamp = QString::number(timeDelta / 1000000.0, 'f', 6);
            }
            
            // Format frame ID as hex
            QString frameId = QString("0x%1").arg(frame.frameId(), 0, 16).toUpper();
            
            // Get direction
            QString direction = frame.isReceived ? "Rx" : "Tx";
            
            // Format data as hex
            QByteArray payload = frame.payload();
            QString dataHex;
            for (int i = 0; i < payload.length(); i++) {
                if (i > 0) dataHex += " ";
                dataHex += QString("%1").arg((unsigned char)payload[i], 2, 16, QChar('0')).toUpper();
            }
            
            // Add interpreted data if DBC is loaded and interpret mode is on
            if (checked && dbcHandler && frame.frameType() == QCanBusFrame::DataFrame) {
                DBC_MESSAGE *msg = dbcHandler->findMessage(frame);
                if (msg != nullptr) {
                    dataHex += "\n<" + msg->name + ">";
                    if (msg->comment.length() > 1) {
                        dataHex += "\n" + msg->comment;
                    }
                    
                    // Process all signals
                    for (int j = 0; j < msg->sigHandler->getCount(); j++) {
                        QString sigString;
                        DBC_SIGNAL* sig = msg->sigHandler->findSignalByIdx(j);
                        
                        if ((sig->multiplexParent == nullptr) && sig->processAsText(frame, sigString)) {
                            dataHex += "\n" + sigString;
                            
                            // Handle multiplexed signals
                            if (sig->isMultiplexor) {
                                dataHex += sig->processSignalTree(frame);
                            }
                        }
                    }
                }
            }
            
            // Call QML function to add frame
            QMetaObject::invokeMethod(m_framesView, "addCANFrame",
                Qt::AutoConnection,
                Q_ARG(QVariant, timestamp),
                Q_ARG(QVariant, frameId),
                Q_ARG(QVariant, frame.hasExtendedFrameFormat()),
                Q_ARG(QVariant, frame.frameType() == QCanBusFrame::RemoteRequestFrame),
                Q_ARG(QVariant, direction),
                Q_ARG(QVariant, frame.bus),
                Q_ARG(QVariant, payload.length()),
                Q_ARG(QVariant, dataHex)
            );
        }
        
        qDebug() << "Refreshed" << framesToDisplay.size() << "frames with new interpret mode";
    }
}

void MainWindowMobileQML::handleNewConn()
{
    qDebug() << "handleNewConn called - dialog should be shown from QML";
}

void MainWindowMobileQML::handleCreateConnection(const QString &type, const QString &host, 
                                                 const QString &port, const QString &device, 
                                                 int baudRate, int canSpeed)
{
    qDebug() << "Creating connection with parameters:";
    qDebug() << "  Type:" << type;
    qDebug() << "  Host:" << host;
    qDebug() << "  Port:" << port;
    qDebug() << "  Device:" << device;
    qDebug() << "  Baud Rate:" << baudRate;
    qDebug() << "  CAN Speed:" << canSpeed;
    
    CANConnection* conn = nullptr;
    
    if (type == "MQTT") {
        qDebug() << "Creating MQTT connection...";
        QString mqttAddress = host + ":" + port;
        conn = CanConFactory::create(
            CANCon::MQTT,
            mqttAddress,
            "",
            0,
            canSpeed,
            false,
            0
        );
    }
    else if (type == "SocketCAN") {
        qDebug() << "Creating SocketCAN connection...";
        
        // Parse the host string - it might be prefixed with "SocketCANd: " or "GVRET Remote: "
        QString actualHost = host;
        CANCon::type connType = CANCon::KAYAK;  // Default to SocketCANd
        
        if (actualHost.startsWith("SocketCANd: ")) {
            actualHost = actualHost.mid(12); // Remove "SocketCANd: " prefix
            connType = CANCon::KAYAK;  // Use SocketCANd
        } else if (actualHost.startsWith("GVRET Remote: ")) {
            actualHost = actualHost.mid(14); // Remove "GVRET Remote: " prefix
            connType = CANCon::REMOTE;  // Use GVRET Remote (TCP)
        }
        
        qDebug() << "Parsed host:" << actualHost;
        qDebug() << "Connection type:" << (connType == CANCon::KAYAK ? "SocketCANd" : "GVRET Remote");
        
        QString connectionString;
        
        if (connType == CANCon::KAYAK) {
            // Format the connection string properly for SocketCANd
            // SocketCANd expects format: "can0,can1@IP:PORT" or just "can0@IP:PORT"
            // If user just provided IP:PORT, default to single can0 bus
            connectionString = actualHost;
            if (!connectionString.contains("@") && !connectionString.contains("can")) {
                // Format: IP:PORT -> can0@IP:PORT
                connectionString = "can0@" + actualHost;
            }
            qDebug() << "SocketCANd connection string:" << connectionString;
        } else {
            // For GVRET Remote, just use the IP address (no can0@ prefix)
            // The format should be just "IP_ADDRESS" (port is hardcoded to 23 in gvretserial.cpp)
            connectionString = actualHost;
            qDebug() << "GVRET Remote connection string:" << connectionString;
        }
        
        conn = CanConFactory::create(
            connType,
            connectionString,
            "",
            0,
            canSpeed,
            false,
            0
        );
    }
    else if (type == "SERIAL") {
        qDebug() << "Creating GVRET Serial connection...";
        conn = CanConFactory::create(
            CANCon::GVRET_SERIAL,
            device,
            "",
            baudRate,
            canSpeed,
            false,
            0
        );
    }
    
    if (conn) {
        qDebug() << "Connection object created successfully";
        canManager->add(conn);
        
        qDebug() << "Starting connection...";
        conn->start();
        
        // Force UI update after a delay to allow connection to initialize
        // Use a longer delay to ensure connection is fully established
        QTimer::singleShot(250, this, [this]() {
            updateStatus();
            updateConnectionsList();
        });
    } else {
        qDebug() << "Failed to create connection object";
    }
}

void MainWindowMobileQML::handleRemoveConn()
{
    qDebug() << "Remove connection requested";
    
    const QList<CANConnection*>& conns = canManager->getConnections();
    if (conns.isEmpty()) {
        qDebug() << "No connections to remove";
        return;
    }
    
    // Use selected connection index, or default to first connection
    int indexToRemove = (m_selectedConnectionIndex >= 0 && m_selectedConnectionIndex < conns.size()) 
                        ? m_selectedConnectionIndex : 0;
    
    qDebug() << "Removing connection at index:" << indexToRemove;
    CANConnection* conn = conns[indexToRemove];
    if (conn) {
        conn->stop();
        canManager->remove(conn);
        m_selectedConnectionIndex = -1; // Clear selection
        updateStatus();
        updateConnectionsList();
    }
}

void MainWindowMobileQML::handleResetConn()
{
    qDebug() << "Reset connection requested";
    
    const QList<CANConnection*>& conns = canManager->getConnections();
    if (conns.isEmpty()) {
        qDebug() << "No connections to reset";
        return;
    }
    
    // Use selected connection index, or default to first connection
    int indexToReset = (m_selectedConnectionIndex >= 0 && m_selectedConnectionIndex < conns.size()) 
                       ? m_selectedConnectionIndex : 0;
    
    CANConnection* conn = conns[indexToReset];
    if (conn) {
        qDebug() << "Resetting connection at index:" << indexToReset;
        qDebug() << "Stopping connection...";
        conn->stop();
        
        qDebug() << "Restarting connection...";
        conn->start();
        qDebug() << "Connection restart() called";
        
        updateStatus();
    }
}

void MainWindowMobileQML::handleSaveBus()
{
    qDebug() << "Save bus settings requested";
    
    if (!m_connectionsView) {
        qDebug() << "No connections view available";
        return;
    }
    
    const QList<CANConnection*>& conns = canManager->getConnections();
    if (conns.isEmpty()) {
        qDebug() << "No connections available to configure";
        return;
    }
    
    // Use selected connection index, or default to first connection
    int indexToUpdate = (m_selectedConnectionIndex >= 0 && m_selectedConnectionIndex < conns.size()) 
                        ? m_selectedConnectionIndex : 0;
    
    CANConnection* conn = conns[indexToUpdate];
    if (!conn) {
        qDebug() << "Connection is null at index:" << indexToUpdate;
        return;
    }
    
    // Get values from QML
    QVariant busSpeed, listenOnly, enableBus;
    
    QMetaObject::invokeMethod(m_connectionsView, "getBusSpeed", Q_RETURN_ARG(QVariant, busSpeed));
    QMetaObject::invokeMethod(m_connectionsView, "getListenOnly", Q_RETURN_ARG(QVariant, listenOnly));
    QMetaObject::invokeMethod(m_connectionsView, "getEnableBus", Q_RETURN_ARG(QVariant, enableBus));
    
    qDebug() << "Bus settings - Speed:" << busSpeed << "ListenOnly:" << listenOnly << "Enable:" << enableBus;
    
    // Apply settings to connection
    CANBus busSettings;
    busSettings.setSpeed(busSpeed.toInt());
    busSettings.setListenOnly(listenOnly.toBool());
    busSettings.setActive(enableBus.toBool());
    
    // Most connections support at least bus 0
    conn->setBusSettings(0, busSettings);
    
    qDebug() << "Bus settings applied to connection";
}

void MainWindowMobileQML::handleConnectionSelection(int row)
{
    qDebug() << "Connection selected:" << row;
    
    m_selectedConnectionIndex = row;
    
    if (!m_connectionsView) {
        qDebug() << "No connections view available";
        return;
    }
    
    const QList<CANConnection*>& conns = canManager->getConnections();
    if (row < 0 || row >= conns.size()) {
        qDebug() << "Invalid connection index:" << row;
        m_selectedConnectionIndex = -1;
        // Disable bus settings if invalid selection
        QMetaObject::invokeMethod(m_connectionsView, "enableBusSettings", Q_ARG(QVariant, false));
        return;
    }
    
    // Enable bus settings in QML
    QMetaObject::invokeMethod(m_connectionsView, "enableBusSettings", Q_ARG(QVariant, true));
    
    // Load current bus settings for the selected connection
    CANConnection* conn = conns[row];
    if (conn && conn->getNumBuses() > 0) {
        CANBus busSettings;
        if (conn->getBusSettings(0, busSettings)) {
            // Update QML with current settings
            QMetaObject::invokeMethod(m_connectionsView, "setBusSpeed", Q_ARG(QVariant, busSettings.getSpeed()));
            QMetaObject::invokeMethod(m_connectionsView, "setListenOnly", Q_ARG(QVariant, busSettings.isListenOnly()));
            QMetaObject::invokeMethod(m_connectionsView, "setEnableBus", Q_ARG(QVariant, busSettings.isActive()));
            
            qDebug() << "Loaded bus settings - Speed:" << busSettings.getSpeed() 
                     << "ListenOnly:" << busSettings.isListenOnly() 
                     << "Active:" << busSettings.isActive();
        } else {
            qDebug() << "Failed to get bus settings for connection";
        }
    }
}

void MainWindowMobileQML::handleScanSerialPorts()
{
    qDebug() << "Scanning for serial ports and network devices...";
    
    QStringList portList;
    
    // Use QSerialPortInfo for all platforms (stub on Android)
    QList<QSerialPortInfo> ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &port : ports) {
        qDebug() << "Found device:" << port.portName();
        portList.append(port.portName());
    }
    
    // Add discovered remote GVRET devices
    for (const QString &ip : remoteDeviceIPGVRET) {
        portList.append("GVRET Remote: " + ip);
    }
    
    // Add discovered Kayak/SocketCANd devices
    for (const QString &host : remoteDeviceKayak) {
        portList.append("SocketCANd: " + host);
    }
    
    if (portList.isEmpty()) {
        qDebug() << "No serial ports or network devices found";
        portList << "No devices found";
    }
    
    qDebug() << "Available ports and devices:" << portList;
    
    // Update QML with the list
    if (m_connectionsView) {
        QVariantList variantList;
        for (const QString &port : portList) {
            variantList.append(port);
        }
        QMetaObject::invokeMethod(m_connectionsView, "setAvailableSerialPorts",
                                 Q_ARG(QVariant, QVariant::fromValue(variantList)));
    }
}

void MainWindowMobileQML::updateDeviceList()
{
    // Rebuild and send the full device list to QML
    handleScanSerialPorts();
}

void MainWindowMobileQML::handleConnectionDialogOpened()
{
    qDebug() << "Connection dialog opened - enabling device auto-discovery updates";
    m_connectionDialogOpen = true;
}

void MainWindowMobileQML::handleConnectionDialogClosed()
{
    qDebug() << "Connection dialog closed - disabling device auto-discovery updates";
    m_connectionDialogOpen = false;
}

void MainWindowMobileQML::handleEnableAll()
{
    for (int i = 0; i < sendingData.size(); i++) {
        sendingData[i].enabled = true;
    }
}

void MainWindowMobileQML::handleDisableAll()
{
    for (int i = 0; i < sendingData.size(); i++) {
        sendingData[i].enabled = false;
    }
}

void MainWindowMobileQML::handleClearGrid()
{
    // Stop any active sending
    for (int i = 0; i < sendingData.size(); i++) {
        sendingData[i].enabled = false;
    }
    
    sendingData.clear();
    sendingData.resize(10);
    
    // Initialize each entry with default values
    for (int i = 0; i < sendingData.size(); i++) {
        sendingData[i].enabled = false;
        sendingData[i].bus = 0;
        sendingData[i].setFrameId(0);
        sendingData[i].setExtendedFrameFormat(false);
        sendingData[i].setFrameType(QCanBusFrame::DataFrame);
        sendingData[i].count = 0;
        sendingData[i].triggers.clear();
        sendingData[i].modifiers.clear();
    }
}

void MainWindowMobileQML::handleAddSender()
{
    // Add a new sender entry with default values
    FrameSendData newSender;
    newSender.enabled = false;
    newSender.bus = 0;
    newSender.setFrameId(0x100); // Default ID
    newSender.setExtendedFrameFormat(false);
    newSender.setFrameType(QCanBusFrame::DataFrame);
    newSender.count = 0;
    
    // Set default data payload (8 bytes of zeros)
    QByteArray defaultData(8, 0x00);
    newSender.setPayload(defaultData);
    
    // Set default interval trigger (100ms)
    Trigger defaultTrigger;
    defaultTrigger.bus = -1;
    defaultTrigger.ID = -1;
    defaultTrigger.maxCount = -1;
    defaultTrigger.milliseconds = 100;
    defaultTrigger.currCount = 0;
    defaultTrigger.msCounter = 0;
    defaultTrigger.triggerMask = 0;
    defaultTrigger.readyCount = true;
    newSender.triggers.append(defaultTrigger);
    
    sendingData.append(newSender);
    
    qDebug() << "Added new sender. Total senders:" << sendingData.size();
}

void MainWindowMobileQML::handleSenderCellChange(int row, int col, const QString &value)
{
    if (row < 0 || row >= sendingData.size()) {
        qDebug() << "Invalid row index:" << row;
        return;
    }
    
    int numBuses = CANConManager::getInstance()->getNumBuses();
    
    switch (col) {
        case 0: // Enable
            sendingData[row].enabled = (value == "true" || value == "1");
            break;
        case 1: // Bus
        {
            int busVal = value.toInt();
            if (busVal < -1 || busVal >= numBuses) {
                qDebug() << "Invalid bus value:" << busVal << "(max:" << numBuses - 1 << ")";
                return;
            }
            sendingData[row].bus = busVal;
            break;
        }
        case 2: // ID
        {
            bool ok;
            uint32_t id = value.toUInt(&ok, 16);
            if (!ok || id > 0x1FFFFFFF) {
                qDebug() << "Invalid CAN ID:" << value;
                return;
            }
            sendingData[row].setFrameId(id);
            // Auto-set extended frame if ID > 0x7FF
            if (id > 0x7FF) {
                sendingData[row].setExtendedFrameFormat(true);
            }
            break;
        }
        case 3: // Len
        {
            int len = value.toInt();
            if (len < 0 || len > 64) {
                qDebug() << "Invalid data length:" << len << "(must be 0-64)";
                return;
            }
            sendingData[row].payload().resize(len);
            break;
        }
        case 4: // Data
        {
            // Parse hex data string (space-separated hex bytes)
            QByteArray arr;
#if QT_VERSION >= QT_VERSION_CHECK(5, 14, 0)
            QStringList tokens = value.split(" ", Qt::SkipEmptyParts);
#else
            QStringList tokens = value.split(" ", QString::SkipEmptyParts);
#endif
            arr.reserve(tokens.count());
            for (int j = 0; j < tokens.count(); j++) {
                bool ok;
                int byteVal = tokens[j].toInt(&ok, 16);
                if (!ok || byteVal < 0 || byteVal > 255) {
                    qDebug() << "Invalid hex byte:" << tokens[j];
                    continue;
                }
                arr.append(static_cast<char>(byteVal));
            }
            sendingData[row].setPayload(arr);
            break;
        }
        case 5: // Interval in milliseconds
        {
            int intervalMs = value.toInt();
            if (intervalMs <= 0) {
                qDebug() << "Invalid interval:" << intervalMs << "(must be > 0)";
                // Clear triggers if interval is invalid
                sendingData[row].triggers.clear();
                return;
            }
            
            Trigger thisTrigger;
            thisTrigger.bus = -1;
            thisTrigger.ID = -1;
            thisTrigger.maxCount = -1;
            thisTrigger.milliseconds = intervalMs;
            thisTrigger.currCount = 0;
            thisTrigger.msCounter = 0;
            thisTrigger.triggerMask = 0;
            thisTrigger.readyCount = true;
            
            sendingData[row].triggers.clear();
            sendingData[row].triggers.append(thisTrigger);
            break;
        }
        case 6: // Count
            sendingData[row].count = value.toInt();
            break;
    }
    
    // Update the QML model to reflect the changes
    if (m_senderView && row >= 0 && row < sendingData.size()) {
        QString frameIdHex = QString("0x%1").arg(sendingData[row].frameId(), 0, 16).toUpper();
        
        // Format data as hex string
        QByteArray payload = sendingData[row].payload();
        QString dataHex;
        for (int i = 0; i < payload.length(); i++) {
            if (i > 0) dataHex += " ";
            dataHex += QString("%1").arg((unsigned char)payload[i], 2, 16, QChar('0')).toUpper();
        }
        
        // Get interval from triggers
        int intervalMs = 100;
        if (!sendingData[row].triggers.isEmpty()) {
            intervalMs = sendingData[row].triggers[0].milliseconds;
        }
        
        // Update the QML model item
        QMetaObject::invokeMethod(m_senderView, "updateSenderItem",
            Q_ARG(QVariant, row),
            Q_ARG(QVariant, sendingData[row].enabled),
            Q_ARG(QVariant, sendingData[row].bus),
            Q_ARG(QVariant, frameIdHex),
            Q_ARG(QVariant, payload.length()),
            Q_ARG(QVariant, dataHex),
            Q_ARG(QVariant, intervalMs),
            Q_ARG(QVariant, sendingData[row].count)
        );
    }
}

void MainWindowMobileQML::handleSenderTick()
{
    // Process periodic sending with proper timing tracking
    FrameSendData *sendData;
    Trigger *trigger;
    QVector<CANFrame> sendingList;
    
    /*
     * Requested tick interval was 10ms but the actual interval could be different. 
     * Track by counting microseconds and accumulating for stability.
     */
    quint64 elapsed = sendingElapsed.nsecsElapsed() / 1000ul;
    if (elapsed == 0) elapsed = 1;
    sendingElapsed.start();
    sendingLastTimeStamp += elapsed;
    
    for (int i = 0; i < sendingData.size(); i++) {
        sendData = &sendingData[i];
        if (!sendData->enabled) {
            // Reset counters when disabled
            if (sendData->triggers.count() > 0) {
                for (int j = 0; j < sendData->triggers.count(); j++) {
                    sendData->triggers[j].currCount = 0;
                }
            }
            continue;
        }
        
        if (sendData->triggers.count() == 0)
            continue;
        
        for (int j = 0; j < sendData->triggers.count(); j++) {
            trigger = &sendData->triggers[j];
            if (!trigger->readyCount) continue;
            
            // Track elapsed microseconds
            trigger->msCounter += elapsed;
            
            // Check if it's time to send
            if (trigger->msCounter >= (trigger->milliseconds * 1000)) {
                trigger->msCounter -= (trigger->milliseconds * 1000);
                sendData->count++;
                trigger->currCount++;
                
                // Queue frame for sending
                sendingList.append(*sendData);
                
                // Check if we've reached max count
                if (trigger->maxCount > 0 && trigger->currCount >= trigger->maxCount) {
                    trigger->readyCount = false;
                }
            }
        }
    }
    
    // Send all queued frames as a batch
    if (sendingList.count() > 0) {
        CANConManager::getInstance()->sendFrames(sendingList);
    }
}

void MainWindowMobileQML::connectionStatusUpdated(int connNum)
{
    qDebug() << "Connection status updated for connection:" << connNum;
    
    // Update the status text
    updateStatus();
    
    // Update the connections list to reflect the new status
    // Delay slightly to batch multiple rapid status updates together
    // and allow connection to fully initialize before showing in UI
    if (!m_connectionUpdateTimer) {
        m_connectionUpdateTimer = new QTimer(this);
        m_connectionUpdateTimer->setSingleShot(true);
        m_connectionUpdateTimer->setInterval(150);
        connect(m_connectionUpdateTimer, &QTimer::timeout, this, &MainWindowMobileQML::updateConnectionsList);
    }
    
    // Restart the timer - this batches multiple updates into one
    m_connectionUpdateTimer->start();
}

void MainWindowMobileQML::framesReceived(CANConnection* conn, QVector<CANFrame>& frames)
{
    Q_UNUSED(conn);
    
    if (frames.size() > 0) {
        // Intentionally silence per-batch frame logs to reduce runtime noise
        
        // Get DBC handler for interpretation
        DBCHandler* dbcHandler = DBCHandler::getReference();
        bool interpretMode = frameModel->getInterpretMode();
        
        // Add frames to QML ListModel
        if (m_framesView) {
            int successCount = 0;
            for (const CANFrame& frame : frames) {
                // Calculate timedelta (time since last frame with same ID+bus)
                uint64_t idAugmented = frame.frameId() + (frame.bus << 29ull);
                uint64_t currentTimestamp = frame.timeStamp().microSeconds();
                uint64_t timeDelta = 0;
                
                if (lastFrameTimestamp.contains(idAugmented)) {
                    timeDelta = currentTimestamp - lastFrameTimestamp[idAugmented];
                }
                lastFrameTimestamp[idAugmented] = currentTimestamp;
                
                // Format timestamp as delta time
                QString timestamp;
                if (timeDelta == 0) {
                    timestamp = "0";
                } else {
                    // Display in seconds with microsecond precision
                    timestamp = QString::number(timeDelta / 1000000.0, 'f', 6);
                }
                
                // Format frame ID as hex
                QString frameId = QString("0x%1").arg(frame.frameId(), 0, 16).toUpper();
                
                // Get direction
                QString direction = frame.isReceived ? "Rx" : "Tx";
                
                // Format data as hex
                QByteArray payload = frame.payload();
                QString dataHex;
                for (int i = 0; i < payload.length(); i++) {
                    if (i > 0) dataHex += " ";
                    dataHex += QString("%1").arg((unsigned char)payload[i], 2, 16, QChar('0')).toUpper();
                }
                
                // Add interpreted data if DBC is loaded and interpret mode is on
                if (interpretMode && dbcHandler && frame.frameType() == QCanBusFrame::DataFrame) {
                    DBC_MESSAGE *msg = dbcHandler->findMessage(frame);
                    if (msg != nullptr) {
                        dataHex += "\n<" + msg->name + ">";
                        if (msg->comment.length() > 1) {
                            dataHex += "\n" + msg->comment;
                        }
                        
                        // Process all signals
                        for (int j = 0; j < msg->sigHandler->getCount(); j++) {
                            QString sigString;
                            DBC_SIGNAL* sig = msg->sigHandler->findSignalByIdx(j);
                            
                            if ((sig->multiplexParent == nullptr) && sig->processAsText(frame, sigString)) {
                                dataHex += "\n" + sigString;
                                
                                // Handle multiplexed signals
                                if (sig->isMultiplexor) {
                                    dataHex += sig->processSignalTree(frame);
                                }
                            }
                        }
                    }
                }
                
                // Call QML function to add frame
                bool success = QMetaObject::invokeMethod(m_framesView, "addCANFrame",
                    Qt::AutoConnection,
                    Q_ARG(QVariant, timestamp),
                    Q_ARG(QVariant, frameId),
                    Q_ARG(QVariant, frame.hasExtendedFrameFormat()),
                    Q_ARG(QVariant, frame.frameType() == QCanBusFrame::RemoteRequestFrame),
                    Q_ARG(QVariant, direction),
                    Q_ARG(QVariant, frame.bus),
                    Q_ARG(QVariant, payload.length()),
                    Q_ARG(QVariant, dataHex)
                );
                
                if (success) {
                    successCount++;
                } else {
                    // Silenced: failed to invoke addCANFrame; avoid noisy logs in production
                }
            }
        } else {
            // Silenced: frames view not available
        }
        
        // Send frames to graph controller for graphing
        if (graphController) {
            for (const CANFrame& frame : frames) {
                graphController->processFrame(frame);
            }
        }
    }
    
    // Also add to the C++ model (for compatibility with other parts of the code)
    frameModel->addFrames(conn, frames);
    
    // Update the frame count in the UI
    int totalFrames = frameModel->rowCount();
    setFrameCount(totalFrames);
}

void MainWindowMobileQML::readPendingDatagrams()
{
    // Handle GVRET broadcasts
    while (rxBroadcastGVRET->hasPendingDatagrams()) {
        QNetworkDatagram datagram = rxBroadcastGVRET->receiveDatagram();
        QString senderIP = datagram.senderAddress().toString();
        
        if (!remoteDeviceIPGVRET.contains(senderIP)) {
            remoteDeviceIPGVRET.append(senderIP);
            qDebug() << "Discovered new GVRET device:" << senderIP;
            
            // Auto-update the device list only if the connection dialog is open
            if (m_connectionDialogOpen) {
                updateDeviceList();
            }
        }
    }
    
    // Handle Kayak/SocketCANd broadcasts
    while (rxBroadcastKayak->hasPendingDatagrams()) {
        QNetworkDatagram datagram = rxBroadcastKayak->receiveDatagram();
        QString kayakData = QString::fromUtf8(datagram.data());
        
        // Parse the Kayak broadcast (format: "<bus1;bus2;...>")
        if (kayakData.startsWith("<") && kayakData.endsWith(">")) {
            QString busInfo = kayakData.mid(1, kayakData.length() - 2);
            QString kayakHost = datagram.senderAddress().toString() + ":" + busInfo;
            
            if (!remoteDeviceKayak.contains(kayakHost)) {
                remoteDeviceKayak.append(kayakHost);
                qDebug() << "Discovered new Kayak/SocketCANd device:" << kayakHost;
                
                // Auto-update the device list only if the connection dialog is open
                if (m_connectionDialogOpen) {
                    updateDeviceList();
                }
            }
        }
    }
}


void MainWindowMobileQML::setupConnections()
{
    // Connect to CAN manager signals
    // Connect directly to the model for frame updates (like desktop version)
    connect(canManager, &CANConManager::framesReceived, frameModel, &CANFrameModel::addFrames);
    // Also connect to our handler for logging and UI updates
    connect(canManager, &CANConManager::framesReceived, this, &MainWindowMobileQML::framesReceived);
    connect(canManager, &CANConManager::connectionStatusUpdated, this, &MainWindowMobileQML::connectionStatusUpdated);
}

void MainWindowMobileQML::tickGUIUpdate()
{
    // Trigger bulk refresh on the model - this batches updates for better performance
    int numFrames = frameModel->sendBulkRefresh();
    
    // Always update frame count (even if 0 new frames)
    int totalFrames = frameModel->rowCount();
    setFrameCount(totalFrames);
    
    if (numFrames > 0) {
        qDebug() << "GUI updated with" << numFrames << "new frames, total:" << totalFrames;
    }
}


void MainWindowMobileQML::updateStatus()
{
    QString status = "Status: ";
    
    const QList<CANConnection*>& conns = canManager->getConnections();
    if (conns.isEmpty()) {
        status += "Not Connected";
    } else {
        int connectedCount = 0;
        for (CANConnection* conn : conns) {
            if (conn && conn->getStatus() == CANCon::CONNECTED) {
                connectedCount++;
            }
        }
        
        if (connectedCount > 0) {
            status += QString("Connected (%1/%2)").arg(connectedCount).arg(conns.size());
        } else {
            status += "Disconnected";
        }
    }
    
    setStatusText(status);
}

void MainWindowMobileQML::updateConnectionsList()
{
    qDebug() << "Updating connections list in QML";
    
    if (!m_connectionsView) {
        qDebug() << "No connections view available";
        return;
    }
    
    const QList<CANConnection*>& conns = canManager->getConnections();
    
    // Clear existing list
    QMetaObject::invokeMethod(m_connectionsView, "clearConnections");
    
    // Add all connections (one entry per physical connection, not per bus)
    qDebug() << "Total connections:" << conns.size();
    for (int i = 0; i < conns.size(); i++) {
        if (conns[i]) {
            QString name;
            QString port = conns[i]->getPort();
            QString status = (conns[i]->getStatus() == CANCon::CONNECTED) ? "Connected" : "Disconnected";
            QString type;
            
            // Determine connection type and name based on both type and port
            switch (conns[i]->getType()) {
                case CANCon::GVRET_SERIAL: 
                    // Check if it's a network connection (contains IP address or @)
                    if (port.contains(".") || port.contains("@")) {
                        type = "GVRET Remote";
                        name = QString("GVRET Remote %1").arg(i + 1);
                    } else {
                        type = "GVRET Serial"; 
                        name = QString("Serial %1").arg(i + 1);
                    }
                    break;
                case CANCon::KVASER: 
                    type = "Kvaser"; 
                    name = QString("Kvaser %1").arg(i + 1);
                    break;
                case CANCon::SERIALBUS: 
                    type = "SerialBus"; 
                    name = QString("SerialBus %1").arg(i + 1);
                    break;
                case CANCon::REMOTE: 
                    type = "Remote"; 
                    name = QString("Remote %1").arg(i + 1);
                    break;
                case CANCon::KAYAK: 
                    type = "SocketCANd"; 
                    name = QString("SocketCANd %1").arg(i + 1);
                    // For SocketCANd, show number of buses
                    if (conns[i]->getNumBuses() > 1) {
                        name += QString(" (%1 buses)").arg(conns[i]->getNumBuses());
                    }
                    break;
                case CANCon::MQTT: 
                    type = "MQTT"; 
                    name = QString("MQTT %1").arg(i + 1);
                    break;
                case CANCon::LAWICEL: 
                    type = "Lawicel"; 
                    name = QString("Lawicel %1").arg(i + 1);
                    break;
                default: 
                    type = "Unknown"; 
                    name = QString("Connection %1").arg(i + 1);
                    break;
            }
            
            qDebug() << "  Adding connection:" << i << name << type << status << port;
            
            QMetaObject::invokeMethod(m_connectionsView, "addConnection",
                Q_ARG(QVariant, name),
                Q_ARG(QVariant, status),
                Q_ARG(QVariant, port),
                Q_ARG(QVariant, type)
            );
        }
    }
    
    qDebug() << "Connections list updated in QML";
}

void MainWindowMobileQML::logReceivedFrame(const CANFrame& frame)
{
    frameModel->addFrame(frame, false);
    setFrameCount(frameModel->rowCount());
}

void MainWindowMobileQML::getBusSettings(int bus, CANBus& busSettings)
{
    Q_UNUSED(bus);
    Q_UNUSED(busSettings);
    // Stub for getting bus settings
}

// DBC Manager functions
void MainWindowMobileQML::handleLoadDBCFile(const QString &filePath)
{
    qDebug() << "Loading DBC file:" << filePath;
    
    DBCHandler* dbcHandler = DBCHandler::getReference();
    if (!dbcHandler) {
        qDebug() << "DBCHandler not available";
        return;
    }
    
    DBCFile* dbcFile = dbcHandler->loadDBCFile(filePath);
    if (dbcFile) {
        qDebug() << "DBC file loaded successfully";
        updateDBCFileList();
        updateInterpretCheckboxState();
    } else {
        qDebug() << "Failed to load DBC file";
    }
}

void MainWindowMobileQML::handleRemoveDBCFile(int index)
{
    qDebug() << "Removing DBC file at index:" << index;
    
    DBCHandler* dbcHandler = DBCHandler::getReference();
    if (!dbcHandler) {
        qDebug() << "DBCHandler not available";
        return;
    }
    
    if (index >= 0 && index < dbcHandler->getFileCount()) {
        dbcHandler->removeDBCFile(index);
        updateDBCFileList();
        updateInterpretCheckboxState();
    }
}

void MainWindowMobileQML::handleRefreshDBCList()
{
    qDebug() << "Refreshing DBC file list";
    updateDBCFileList();
}

void MainWindowMobileQML::updateDBCFileList()
{
    if (!m_dbcManagerView) {
        qDebug() << "No DBC manager view available - skipping DBC list update";
        return;
    }
    
    DBCHandler* dbcHandler = DBCHandler::getReference();
    if (!dbcHandler) {
        qDebug() << "DBCHandler not available - skipping DBC list update";
        return;
    }
    
    // Clear existing list
    bool success = QMetaObject::invokeMethod(m_dbcManagerView, "clearFilesList", Qt::AutoConnection);
    if (!success) {
        qDebug() << "Warning: Failed to invoke clearFilesList on DBC manager view";
    }
    
    // Add all loaded DBC files
    int fileCount = dbcHandler->getFileCount();
    qDebug() << "Total DBC files:" << fileCount;
    
    for (int i = 0; i < fileCount; i++) {
        DBCFile* file = dbcHandler->getFileByIdx(i);
        if (file) {
            QString filename = file->getFilename();
            QString fullPath = file->getFullFilename();
            int messageCount = file->messageHandler->getCount();
            int associatedBus = file->getAssocBus();
            
            qDebug() << "  Adding DBC file:" << i << filename << "Messages:" << messageCount << "Bus:" << associatedBus;
            
            success = QMetaObject::invokeMethod(m_dbcManagerView, "addDBCFile",
                Qt::AutoConnection,
                Q_ARG(QVariant, filename),
                Q_ARG(QVariant, fullPath),
                Q_ARG(QVariant, messageCount),
                Q_ARG(QVariant, associatedBus)
            );
            
            if (!success) {
                qDebug() << "Warning: Failed to invoke addDBCFile for" << filename;
            }
        }
    }
    
    qDebug() << "DBC file list updated in QML";
}

void MainWindowMobileQML::updateInterpretCheckboxState()
{
    if (!m_framesView) {
        qDebug() << "No frames view available - skipping interpret checkbox update";
        return;
    }
    
    DBCHandler* dbcHandler = DBCHandler::getReference();
    if (!dbcHandler) {
        qDebug() << "DBCHandler not available - skipping interpret checkbox update";
        return;
    }
    
    // Enable interpret checkbox only if DBC files are loaded
    bool hasDBCFiles = (dbcHandler->getFileCount() > 0);
    
    qDebug() << "Updating interpret checkbox state: hasDBCFiles =" << hasDBCFiles;
    
    // Update the hasDBCFiles property in QML to enable/disable the checkbox
    bool success = QMetaObject::invokeMethod(m_framesView, "setHasDBCFiles", 
        Qt::AutoConnection,
        Q_ARG(QVariant, hasDBCFiles));
    
    if (!success) {
        qDebug() << "Warning: Failed to invoke setHasDBCFiles on frames view";
    }
}

void MainWindowMobileQML::handleAddFrameToGraph(uint32_t frameId, int bus)
{
    qDebug() << "=== handleAddFrameToGraph called ===";
    qDebug() << "  Frame ID: 0x" << QString::number(frameId, 16);
    qDebug() << "  Bus:" << bus;
    
    if (!graphController) {
        qDebug() << "  ERROR: graphController is null!";
        return;
    }
    
    // Clear existing graph (single graph mode - replace on each add)
    qDebug() << "  Clearing existing signals...";
    graphController->clearAllSignals();
    
    // Check if DBC is available for this frame
    DBCHandler* dbcHandler = DBCHandler::getReference();
    DBC_MESSAGE* message = nullptr;
    
    if (dbcHandler) {
        // Try to find the message for this frame ID
        // We need to create a temporary CANFrame to search
        CANFrame tempFrame;
        tempFrame.setFrameId(frameId);
        tempFrame.bus = bus;
        message = dbcHandler->findMessage(tempFrame);
    }
    
    if (message && message->sigHandler && message->sigHandler->getCount() > 0) {
        qDebug() << "  DBC message found:" << message->name << "with" << message->sigHandler->getCount() << "signals";
        
        // Show signal picker dialog in QML
        if (m_graphView) {
            // Pass the frame ID, bus, and signal list to QML
            QVariantList signalList;
            for (int i = 0; i < message->sigHandler->getCount(); i++) {
                DBC_SIGNAL* sig = message->sigHandler->findSignalByIdx(i);
                if (sig) {
                    QVariantMap signalInfo;
                    signalInfo["name"] = sig->name;
                    signalInfo["startBit"] = sig->startBit;
                    signalInfo["signalSize"] = sig->signalSize;
                    signalInfo["isLittleEndian"] = sig->intelByteOrder;
                    signalInfo["isSigned"] = sig->valType == DBC_SIG_VAL_TYPE::SIGNED_INT;
                    signalList.append(signalInfo);
                }
            }
            
            QMetaObject::invokeMethod(m_graphView, "showSignalPicker",
                Qt::AutoConnection,
                Q_ARG(QVariant, frameId),
                Q_ARG(QVariant, bus),
                Q_ARG(QVariant, message->name),
                Q_ARG(QVariant, signalList)
            );
        }
    } else {
        qDebug() << "  No DBC message found, graphing entire frame as single value";
        // No DBC available, just graph the whole frame
        graphController->addFrameSignal(frameId, bus);
        qDebug() << "  Frame added to graph successfully";
    }
}

void MainWindowMobileQML::handleAddSignalToGraph(uint32_t frameId, int bus, const QString& signalName)
{
    qDebug() << "=== handleAddSignalToGraph called ===";
    qDebug() << "  Frame ID: 0x" << QString::number(frameId, 16);
    qDebug() << "  Bus:" << bus;
    qDebug() << "  Signal name:" << signalName;
    
    if (!graphController) {
        qDebug() << "  ERROR: graphController is null!";
        return;
    }
    
    // Clear existing graph (single graph mode - replace on each add)
    qDebug() << "  Clearing existing signals...";
    graphController->clearAllSignals();
    
    // Check if DBC is available for this frame
    DBCHandler* dbcHandler = DBCHandler::getReference();
    DBC_MESSAGE* message = nullptr;
    
    if (dbcHandler) {
        // Try to find the message for this frame ID
        CANFrame tempFrame;
        tempFrame.setFrameId(frameId);
        tempFrame.bus = bus;
        message = dbcHandler->findMessage(tempFrame);
    }
    
    if (message && message->sigHandler && message->sigHandler->getCount() > 0) {
        qDebug() << "  DBC message found:" << message->name << "with" << message->sigHandler->getCount() << "signals";
        
        // Find the specific signal by name
        DBC_SIGNAL* targetSignal = nullptr;
        for (int i = 0; i < message->sigHandler->getCount(); i++) {
            DBC_SIGNAL* sig = message->sigHandler->findSignalByIdx(i);
            if (sig && sig->name == signalName) {
                targetSignal = sig;
                break;
            }
        }
        
        if (targetSignal) {
            qDebug() << "  Found signal:" << targetSignal->name;
            qDebug() << "  Adding signal to graph...";
            
            // Add the signal to the graph
            graphController->addSignal(
                frameId,
                bus,
                targetSignal->startBit,
                targetSignal->signalSize,
                targetSignal->valType == DBC_SIG_VAL_TYPE::SIGNED_INT,
                targetSignal->intelByteOrder,
                targetSignal->name
            );
            
            qDebug() << "  Signal added to graph successfully";
        } else {
            qDebug() << "  ERROR: Signal not found:" << signalName;
        }
    } else {
        qDebug() << "  ERROR: No DBC message found for frame ID 0x" << QString::number(frameId, 16);
    }
}

