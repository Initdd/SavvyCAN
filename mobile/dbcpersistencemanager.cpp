#include "dbcpersistencemanager.h"
#include <QDebug>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QCoreApplication>
#include <QJniEnvironment>
#endif

DbcPersistenceManager::DbcPersistenceManager(QObject *parent)
    : QObject(parent)
#ifdef Q_OS_ANDROID
    , javaManager(nullptr)
#endif
{
#ifdef Q_OS_ANDROID
    initializeJavaManager();
#endif
}

DbcPersistenceManager::~DbcPersistenceManager()
{
#ifdef Q_OS_ANDROID
    if (javaManager) {
        delete javaManager;
        javaManager = nullptr;
    }
#endif
}

#ifdef Q_OS_ANDROID
void DbcPersistenceManager::initializeJavaManager()
{
    // Get Android context using Qt 6 API
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;"
    );
    
    if (!activity.isValid()) {
        qWarning() << "DbcPersistenceManager: Failed to get Android activity";
        return;
    }
    
    // Create DbcFileManager instance
    javaManager = new QJniObject("org/savvycan/utils/DbcFileManager",
                                  "(Landroid/content/Context;)V",
                                  activity.object());
    
    if (!javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Failed to create DbcFileManager instance";
        
        // Check for Java exceptions
        QJniEnvironment env;
        if (env->ExceptionCheck()) {
            env->ExceptionDescribe();
            env->ExceptionClear();
        }
        
        delete javaManager;
        javaManager = nullptr;
    } else {
        qDebug() << "DbcPersistenceManager: Initialized successfully";
    }
}
#endif

bool DbcPersistenceManager::saveDbcUri(const QString &uriString)
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return false;
    }
    
    QJniObject jniUri = QJniObject::fromString(uriString);
    bool result = javaManager->callMethod<jboolean>("addDbcFileUri",
                                                      "(Ljava/lang/String;)Z",
                                                      jniUri.object<jstring>());
    
    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        qWarning() << "DbcPersistenceManager: Exception in saveDbcUri";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }
    
    qDebug() << "DbcPersistenceManager: Saved URI" << uriString << "Result:" << result;
    return result;
#else
    Q_UNUSED(uriString);
    qDebug() << "DbcPersistenceManager: Not on Android, persistence not supported";
    return false;
#endif
}

bool DbcPersistenceManager::removeDbcUri(const QString &uriString)
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return false;
    }
    
    QJniObject jniUri = QJniObject::fromString(uriString);
    bool result = javaManager->callMethod<jboolean>("removeDbcFileUri",
                                                      "(Ljava/lang/String;)Z",
                                                      jniUri.object<jstring>());
    
    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        qWarning() << "DbcPersistenceManager: Exception in removeDbcUri";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }
    
    qDebug() << "DbcPersistenceManager: Removed URI" << uriString << "Result:" << result;
    return result;
#else
    Q_UNUSED(uriString);
    return false;
#endif
}

QStringList DbcPersistenceManager::getSavedDbcUris()
{
    QStringList result;
    
#ifdef Q_OS_ANDROID
    qDebug() << "DbcPersistenceManager::getSavedDbcUris called";
    
    if (!javaManager || !javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return result;
    }
    
    qDebug() << "DbcPersistenceManager: Java manager is valid, calling getSavedDbcUris";
    
    QJniObject javaList = javaManager->callObjectMethod("getSavedDbcUris",
                                                         "()Ljava/util/List;");
    
    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        qWarning() << "DbcPersistenceManager: Exception in getSavedDbcUris";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return result;
    }
    
    if (!javaList.isValid()) {
        qWarning() << "DbcPersistenceManager: Failed to get saved URIs (javaList invalid)";
        return result;
    }
    
    // Convert Java List to QStringList
    int size = javaList.callMethod<jint>("size", "()I");
    qDebug() << "DbcPersistenceManager: Java list size:" << size;
    
    for (int i = 0; i < size; i++) {
        QJniObject item = javaList.callObjectMethod("get",
                                                     "(I)Ljava/lang/Object;",
                                                     i);
        if (item.isValid()) {
            QString uriString = item.toString();
            qDebug() << "DbcPersistenceManager: Retrieved URI:" << uriString;
            result.append(uriString);
        }
    }
    
    qDebug() << "DbcPersistenceManager: Retrieved" << result.size() << "saved URIs";
#else
    qDebug() << "DbcPersistenceManager: Not on Android, returning empty list";
#endif
    
    return result;
}

bool DbcPersistenceManager::isUriValid(const QString &uriString)
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return false;
    }
    
    QJniObject jniUri = QJniObject::fromString(uriString);
    bool result = javaManager->callMethod<jboolean>("isUriValid",
                                                      "(Ljava/lang/String;)Z",
                                                      jniUri.object<jstring>());
    
    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        qWarning() << "DbcPersistenceManager: Exception in isUriValid";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }
    
    return result;
#else
    Q_UNUSED(uriString);
    return false;
#endif
}

QStringList DbcPersistenceManager::cleanupInvalidUris()
{
    QStringList result;
    
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return result;
    }
    
    QJniObject javaList = javaManager->callObjectMethod("cleanupInvalidUris",
                                                         "()Ljava/util/List;");
    
    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        qWarning() << "DbcPersistenceManager: Exception in cleanupInvalidUris";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return result;
    }
    
    if (!javaList.isValid()) {
        qWarning() << "DbcPersistenceManager: Failed to cleanup invalid URIs";
        return result;
    }
    
    // Convert Java List to QStringList
    int size = javaList.callMethod<jint>("size", "()I");
    for (int i = 0; i < size; i++) {
        QJniObject item = javaList.callObjectMethod("get",
                                                     "(I)Ljava/lang/Object;",
                                                     i);
        if (item.isValid()) {
            QString uriString = item.toString();
            result.append(uriString);
        }
    }
    
    qDebug() << "DbcPersistenceManager: Cleaned up" << result.size() << "invalid URIs";
#endif
    
    return result;
}

void DbcPersistenceManager::clearAllUris()
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid()) {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return;
    }
    
    javaManager->callMethod<void>("clearAllUris", "()V");
    
    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck()) {
        qWarning() << "DbcPersistenceManager: Exception in clearAllUris";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }
    
    qDebug() << "DbcPersistenceManager: Cleared all URIs";
#endif
}
