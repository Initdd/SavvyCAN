#ifndef GRAPHCONTROLLER_H
#define GRAPHCONTROLLER_H

#include <QObject>
#include <QAbstractListModel>
#include <QColor>
#include <QVector>
#include <QPointF>
#include <QtCharts>
#include <QTimer>
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
    
public:
    static const int TARGET_FPS = 20;

    explicit GraphController(QObject *parent = nullptr);
    ~GraphController();
    
    // Add a signal to graph (simple version - whole frame as single value)
    Q_INVOKABLE void addFrameSignal(uint32_t frameId, int bus);
    // Add a specific bit range from a frame
    Q_INVOKABLE void addSignal(uint32_t frameId, int bus, int startBit, int numBits, 
                               bool isSigned, bool isLittleEndian, const QString &name,
                               double min = 0.0, double max = 0.0);
    
    // Remove the signal
    Q_INVOKABLE void removeSignal();
    
    // Get signal info for QML
    Q_INVOKABLE QString getSignalName() const;
    Q_INVOKABLE QColor getSignalColor() const;
    Q_INVOKABLE bool signalDefined() const { return m_signal != nullptr; }
    
    // Process incoming CAN frame and update graphs
    void processFrame(const CANFrame &frame);
    
    // Get data for a specific signal (for QtCharts)
    QVector<QPointF> getSignalData() const;
    Q_INVOKABLE void updateSeries(QAbstractSeries *series);
    
    // Get min/max for auto-ranging
    void getValueRange(double &minVal, double &maxVal) const;
    void getTimeRange(double &minTime, double &maxTime) const;
    Q_INVOKABLE QVariantMap getValueRangeMap() const;
    Q_INVOKABLE QVariantMap getTimeRangeMap() const;

signals:
    void signalChanged();
    void dataUpdated();
    void rangesChanged();
    
private:
    // Extract value from CAN frame data
    double extractValue(const CANFrame &frame, const GraphSignal &signal) const;
    
    // Get next color from palette
    QColor getNextColor();
    
    // Initialize color palette
    void initColorPalette();

private slots:
    void onTimerTimeout();

private:
    GraphSignal* m_signal;
    QVector<QColor> m_colorPalette;
    int m_nextColorIndex;
    double m_baseTimestamp;
    bool m_hasBaseTimestamp;
    
    QTimer m_updateTimer;
    bool m_newDataAvailable;
};

#endif // GRAPHCONTROLLER_H
