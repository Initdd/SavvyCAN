#pragma once
#ifndef ANDROID_STUB_QCANBUSDEVICE_H
#define ANDROID_STUB_QCANBUSDEVICE_H

#include <QObject>
#include <QString>
#include <QList>
#include <QVariant>
#include "qcanbusframe.h"

class QCanBusDeviceInfo
{
public:
    QCanBusDeviceInfo() {}
    QCanBusDeviceInfo(const QString &name) : m_name(name) {}
    
    QString name() const { return m_name; }
    QString description() const { return QString(); }
    QString serialNumber() const { return QString(); }
    QString alias() const { return QString(); }
    int channel() const { return 0; }
    bool hasFlexibleDataRate() const { return false; }
    bool isVirtual() const { return true; }
    
private:
    QString m_name;
};

class QCanBusDevice : public QObject
{
    Q_OBJECT
    
public:
    enum CanBusError {
        NoError,
        ReadError,
        WriteError,
        ConnectionError,
        ConfigurationError,
        UnknownError,
        OperationError,
        TimeoutError
    };
    Q_ENUM(CanBusError)
    
    enum CanBusDeviceState {
        UnconnectedState,
        ConnectingState,
        ConnectedState,
        ClosingState
    };
    Q_ENUM(CanBusDeviceState)
    
    enum ConfigurationKey {
        RawFilterKey = 0,
        ErrorFilterKey,
        LoopbackKey,
        ReceiveOwnKey,
        BitRateKey,
        CanFdKey,
        DataBitRateKey,
        ProtocolKey,
        UserKey = 30
    };
    Q_ENUM(ConfigurationKey)
    
    enum Direction {
        Input = 1,
        Output = 2,
        AllDirections = Input | Output
    };
    Q_DECLARE_FLAGS(Directions, Direction)
    Q_FLAG(Directions)
    
    explicit QCanBusDevice(QObject *parent = nullptr) : QObject(parent), m_state(UnconnectedState) {}
    virtual ~QCanBusDevice() {}
    
    virtual bool connectDevice() { return false; }
    virtual void disconnectDevice() {}
    
    CanBusDeviceState state() const { return m_state; }
    
    CanBusError error() const { return NoError; }
    QString errorString() const { return QString(); }
    
    virtual bool writeFrame(const QCanBusFrame &frame) { Q_UNUSED(frame); return false; }
    QCanBusFrame readFrame() { return QCanBusFrame(); }
    QList<QCanBusFrame> readAllFrames() { return QList<QCanBusFrame>(); }
    qint64 framesAvailable() const { return 0; }
    qint64 framesToWrite() const { return 0; }
    
    virtual bool waitForFramesReceived(int msecs) { Q_UNUSED(msecs); return false; }
    virtual bool waitForFramesWritten(int msecs) { Q_UNUSED(msecs); return false; }
    
    void setConfigurationParameter(ConfigurationKey key, const QVariant &value) {
        Q_UNUSED(key); Q_UNUSED(value);
    }
    QVariant configurationParameter(ConfigurationKey key) const {
        Q_UNUSED(key); return QVariant();
    }
    QList<ConfigurationKey> configurationKeys() const { return QList<ConfigurationKey>(); }
    
    virtual void resetController() {}
    virtual bool hasBusStatus() const { return false; }
    virtual CanBusDeviceState busStatus() const { return UnconnectedState; }
    
    void clear(Directions direction = Direction::AllDirections) { Q_UNUSED(direction); }
    
    virtual QString interpretErrorFrame(const QCanBusFrame &errorFrame) { 
        Q_UNUSED(errorFrame); return QString(); 
    }
    
signals:
    void errorOccurred(QCanBusDevice::CanBusError);
    void framesReceived();
    void framesWritten(qint64 framesCount);
    void stateChanged(QCanBusDevice::CanBusDeviceState state);
    
protected:
    void setState(CanBusDeviceState newState) {
        if (m_state != newState) {
            m_state = newState;
            emit stateChanged(newState);
        }
    }
    
    void setError(const QString &errorText, CanBusError errorId) {
        Q_UNUSED(errorText); Q_UNUSED(errorId);
    }
    
private:
    CanBusDeviceState m_state;
};

Q_DECLARE_OPERATORS_FOR_FLAGS(QCanBusDevice::Directions)

#endif // ANDROID_STUB_QCANBUSDEVICE_H