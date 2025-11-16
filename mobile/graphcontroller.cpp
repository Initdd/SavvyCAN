#include "graphcontroller.h"
#include <QDebug>
#include <QtMath>

#define GRAPH_SIGNAL_MAX_POINTS 5000

GraphController::GraphController(QObject *parent)
    : QObject(parent)
    , m_nextColorIndex(0)
    , m_baseTimestamp(0)
    , m_hasBaseTimestamp(false)
{
    initColorPalette();
}

GraphController::~GraphController()
{
}

void GraphController::initColorPalette()
{
    // Nice vibrant colors for graphing
    m_colorPalette = {
        QColor("#2196F3"), // Blue
        QColor("#F44336"), // Red
        QColor("#4CAF50"), // Green
        QColor("#FF9800"), // Orange
        QColor("#9C27B0"), // Purple
        QColor("#00BCD4"), // Cyan
        QColor("#FFEB3B"), // Yellow
        QColor("#E91E63"), // Pink
        QColor("#009688"), // Teal
        QColor("#FF5722"), // Deep Orange
    };
}

QColor GraphController::getNextColor()
{
    QColor color = m_colorPalette[m_nextColorIndex];
    m_nextColorIndex = (m_nextColorIndex + 1) % m_colorPalette.size();
    return color;
}

void GraphController::addFrameSignal(uint32_t frameId, int bus)
{
    // Simple version: graph entire frame data as a single concatenated value
    // This is useful for quick visualization
    QString name = QString("0x%1 (Bus %2)").arg(frameId, 0, 16).arg(bus);
    
    GraphSignal signal;
    signal.frameId = frameId;
    signal.bus = bus;
    signal.startBit = 0;
    signal.numBits = 64; // Max CAN frame data
    signal.isSigned = false;
    signal.isLittleEndian = true;
    signal.name = name;
    signal.color = getNextColor();
    signal.minValue = 0;
    signal.maxValue = 255;
    
    m_signals.append(signal);
    
    qDebug() << "GraphController::addFrameSignal - Added:" << name;
    qDebug() << "  Total signals now:" << m_signals.count();
    qDebug() << "  Emitting signalCountChanged...";
    
    emit signalCountChanged();
    
    qDebug() << "  Emitting signalAdded(" << (m_signals.count() - 1) << ")...";
    emit signalAdded(m_signals.count() - 1);
    
    qDebug() << "  Done adding signal";
}

void GraphController::addSignal(uint32_t frameId, int bus, int startBit, int numBits,
                                bool isSigned, bool isLittleEndian, const QString &name)
{
    GraphSignal signal;
    signal.frameId = frameId;
    signal.bus = bus;
    signal.startBit = startBit;
    signal.numBits = numBits;
    signal.isSigned = isSigned;
    signal.isLittleEndian = isLittleEndian;
    signal.name = name;
    signal.color = getNextColor();
    
    // Calculate min/max based on bit width and signedness
    if (isSigned) {
        signal.minValue = -(1 << (numBits - 1));
        signal.maxValue = (1 << (numBits - 1)) - 1;
    } else {
        signal.minValue = 0;
        signal.maxValue = (1 << numBits) - 1;
    }
    
    m_signals.append(signal);
    
    qDebug() << "Added signal:" << name << "ID:" << QString::number(frameId, 16)
             << "Bits:" << startBit << "-" << (startBit + numBits - 1);
    
    emit signalCountChanged();
    emit signalAdded(m_signals.count() - 1);
}

void GraphController::removeSignal(int index)
{
    if (index >= 0 && index < m_signals.count()) {
        qDebug() << "Removing signal:" << m_signals[index].name;
        m_signals.removeAt(index);
        emit signalCountChanged();
        emit signalRemoved(index);
        emit rangesChanged();
    }
}

void GraphController::clearAllSignals()
{
    qDebug() << "Clearing all signals";
    m_signals.clear();
    m_hasBaseTimestamp = false;
    m_nextColorIndex = 0;
    emit signalCountChanged();
    emit dataUpdated();
}

QString GraphController::getSignalName(int index) const
{
    if (index >= 0 && index < m_signals.count()) {
        return m_signals[index].name;
    }
    return QString();
}

QColor GraphController::getSignalColor(int index) const
{
    if (index >= 0 && index < m_signals.count()) {
        return m_signals[index].color;
    }
    return QColor(Qt::gray);
}

QVector<QPointF> GraphController::getSignalData(int index) const
{
    if (index >= 0 && index < m_signals.count()) {
        return m_signals[index].dataPoints;
    }
    return QVector<QPointF>();
}

QVariantList GraphController::getSignalDataVariant(int index) const
{
    QVariantList result;
    
    if (index >= 0 && index < m_signals.count()) {
        const QVector<QPointF> &points = m_signals[index].dataPoints;
        for (const QPointF &point : points) {
            QVariantMap pointMap;
            pointMap["x"] = point.x();
            pointMap["y"] = point.y();
            result.append(pointMap);
        }
    }
    
    return result;
}

void GraphController::getValueRange(double &minVal, double &maxVal) const
{
    if (m_signals.isEmpty()) {
        minVal = 0;
        maxVal = 255;
        return;
    }
    
    minVal = m_signals[0].minValue;
    maxVal = m_signals[0].maxValue;
    
    for (const GraphSignal &signal : m_signals) {
        minVal = qMin(minVal, signal.minValue);
        maxVal = qMax(maxVal, signal.maxValue);
    }
    
    // Add 10% padding
    double range = maxVal - minVal;
    minVal -= range * 0.1;
    maxVal += range * 0.1;
}

void GraphController::getTimeRange(double &minTime, double &maxTime) const
{
    minTime = 0;
    maxTime = 10; // Default 10 second window
    
    if (m_signals.isEmpty()) {
        return;
    }
    
    // Find the actual time range from data
    bool first = true;
    for (const GraphSignal &signal : m_signals) {
        if (!signal.dataPoints.isEmpty()) {
            double sigMin = signal.dataPoints.first().x();
            double sigMax = signal.dataPoints.last().x();
            
            if (first) {
                minTime = sigMin;
                maxTime = sigMax;
                first = false;
            } else {
                minTime = qMin(minTime, sigMin);
                maxTime = qMax(maxTime, sigMax);
            }
        }
    }
    
    // Ensure at least 1 second range
    if (maxTime - minTime < 1.0) {
        maxTime = minTime + 10.0;
    }
}

QVariantMap GraphController::getValueRangeMap() const
{
    double minVal, maxVal;
    getValueRange(minVal, maxVal);
    
    QVariantMap result;
    result["min"] = minVal;
    result["max"] = maxVal;
    return result;
}

QVariantMap GraphController::getTimeRangeMap() const
{
    double minTime, maxTime;
    getTimeRange(minTime, maxTime);
    
    QVariantMap result;
    result["min"] = minTime;
    result["max"] = maxTime;
    return result;
}

double GraphController::extractValue(const CANFrame &frame, const GraphSignal &signal) const
{
    // Get payload data
    QByteArray payload = frame.payload();
    
    // For simple frame signal (numBits == 64), just use first byte as value
    if (signal.numBits == 64) {
        if (payload.length() > 0) {
            return (uint8_t)payload[0];
        }
        return 0;
    }
    
    // Extract specific bits from frame
    // This is a simplified version - a full implementation would handle
    // endianness and bit extraction properly
    
    int byteIdx = signal.startBit / 8;
    int bitOffset = signal.startBit % 8;
    
    if (byteIdx >= payload.length()) {
        return 0;
    }
    
    // Simple extraction for byte-aligned data
    if (signal.numBits <= 8 && bitOffset == 0) {
        uint8_t rawValue = (uint8_t)payload[byteIdx];
        
        // Mask to get only the bits we want
        uint8_t mask = (1 << signal.numBits) - 1;
        rawValue &= mask;
        
        if (signal.isSigned && (rawValue & (1 << (signal.numBits - 1)))) {
            // Sign extend
            return (double)((int8_t)(rawValue | (~mask)));
        }
        
        return (double)rawValue;
    }
    
    // For multi-byte values, need more complex extraction
    // This is simplified - real implementation would handle Intel/Motorola byte order
    uint64_t rawValue = 0;
    int bytesToRead = (signal.numBits + 7) / 8;
    
    for (int i = 0; i < bytesToRead && (byteIdx + i) < payload.length(); i++) {
        if (signal.isLittleEndian) {
            rawValue |= ((uint64_t)(uint8_t)payload[byteIdx + i]) << (i * 8);
        } else {
            rawValue = (rawValue << 8) | (uint8_t)payload[byteIdx + i];
        }
    }
    
    // Apply bit offset
    rawValue >>= bitOffset;
    
    // Mask to signal width
    uint64_t mask = (signal.numBits >= 64) ? ~0ULL : ((1ULL << signal.numBits) - 1);
    rawValue &= mask;
    
    // Handle signed values
    if (signal.isSigned && (rawValue & (1ULL << (signal.numBits - 1)))) {
        // Sign extend
        rawValue |= ~mask;
        return (double)((int64_t)rawValue);
    }
    
    return (double)rawValue;
}

void GraphController::processFrame(const CANFrame &frame)
{
    bool updated = false;
    
    // Set base timestamp on first frame
    if (!m_hasBaseTimestamp) {
        m_baseTimestamp = frame.timeStamp().microSeconds() / 1000000.0; // Convert to seconds
        m_hasBaseTimestamp = true;
    }
    
    double relativeTime = (frame.timeStamp().microSeconds() / 1000000.0) - m_baseTimestamp;
    
    // Update all signals that match this frame
    for (int i = 0; i < m_signals.count(); i++) {
        GraphSignal &signal = m_signals[i];
        
        // Check if this frame matches this signal
        if (signal.frameId == frame.frameId() && 
            (signal.bus == -1 || signal.bus == frame.bus)) {
            
            // Extract value from frame
            double value = extractValue(frame, signal);
            
            // Add data point
            signal.dataPoints.append(QPointF(relativeTime, value));
            
                // Limit data points to prevent memory issues (keep last GRAPH_SIGNAL_MAX_POINTS points)
                if (signal.dataPoints.size() > GRAPH_SIGNAL_MAX_POINTS) {
                    signal.dataPoints.remove(0, signal.dataPoints.size() - GRAPH_SIGNAL_MAX_POINTS);
            }
            
            // Update min/max if needed
            if (value < signal.minValue) signal.minValue = value;
            if (value > signal.maxValue) signal.maxValue = value;
            
            updated = true;
        }
    }
    
    if (updated) {
        emit dataUpdated();
        emit rangesChanged();
    }
}
