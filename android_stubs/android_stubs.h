#pragma once
#ifndef ANDROID_STUBS_H
#define ANDROID_STUBS_H

// Android stub implementations for Qt SerialBus and SerialPort modules
// These provide minimal "do-nothing" implementations to allow compilation on Android

#include "qserialport.h"
#include "qcanbusframe.h"
#include "qcanbusdevice.h"
#include "qcanbus.h"

#endif // ANDROID_STUBS_H