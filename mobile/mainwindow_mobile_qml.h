#ifndef MAINWINDOW_MOBILE_QML_H
#define MAINWINDOW_MOBILE_QML_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>
#include <QElapsedTimer>
#include <QUdpSocket>
#include "can_structs.h"
#include "can_trigger_structs.h"
#include "connections/canconmanager.h"
#include "connections/canconnection.h"
#include "canframemodel.h"

// Forward declarations
class GraphController;

class MainWindowMobileQML : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString statusText READ statusText WRITE setStatusText NOTIFY statusTextChanged)
    Q_PROPERTY(int frameCount READ frameCount WRITE setFrameCount NOTIFY frameCountChanged)

public:
    explicit MainWindowMobileQML(QQmlApplicationEngine *engine, QObject *parent = nullptr);
    ~MainWindowMobileQML();

    void handleDroppedFile(const QString &filename);
    
    // Desktop compatibility methods (needed by some components even on mobile)
    static MainWindowMobileQML* getReference();
    CANFrameModel* getCANFrameModel();
    
    // Property getters
    QString statusText() const { return m_statusText; }
    int frameCount() const { return m_frameCount; }
    
    // Initialize QML connections after QML is loaded
    void connectQMLSignals();

signals:
    void framesUpdated(int numFrames);
    void statusTextChanged();
    void frameCountChanged();

public slots:
    // Property setters
    void setStatusText(const QString &text);
    void setFrameCount(int count);
    
    // Frames tab
    void clearFrames();
    void handleOverwriteChanged(bool checked);
    void handleInterpretChanged(bool checked);
    
    // Connections tab
    void handleNewConn();
    void handleCreateConnection(const QString &type, const QString &host, const QString &port, 
                               const QString &device, int baudRate, int canSpeed);
    void handleRemoveConn();
    void handleResetConn();
    void handleSaveBus();
    void handleConnectionSelection(int row);
    void handleScanSerialPorts();
    void handleConnectionDialogOpened();
    void handleConnectionDialogClosed();
    
    // Sender tab
    void handleEnableAll();
    void handleDisableAll();
    void handleClearGrid();
    void handleAddSender();
    void handleSenderCellChange(int row, int col, const QString &value);
    void handleSenderTick();
    void handleDBCModeChanged(bool dbcMode);
    void handleRequestDBCMessages();
    void handleRequestDBCSignals(const QString &messageName);
    
    // DBC Manager tab
    void handleLoadDBCFile(const QString &filePath);
    void handleRemoveDBCFile(int index);
    void handleRefreshDBCList();
    
    // Graph tab
    void handleAddFrameToGraph(uint32_t frameId, int bus);
    void handleAddSignalToGraph(uint32_t frameId, int bus, const QString& signalName);
    
    // CAN connection events
    void connectionStatusUpdated(int connNum);
    void framesReceived(CANConnection* conn, QVector<CANFrame>& frames);
    void readPendingDatagrams();
    void tickGUIUpdate();

private:
    void setupConnections();
    void updateStatus();
    void updateConnectionsList();
    void updateDeviceList();
    void logReceivedFrame(const CANFrame& frame);
    void getBusSettings(int bus, CANBus& busSettings);
    void updateDBCFileList();
    void updateInterpretCheckboxState();
    
    QQmlApplicationEngine *m_engine;
    QObject *m_rootObject;
    QObject *m_framesView;
    QObject *m_connectionsView;
    QObject *m_senderView;
    QObject *m_dbcManagerView;
    QObject *m_graphView;
    
    CANFrameModel *frameModel;
    CANConManager *canManager;
    GraphController *graphController;
    
    // Timers
    QTimer *senderTimer;
    QTimer *updateTimer;
    QTimer *m_connectionUpdateTimer;  // Timer to batch connection status updates
    
    // Sender state
    QVector<FrameSendData> sendingData;
    QElapsedTimer sendingElapsed;
    quint64 sendingLastTimeStamp;
    
    // UDP broadcast receivers for device discovery
    QUdpSocket *rxBroadcastGVRET;
    QUdpSocket *rxBroadcastKayak;
    QStringList remoteDeviceIPGVRET;
    QStringList remoteDeviceKayak;
    
    // Properties
    QString m_statusText;
    int m_frameCount;
    int m_selectedConnectionIndex;
    bool m_connectionDialogOpen;
    
    // Track last timestamp for each frame ID+bus (for timedelta calculation)
    QHash<uint64_t, uint64_t> lastFrameTimestamp; // key: (frameId | (bus << 29)), value: timestamp in microseconds
    
    // DBC loading state to prevent concurrent loads
    bool m_isLoadingDBC;
    QStringList m_dbcLoadQueue;
    
    // Singleton reference
    static MainWindowMobileQML *selfRef;
};

#endif // MAINWINDOW_MOBILE_QML_H
