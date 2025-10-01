# SavvyCAN Android Port - Implementation Guide

## Overview
This document outlines what has been set up and what still needs to be implemented to make SavvyCAN fully functional on Android.

## What's Already Configured ✅

### 1. Build System
- **Android configuration in SavvyCAN.pro**
  - Android platform detection
  - Qt AndroidExtras module included
  - OpenGL ES configuration for Android
  - Android package source directory setup
  - SDK version configuration (min: 26, target: 33)

### 2. Android Manifest & Permissions
- **Full AndroidManifest.xml created** with:
  - USB Host permissions and features
  - Bluetooth permissions (classic and BLE)
  - Network permissions (for SocketCAN, MQTT)
  - Storage permissions (for log files, DBC files)
  - Wake lock (for continuous logging)
  - USB device intent filters

### 3. Resource Files
- `android/res/values/libs.xml` - Qt library dependencies
- `android/res/xml/device_filter.xml` - USB device filters (needs customization)

### 4. Platform Detection
- **android_platform.h** - Helper functions for Android-specific features
- **main.cpp** - Android initialization and permission requests

## What Needs Implementation ⚠️

### CRITICAL: USB/Serial Communication

The biggest challenge is replacing Qt's SerialPort/SerialBus with Android USB Host API.

#### Current Desktop Implementation:
- Uses `QSerialPort` for serial devices
- Uses `QCanBusDevice` for CAN adapters
- Direct OS-level serial port access

#### Android Requirements:
1. **Replace QSerialPort with Android USB Serial**
   - Need to use Android USB Host API via JNI
   - Consider using libraries like:
     - [usb-serial-for-android](https://github.com/mik3y/usb-serial-for-android) (Java)
     - [UsbSerial4a](https://github.com/felHR85/UsbSerial) (Kotlin)
   - Create JNI bridge between C++ and Java/Kotlin USB code

2. **Files to Modify:**
   ```
   connections/serialbusconnection.cpp/h  - CAN bus connection via serial
   connections/gvretserial.cpp/h          - GVRET protocol over serial
   connections/lawicel_serial.cpp/h       - Lawicel/SLCAN protocol
   ```

3. **Implementation Strategy:**
   ```cpp
   #ifdef Q_OS_ANDROID
   // Use Android USB Host API via JNI
   class AndroidUsbSerial {
       // JNI calls to Java USB Serial library
       QAndroidJniObject usbManager;
       QAndroidJniObject usbDevice;
       // ... implement read/write/connect methods
   };
   #else
   // Use QSerialPort
   QSerialPort serialPort;
   #endif
   ```

### 2. File System Access

Android has scoped storage (API 29+) which restricts file access.

#### Required Changes:
- **Use Android Storage Access Framework (SAF)**
  - Can't directly access `/sdcard/` or arbitrary paths
  - Need to use `QAndroidIntent` to open file pickers
  - Store files in app-specific directories or use SAF

- **Files to Modify:**
  ```
  framefileio.cpp/h       - File loading/saving
  mainwindow.cpp          - File menu operations
  dbc/dbcloadsavewindow.cpp - DBC file operations
  ```

#### Implementation:
```cpp
#ifdef Q_OS_ANDROID
QString openFileAndroid() {
    QAndroidJniObject ACTION_OPEN_DOCUMENT = 
        QAndroidJniObject::getStaticObjectField(
            "android/content/Intent", "ACTION_OPEN_DOCUMENT", 
            "Ljava/lang/String;");
    QAndroidJniObject intent("android/content/Intent", 
                             "(Ljava/lang/String;)V",
                             ACTION_OPEN_DOCUMENT.object());
    // ... handle file selection
}
#endif
```

### 3. UI/UX Adaptations

Desktop UI needs touch-friendly modifications.

#### Required Changes:
- **Increase touch target sizes** (buttons, menus)
- **Adapt layouts for mobile screens**
  - Portrait vs Landscape
  - Smaller screen real estate
  - Virtual keyboard handling
- **Gesture support** (pinch-zoom in graphs)
- **Mobile navigation patterns** (drawer menus instead of menu bars)

#### Files to Consider:
```
mainwindow.ui/cpp/h         - Main application window
ui/*.ui                     - All UI files
re/graphingwindow.cpp       - Touch gestures for graphs
```

### 4. Background Operation

Android restricts background processes.

#### Implementation Needed:
- **Android Foreground Service** for continuous CAN logging
  - Create service in Java/Kotlin
  - Bridge to C++ via JNI
  - Show persistent notification while logging

```kotlin
// AndroidService.kt
class CANLoggerService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        // Call C++ logging code via JNI
        return START_STICKY
    }
}
```

### 5. Network Features (Easier)

These should work with minimal changes:

✅ **SocketCAN over network** - Should work as-is
✅ **MQTT connections** - Should work as-is  
✅ **TCP/UDP bridges** - Should work as-is
⚠️ **WiFi/Bluetooth CAN bridges** - May need Android-specific implementations

### 6. Bluetooth Support

For Bluetooth CAN adapters:

#### Implementation:
- Use Qt Bluetooth or Android Bluetooth API
- Handle Bluetooth Classic and BLE
- Bluetooth permissions already in manifest

```cpp
#ifdef Q_OS_ANDROID
#include <QtBluetooth/QBluetoothSocket>
#include <QtBluetooth/QBluetoothDeviceDiscoveryAgent>
// Implement Bluetooth CAN adapter class
#endif
```

## Step-by-Step Porting Plan

### Phase 1: Basic Build (DONE ✅)
- [x] Configure build system for Android
- [x] Create Android manifest
- [x] Add platform detection
- [x] Set up permissions

### Phase 2: USB Serial Layer (HIGH PRIORITY)
1. Integrate usb-serial-for-android library
2. Create JNI bridge for USB communication
3. Create AndroidUsbSerial wrapper class
4. Modify connection classes to use Android USB
5. Test with USB CAN adapter

**Estimated Effort:** 2-3 weeks

### Phase 3: File System (MEDIUM PRIORITY)
1. Implement SAF file pickers
2. Update all file I/O operations
3. Test loading/saving CAN logs and DBC files

**Estimated Effort:** 1-2 weeks

### Phase 4: UI Adaptation (MEDIUM PRIORITY)
1. Test UI on various Android screen sizes
2. Adjust layouts for mobile
3. Add touch gestures
4. Improve navigation

**Estimated Effort:** 2-3 weeks

### Phase 5: Background Service (LOW PRIORITY)
1. Create Android foreground service
2. Implement JNI bridge
3. Handle service lifecycle

**Estimated Effort:** 1 week

### Phase 6: Bluetooth Support (OPTIONAL)
1. Implement Bluetooth CAN adapter support
2. Test with Bluetooth OBDII adapters

**Estimated Effort:** 1-2 weeks

## Testing Strategy

### Test Devices
- **Minimum:** Android 8.0 (API 26)
- **Target:** Android 13 (API 33)
- **USB OTG:** Required for USB CAN adapters

### Test Cases
1. **USB Detection:** Plug in CAN adapter, verify device detection
2. **Permissions:** Test USB, storage, and Bluetooth permissions
3. **File Operations:** Load/save CAN logs and DBC files
4. **Network:** Test SocketCAN and MQTT connections
5. **Background:** Test continuous logging with screen off
6. **UI:** Test on different screen sizes and orientations

## Code Examples

### Example 1: Android USB Serial (JNI Bridge)

Create `android/src/com/savvycan/android/UsbSerial.java`:

```java
package com.savvycan.android;

import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import com.hoho.android.usbserial.driver.*;

public class UsbSerial {
    private UsbSerialPort port;
    
    public boolean open(int vendorId, int productId, int baudRate) {
        // Implementation using usb-serial-for-android
    }
    
    public int read(byte[] buffer, int timeout) {
        // Read from USB serial
    }
    
    public int write(byte[] data) {
        // Write to USB serial
    }
    
    public void close() {
        // Close connection
    }
}
```

C++ JNI Bridge (`android_usb.cpp`):
```cpp
#include <jni.h>
#include <QAndroidJniObject>

class AndroidUsbSerial {
private:
    QAndroidJniObject javaUsbSerial;
    
public:
    bool open(int vendorId, int productId, int baudRate) {
        javaUsbSerial = QAndroidJniObject(
            "com/savvycan/android/UsbSerial");
        return javaUsbSerial.callMethod<jboolean>(
            "open", "(III)Z", vendorId, productId, baudRate);
    }
    
    int read(QByteArray &data, int timeout) {
        QAndroidJniObject buffer = 
            javaUsbSerial.callObjectMethod("read", "([BI)I");
        // Convert Java byte array to QByteArray
    }
};
```

### Example 2: Platform-Specific Connection

```cpp
// connections/serialbusconnection.cpp
bool SerialBusConnection::piStarted()
{
#ifdef Q_OS_ANDROID
    // Android implementation
    if (!androidUsbSerial.open(vendorId, productId, baudRate)) {
        qWarning() << "Failed to open Android USB device";
        return false;
    }
    startAndroidReadLoop();
#else
    // Desktop implementation
    device = QCanBus::instance()->createDevice(
        driverName.toLocal8Bit(), portName);
    if (!device) {
        return false;
    }
    device->connectDevice();
#endif
    return true;
}
```

## Resources

### Libraries to Use
- **USB Serial:** https://github.com/mik3y/usb-serial-for-android
- **Qt Android Extras:** https://doc.qt.io/qt-5/qtandroidextras-index.html
- **Android USB Host:** https://developer.android.com/guide/topics/connectivity/usb/host

### Documentation
- Qt for Android: https://doc.qt.io/qt-5/android.html
- Android Permissions: https://developer.android.com/guide/topics/permissions
- Android Storage: https://developer.android.com/training/data-storage

## Building the APK

### Prerequisites
1. Install Qt for Android (via Qt Maintenance Tool)
2. Install Android SDK (API 26+)
3. Install Android NDK
4. Install Java JDK (8 or 11)

### Build Steps

#### In Qt Creator:
1. Open SavvyCAN.pro
2. Select Android kit (e.g., "Android Qt 5.15.2 Clang arm64-v8a")
3. Build → Build Project
4. Build → Deploy (creates APK)

#### Command Line:
```bash
# Set up environment
export ANDROID_SDK_ROOT=/path/to/android/sdk
export ANDROID_NDK_ROOT=/path/to/android/ndk
export JAVA_HOME=/path/to/jdk

# Generate Makefile
qmake -spec android-clang CONFIG+=release

# Build
make -j$(nproc)

# Create APK
androiddeployqt --input android-SavvyCAN-deployment-settings.json \
                --output android-build \
                --android-platform android-33 \
                --jdk $JAVA_HOME \
                --gradle
```

The APK will be in: `android-build/build/outputs/apk/release/`

### Installing on Device
```bash
adb install -r android-build/build/outputs/apk/release/SavvyCAN-release.apk
```

## Current Build Status

The project is now **BUILDABLE** for Android, but will have **LIMITED FUNCTIONALITY**:

✅ **Will Work:**
- Basic UI
- Network-based CAN connections (SocketCAN over network, MQTT)
- File operations (with limitations)
- Data visualization

❌ **Won't Work (Yet):**
- USB CAN adapters (needs USB Serial implementation)
- Direct serial port access
- Some file operations (needs SAF implementation)
- Background logging (needs foreground service)

## Next Steps

1. **Test the Build:** Build APK and deploy to Android device
2. **Implement USB Serial:** This is the critical path for hardware support
3. **Test Network Features:** Verify SocketCAN and MQTT work
4. **Iterate on UI:** Adapt for mobile usage patterns

## Contributing

When implementing Android features:
1. Always use `#ifdef Q_OS_ANDROID` for platform-specific code
2. Keep desktop functionality working
3. Document any new Android-specific classes
4. Test on real Android hardware with USB OTG support
5. Update this document with implementation notes

## Questions?

For Android porting questions, refer to:
- Qt Android documentation
- SavvyCAN GitHub issues
- Android developer documentation

---

**Document Version:** 1.0  
**Created:** October 2025  
**Status:** Initial Android build configuration complete
