#pragma once
#ifndef ANDROID_STUB_QSERIALPORT_H
#define ANDROID_STUB_QSERIALPORT_H

#include <QObject>
#include <QIODevice>
#include <QString>

class QSerialPortInfo
{
public:
    QSerialPortInfo() {}
    QSerialPortInfo(const QString &name) : m_name(name) {}
    QString portName() const { return m_name; }
    QString description() const { return QString(); }
    QString manufacturer() const { return QString(); }
    bool isNull() const { return m_name.isEmpty(); }
    
    static QList<QSerialPortInfo> availablePorts() { return QList<QSerialPortInfo>(); }
    
private:
    QString m_name;
};

class QSerialPort : public QObject
{
    Q_OBJECT
    
public:
    enum SerialPortError {
        NoError,
        DeviceNotFoundError,
        PermissionError,
        OpenError,
        NotOpenError,
        ParityError,
        FramingError,
        BreakConditionError,
        WriteError,
        ReadError,
        ResourceError,
        UnsupportedOperationError,
        TimeoutError,
        UnknownError
    };
    Q_ENUM(SerialPortError)
    
    enum BaudRate {
        Baud1200 = 1200,
        Baud2400 = 2400,
        Baud4800 = 4800,
        Baud9600 = 9600,
        Baud19200 = 19200,
        Baud38400 = 38400,
        Baud57600 = 57600,
        Baud115200 = 115200
    };
    Q_ENUM(BaudRate)
    
    enum DataBits {
        Data5 = 5,
        Data6 = 6,
        Data7 = 7,
        Data8 = 8,
        UnknownDataBits = -1
    };
    Q_ENUM(DataBits)
    
    enum Parity {
        NoParity = 0,
        EvenParity = 2,
        OddParity = 3,
        SpaceParity = 4,
        MarkParity = 5,
        UnknownParity = -1
    };
    Q_ENUM(Parity)
    
    enum StopBits {
        OneStop = 1,
        OneAndHalfStop = 3,
        TwoStop = 2,
        UnknownStopBits = -1
    };
    Q_ENUM(StopBits)
    
    enum FlowControl {
        NoFlowControl,
        HardwareControl,
        SoftwareControl,
        UnknownFlowControl = -1
    };
    Q_ENUM(FlowControl)
    
    enum PinoutSignal {
        TransmittedDataSignal = 1,
        ReceivedDataSignal = 2,
        DataTerminalReadySignal = 4,
        DataCarrierDetectSignal = 8,
        DataSetReadySignal = 16,
        RingIndicatorSignal = 32,
        RequestToSendSignal = 64,
        ClearToSendSignal = 128,
        SecondaryTransmittedDataSignal = 256,
        SecondaryReceivedDataSignal = 512
    };
    Q_DECLARE_FLAGS(PinoutSignals, PinoutSignal)
    Q_FLAG(PinoutSignals)
    
    explicit QSerialPort(QObject *parent = nullptr) : QObject(parent) {}
    explicit QSerialPort(const QString &name, QObject *parent = nullptr) : QObject(parent), m_portName(name) {}
    explicit QSerialPort(const QSerialPortInfo &info, QObject *parent = nullptr) : QObject(parent), m_portName(info.portName()) {}
    virtual ~QSerialPort() {}
    
    void setPortName(const QString &name) { m_portName = name; }
    QString portName() const { return m_portName; }
    
    bool open(QIODevice::OpenMode mode) { Q_UNUSED(mode); return false; }
    void close() {}
    bool isOpen() const { return false; }
    
    bool setBaudRate(qint32 baudRate, QIODevice::OpenModeFlag directions = QIODevice::ReadWrite) {
        Q_UNUSED(baudRate); Q_UNUSED(directions); return false;
    }
    qint32 baudRate(QIODevice::OpenModeFlag directions = QIODevice::ReadWrite) const {
        Q_UNUSED(directions); return 0;
    }
    
    bool setDataBits(DataBits dataBits) { Q_UNUSED(dataBits); return false; }
    DataBits dataBits() const { return UnknownDataBits; }
    
    bool setParity(Parity parity) { Q_UNUSED(parity); return false; }
    Parity parity() const { return UnknownParity; }
    
    bool setStopBits(StopBits stopBits) { Q_UNUSED(stopBits); return false; }
    StopBits stopBits() const { return UnknownStopBits; }
    
    bool setFlowControl(FlowControl flowControl) { Q_UNUSED(flowControl); return false; }
    FlowControl flowControl() const { return UnknownFlowControl; }
    
    bool setDataTerminalReady(bool set) { Q_UNUSED(set); return false; }
    bool isDataTerminalReady() { return false; }
    
    bool setRequestToSend(bool set) { Q_UNUSED(set); return false; }
    bool isRequestToSend() { return false; }
    
    PinoutSignals pinoutSignals() { return PinoutSignals(); }
    
    bool flush() { return false; }
    bool clear(QIODevice::OpenModeFlag directions = QIODevice::ReadWrite) { Q_UNUSED(directions); return false; }
    bool atEnd() const { return true; }
    
    SerialPortError error() const { return NoError; }
    void clearError() {}
    
    qint64 readBufferSize() const { return 0; }
    void setReadBufferSize(qint64 size) { Q_UNUSED(size); }
    
    qint64 bytesAvailable() const { return 0; }
    qint64 bytesToWrite() const { return 0; }
    bool canReadLine() const { return false; }
    
    bool waitForReadyRead(int msecs) { Q_UNUSED(msecs); return false; }
    bool waitForBytesWritten(int msecs) { Q_UNUSED(msecs); return false; }
    
    qint64 readData(char *data, qint64 maxSize) { Q_UNUSED(data); Q_UNUSED(maxSize); return -1; }
    qint64 writeData(const char *data, qint64 maxSize) { Q_UNUSED(data); Q_UNUSED(maxSize); return -1; }
    
    // Additional methods for compatibility
    qint64 write(const QByteArray &data) { Q_UNUSED(data); return -1; }
    QByteArray readAll() { return QByteArray(); }
    
signals:
    void baudRateChanged(qint32 baudRate, QIODevice::OpenModeFlag directions);
    void dataBitsChanged(DataBits dataBits);
    void parityChanged(Parity parity);
    void stopBitsChanged(StopBits stopBits);
    void flowControlChanged(FlowControl flowControl);
    void dataTerminalReadyChanged(bool set);
    void requestToSendChanged(bool set);
    void error(SerialPortError serialPortError);
    void settingsRestoredOnCloseChanged(bool restore);
    void breakEnabledChanged(bool set);
    
private:
    QString m_portName;
};

Q_DECLARE_OPERATORS_FOR_FLAGS(QSerialPort::PinoutSignals)

#endif // ANDROID_STUB_QSERIALPORT_H