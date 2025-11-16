#ifndef GRAPHCONTROLLER_H
#define GRAPHCONTROLLER_H

#include <QObject>
#include <QAbstractListModel>
#include <QColor>
#include <QVector>
#include <QPointF>
#include "can_structs.h"

// Represents a single signal being graphed
struct GraphSignal {
    uint32_t frameId;
    int bus;
    int startBit;
    int numBits;
    bool isSigned;
    bool isLittleEndian;
    QString name;
    QColor color;
    QVector<QPointF> dataPoints; // x=timestamp, y=value
    double minValue;
    double maxValue;
    
    GraphSignal() : frameId(0), bus(0), startBit(0), numBits(8), 
                    isSigned(false), isLittleEndian(true),
                    minValue(0), maxValue(255) {}
};

class GraphController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int signalCount READ signalCount NOTIFY signalCountChanged)
    
public:
    explicit GraphController(QObject *parent = nullptr);
    ~GraphController();
    
    // Add a signal to graph (simple version - whole frame as single value)
    Q_INVOKABLE void addFrameSignal(uint32_t frameId, int bus);
    
    // Add a specific bit range from a frame
    Q_INVOKABLE void addSignal(uint32_t frameId, int bus, int startBit, int numBits, 
                               bool isSigned, bool isLittleEndian, const QString &name);
    
    // Remove a signal by index
    Q_INVOKABLE void removeSignal(int index);
    
    // Clear all signals
    Q_INVOKABLE void clearAllSignals();
    
    // Get signal info for QML
    Q_INVOKABLE QString getSignalName(int index) const;
    Q_INVOKABLE QColor getSignalColor(int index) const;
    Q_INVOKABLE int signalCount() const { return m_signals.count(); }
    
    // Process incoming CAN frame and update graphs
    void processFrame(const CANFrame &frame);
    
    // Get data for a specific signal (for QtCharts)
    QVector<QPointF> getSignalData(int index) const;
    Q_INVOKABLE QVariantList getSignalDataVariant(int index) const;
    
    // Get min/max for auto-ranging
    void getValueRange(double &minVal, double &maxVal) const;
    void getTimeRange(double &minTime, double &maxTime) const;
    Q_INVOKABLE QVariantMap getValueRangeMap() const;
    Q_INVOKABLE QVariantMap getTimeRangeMap() const;

signals:
    void signalCountChanged();
    void signalAdded(int index);
    void signalRemoved(int index);
    void dataUpdated();
    void rangesChanged();
    
private:
    QList<GraphSignal> m_signals;
    QVector<QColor> m_colorPalette;
    int m_nextColorIndex;
    double m_baseTimestamp;
    bool m_hasBaseTimestamp;
    
    // Extract value from CAN frame data
    double extractValue(const CANFrame &frame, const GraphSignal &signal) const;
    
    // Get next color from palette
    QColor getNextColor();
    
    // Initialize color palette
    void initColorPalette();
};

#endif // GRAPHCONTROLLER_H
