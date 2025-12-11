#include "graphcontroller.h"
#include <QDebug>
#include <QtMath>

#define GRAPH_SIGNAL_MAX_POINTS 5000

GraphController::GraphController(QObject *parent)
    : QObject(parent), m_signal(nullptr), m_nextColorIndex(0), m_baseTimestamp(0), m_hasBaseTimestamp(false), m_newDataAvailable(false)
{
    initColorPalette();

    // Setup timer based on target FPS
    connect(&m_updateTimer, &QTimer::timeout, this, &GraphController::onTimerTimeout);
    m_updateTimer.start(1000 / TARGET_FPS);
}

GraphController::~GraphController()
{
    if (m_signal)
        delete m_signal;
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

    // Overwrite the current signal
    if (m_signal)
        delete m_signal;
    m_signal = new GraphSignal();
    m_signal->frameId = frameId;
    m_signal->bus = bus;
    m_signal->startBit = 0;
    m_signal->numBits = 64;
    m_signal->isSigned = false;
    m_signal->isLittleEndian = true;
    m_signal->name = name;
    m_signal->color = getNextColor();
    m_signal->minValue = 0;
    m_signal->maxValue = 255;

    emit signalChanged();
}

void GraphController::addSignal(uint32_t frameId, int bus, int startBit, int numBits,
                                bool isSigned, bool isLittleEndian, const QString &name,
                                double min, double max)
{
    if (m_signal)
        delete m_signal;
    m_signal = new GraphSignal();
    m_signal->frameId = frameId;
    m_signal->bus = bus;
    m_signal->startBit = startBit;
    m_signal->numBits = numBits;
    m_signal->isSigned = isSigned;
    m_signal->isLittleEndian = isLittleEndian;
    m_signal->name = name;
    m_signal->color = getNextColor();

    // Use provided min/max if they look valid (not equal)
    if (qAbs(max - min) > 0.000001)
    {
        m_signal->minValue = min;
        m_signal->maxValue = max;
    }
    else
    {
        // Calculate min/max based on bit width and signedness
        if (isSigned)
        {
            m_signal->minValue = -(1 << (numBits - 1));
            m_signal->maxValue = (1 << (numBits - 1)) - 1;
        }
        else
        {
            m_signal->minValue = 0;
            m_signal->maxValue = (1 << numBits) - 1;
        }
    }

    emit signalChanged();
}

void GraphController::removeSignal()
{
    if (m_signal)
    {
        delete m_signal;
        m_signal = nullptr;
        emit signalChanged();
    }
}

QString GraphController::getSignalName() const
{
    if (m_signal)
    {
        return m_signal->name;
    }
    return QString();
}

QColor GraphController::getSignalColor() const
{
    if (m_signal)
    {
        return m_signal->color;
    }
    return QColor();
}

QVector<QPointF> GraphController::getSignalData() const
{
    if (m_signal)
    {
        return m_signal->dataPoints;
    }
    return QVector<QPointF>();
}

void GraphController::updateSeries(QAbstractSeries *series)
{
    if (!series || !m_signal)
        return;

    // Cast to XYSeries
    QXYSeries *xySeries = qobject_cast<QXYSeries *>(series);

    if (xySeries)
    {
        // Replace the internal data of the series directly with the QVector.
        xySeries->replace(m_signal->dataPoints);
    }
}

void GraphController::getValueRange(double &minVal, double &maxVal) const
{
    minVal = 0;
    maxVal = 255;

    if (m_signal)
    {
        minVal = m_signal->minValue;
        maxVal = m_signal->maxValue;
    }
}

void GraphController::getTimeRange(double &minTime, double &maxTime) const
{
    minTime = 0;
    maxTime = 10; // Default 10 second window

    if (m_signal && !m_signal->dataPoints.isEmpty())
    {
        minTime = m_signal->dataPoints.first().x();
        maxTime = m_signal->dataPoints.last().x();
    }

    // Ensure at least small range if min == max
    if (qAbs(maxTime - minTime) < 0.001)
    {
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
    if (signal.numBits == 64)
    {
        if (payload.length() > 0)
        {
            return (uint8_t)payload[0];
        }
        return 0;
    }

    // Extract specific bits from frame
    // This is a simplified version - a full implementation would handle
    // endianness and bit extraction properly

    int byteIdx = signal.startBit / 8;
    int bitOffset = signal.startBit % 8;

    if (byteIdx >= payload.length())
    {
        return 0;
    }

    // Simple extraction for byte-aligned data
    if (signal.numBits <= 8 && bitOffset == 0)
    {
        uint8_t rawValue = (uint8_t)payload[byteIdx];

        // Mask to get only the bits we want
        uint8_t mask = (1 << signal.numBits) - 1;
        rawValue &= mask;

        if (signal.isSigned && (rawValue & (1 << (signal.numBits - 1))))
        {
            // Sign extend
            return (double)((int8_t)(rawValue | (~mask)));
        }

        return (double)rawValue;
    }

    // For multi-byte values, need more complex extraction
    // This is simplified - real implementation would handle Intel/Motorola byte order
    uint64_t rawValue = 0;
    int bytesToRead = (signal.numBits + 7) / 8;

    for (int i = 0; i < bytesToRead && (byteIdx + i) < payload.length(); i++)
    {
        if (signal.isLittleEndian)
        {
            rawValue |= ((uint64_t)(uint8_t)payload[byteIdx + i]) << (i * 8);
        }
        else
        {
            rawValue = (rawValue << 8) | (uint8_t)payload[byteIdx + i];
        }
    }

    // Apply bit offset
    rawValue >>= bitOffset;

    // Mask to signal width
    uint64_t mask = (signal.numBits >= 64) ? ~0ULL : ((1ULL << signal.numBits) - 1);
    rawValue &= mask;

    // Handle signed values
    if (signal.isSigned && (rawValue & (1ULL << (signal.numBits - 1))))
    {
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
    if (!m_hasBaseTimestamp)
    {
        m_baseTimestamp = frame.timeStamp().microSeconds() / 1000000.0; // Convert to seconds
        m_hasBaseTimestamp = true;
    }

    double relativeTime = (frame.timeStamp().microSeconds() / 1000000.0) - m_baseTimestamp;

    // Update signal if it matches this frame
    if (m_signal)
    {
        // Check if this frame matches this signal
        if (m_signal->frameId == frame.frameId() &&
            (m_signal->bus == -1 || m_signal->bus == frame.bus))
        {

            // Extract value from frame
            double value = extractValue(frame, *m_signal);

            // Add data point
            m_signal->dataPoints.append(QPointF(relativeTime, value));

            // Limit data points to prevent memory issues (keep last GRAPH_SIGNAL_MAX_POINTS points)
            // Optimization: Remove in chunks to avoid O(N) shift every frame
            if (m_signal->dataPoints.size() > GRAPH_SIGNAL_MAX_POINTS + 100)
            {
                m_signal->dataPoints.remove(0, 100);
            }

            // Update min/max if needed
            if (value < m_signal->minValue)
                m_signal->minValue = value;
            if (value > m_signal->maxValue)
                m_signal->maxValue = value;

            updated = true;
        }
    }

    if (updated)
    {
        m_newDataAvailable = true;
    }
}

void GraphController::onTimerTimeout()
{
    if (m_newDataAvailable)
    {
        emit dataUpdated();
        emit rangesChanged();
        m_newDataAvailable = false;
    }
}
