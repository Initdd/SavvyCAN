#pragma once
#ifndef ANDROID_STUB_QCANBUSFRAME_H
#define ANDROID_STUB_QCANBUSFRAME_H

#include <QObject>
#include <QByteArray>
#include <QString>

class QCanBusFrame
{
public:
    enum FrameType {
        UnknownFrame        = 0x0,
        DataFrame           = 0x1,
        ErrorFrame          = 0x2,
        RemoteRequestFrame  = 0x3,
        InvalidFrame        = 0x4
    };
    
    class TimeStamp
    {
    public:
        TimeStamp(qint64 sec = 0, qint64 usec = 0) : m_seconds(sec), m_microSeconds(usec) {}
        static TimeStamp fromMicroSeconds(qint64 usec) { return TimeStamp(usec / 1000000, usec % 1000000); }
        
        qint64 seconds() const { return m_seconds; }
        qint64 microSeconds() const { return m_microSeconds; }
        
    private:
        qint64 m_seconds;
        qint64 m_microSeconds;
    };
    
    QCanBusFrame(FrameType type = DataFrame) : m_frameType(type), m_frameId(0), m_hasExtended(false) {}
    QCanBusFrame(quint32 identifier, const QByteArray &data) : 
        m_frameType(DataFrame), m_frameId(identifier), m_hasExtended(false), m_payload(data) {}
    
    bool isValid() const { return m_frameType != InvalidFrame && m_frameType != UnknownFrame; }
    
    FrameType frameType() const { return m_frameType; }
    void setFrameType(FrameType type) { m_frameType = type; }
    
    quint32 frameId() const { return m_frameId; }
    void setFrameId(quint32 newFrameId) { m_frameId = newFrameId; }
    
    QByteArray payload() const { return m_payload; }
    void setPayload(const QByteArray &data) { m_payload = data; }
    
    bool hasExtendedFrameFormat() const { return m_hasExtended; }
    void setExtendedFrameFormat(bool isExtended) { m_hasExtended = isExtended; }
    
    TimeStamp timeStamp() const { return m_timeStamp; }
    void setTimeStamp(const TimeStamp &ts) { m_timeStamp = ts; }
    
    QString toString() const { return QString("CanBusFrame(ID: %1)").arg(m_frameId); }
    
    // Error handling - stub methods
    enum FrameError {
        NoError = 0,
        TransmissionTimeoutError = 1,
        LostArbitrationError = 2,
        ControllerError = 4,
        ProtocolViolationError = 8,
        TransceiverError = 16,
        MissingAcknowledgmentError = 32,
        BusOffError = 64,
        BusError = 128,
        ControllerRestartError = 256,
        UnknownError = 512,
        AnyError = 0x1FFFFFFF
    };
    Q_DECLARE_FLAGS(FrameErrors, FrameError)
    
    FrameErrors error() const { return NoError; }
    void setError(FrameErrors error) { Q_UNUSED(error); }
    
    // Flexible Data Rate (CAN FD) support - stub methods
    bool hasFlexibleDataRateFormat() const { return false; }
    void setFlexibleDataRateFormat(bool isFlexibleData) { Q_UNUSED(isFlexibleData); }
    
    bool hasBitrateSwitch() const { return false; }
    void setBitrateSwitch(bool bitrateSwitch) { Q_UNUSED(bitrateSwitch); }
    
    // Additional methods for compatibility
    QByteArray readAll() const { return m_payload; }
    bool hasLocalEcho() const { return false; }
    
private:
    FrameType m_frameType;
    quint32 m_frameId;
    bool m_hasExtended;
    QByteArray m_payload;
    TimeStamp m_timeStamp;
};

Q_DECLARE_METATYPE(QCanBusFrame::FrameType)

#endif // ANDROID_STUB_QCANBUSFRAME_H