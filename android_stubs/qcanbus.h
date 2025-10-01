#pragma once
#ifndef ANDROID_STUB_QCANBUS_H
#define ANDROID_STUB_QCANBUS_H

#include <QObject>
#include <QString>
#include <QStringList>
#include "qcanbusdevice.h"

class QCanBus : public QObject
{
    Q_OBJECT
    
public:
    static QCanBus* instance() {
        static QCanBus inst;
        return &inst;
    }
    
    QStringList plugins() const { return QStringList(); }
    
    QList<QCanBusDeviceInfo> availableDevices(const QString &plugin, QString *errorMessage = nullptr) const {
        Q_UNUSED(plugin); Q_UNUSED(errorMessage);
        return QList<QCanBusDeviceInfo>();
    }
    
    QCanBusDevice* createDevice(const QString &plugin, const QString &interfaceName, QString *errorMessage = nullptr) const {
        Q_UNUSED(plugin); Q_UNUSED(interfaceName); Q_UNUSED(errorMessage);
        return nullptr;
    }
    
private:
    explicit QCanBus(QObject *parent = nullptr) : QObject(parent) {}
    ~QCanBus() = default;
    Q_DISABLE_COPY(QCanBus)
};

#endif // ANDROID_STUB_QCANBUS_H