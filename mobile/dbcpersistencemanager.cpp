#include "dbcpersistencemanager.h"
#include <QDebug>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QCoreApplication>
#include <QJniEnvironment>

// Global instance pointer for JNI callback
static DbcPersistenceManager *g_persistenceInstance = nullptr;

// JNI callback function called from Java when file is selected
extern "C" JNIEXPORT void JNICALL
Java_org_savvycan_SavvyCANActivity_notifyFileSelected(JNIEnv *env, jobject thiz, jstring uriString)
{
    if (g_persistenceInstance && uriString)
    {
        const char *nativeString = env->GetStringUTFChars(uriString, nullptr);
        QString uri = QString::fromUtf8(nativeString);
        env->ReleaseStringUTFChars(uriString, nativeString);

        qDebug() << "DbcPersistenceManager: File selected from native picker:" << uri;

        // Emit signal to QML
        QMetaObject::invokeMethod(g_persistenceInstance, "fileSelected",
                                  Qt::QueuedConnection,
                                  Q_ARG(QString, uri));
    }
    else if (g_persistenceInstance)
    {
        qDebug() << "DbcPersistenceManager: File picker cancelled";
        QMetaObject::invokeMethod(g_persistenceInstance, "fileSelected",
                                  Qt::QueuedConnection,
                                  Q_ARG(QString, QString()));
    }
}
#endif

DbcPersistenceManager::DbcPersistenceManager(QObject *parent)
    : QObject(parent)
#ifdef Q_OS_ANDROID
      ,
      javaManager(nullptr)
#endif
{
#ifdef Q_OS_ANDROID
    g_persistenceInstance = this;
    initializeJavaManager();
#endif
}

DbcPersistenceManager::~DbcPersistenceManager()
{
#ifdef Q_OS_ANDROID
    if (javaManager)
    {
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
        "()Landroid/app/Activity;");

    if (!activity.isValid())
    {
        qWarning() << "DbcPersistenceManager: Failed to get Android activity";
        return;
    }

    // Create DbcFileManager instance
    javaManager = new QJniObject("org/savvycan/utils/DbcFileManager",
                                 "(Landroid/content/Context;)V",
                                 activity.object());

    if (!javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Failed to create DbcFileManager instance";

        // Check for Java exceptions
        QJniEnvironment env;
        if (env->ExceptionCheck())
        {
            env->ExceptionDescribe();
            env->ExceptionClear();
        }

        delete javaManager;
        javaManager = nullptr;
    }
    else
    {
        qDebug() << "DbcPersistenceManager: Initialized successfully";
    }
}
#endif

bool DbcPersistenceManager::saveDbcUri(const QString &uriString)
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return false;
    }

    QJniObject jniUri = QJniObject::fromString(uriString);
    bool result = javaManager->callMethod<jboolean>("addDbcFileUri",
                                                    "(Ljava/lang/String;)Z",
                                                    jniUri.object<jstring>());

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
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
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return false;
    }

    QJniObject jniUri = QJniObject::fromString(uriString);
    bool result = javaManager->callMethod<jboolean>("removeDbcFileUri",
                                                    "(Ljava/lang/String;)Z",
                                                    jniUri.object<jstring>());

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
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

    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return result;
    }

    qDebug() << "DbcPersistenceManager: Java manager is valid, calling getSavedDbcUris";

    QJniObject javaList = javaManager->callObjectMethod("getSavedDbcUris",
                                                        "()Ljava/util/List;");

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
        qWarning() << "DbcPersistenceManager: Exception in getSavedDbcUris";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return result;
    }

    if (!javaList.isValid())
    {
        qWarning() << "DbcPersistenceManager: Failed to get saved URIs (javaList invalid)";
        return result;
    }

    // Convert Java List to QStringList
    int size = javaList.callMethod<jint>("size", "()I");
    qDebug() << "DbcPersistenceManager: Java list size:" << size;

    for (int i = 0; i < size; i++)
    {
        QJniObject item = javaList.callObjectMethod("get",
                                                    "(I)Ljava/lang/Object;",
                                                    i);
        if (item.isValid())
        {
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
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return false;
    }

    QJniObject jniUri = QJniObject::fromString(uriString);
    bool result = javaManager->callMethod<jboolean>("isUriValid",
                                                    "(Ljava/lang/String;)Z",
                                                    jniUri.object<jstring>());

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
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
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return result;
    }

    QJniObject javaList = javaManager->callObjectMethod("cleanupInvalidUris",
                                                        "()Ljava/util/List;");

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
        qWarning() << "DbcPersistenceManager: Exception in cleanupInvalidUris";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return result;
    }

    if (!javaList.isValid())
    {
        qWarning() << "DbcPersistenceManager: Failed to cleanup invalid URIs";
        return result;
    }

    // Convert Java List to QStringList
    int size = javaList.callMethod<jint>("size", "()I");
    for (int i = 0; i < size; i++)
    {
        QJniObject item = javaList.callObjectMethod("get",
                                                    "(I)Ljava/lang/Object;",
                                                    i);
        if (item.isValid())
        {
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
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return;
    }

    javaManager->callMethod<void>("clearAllUris", "()V");

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
        qWarning() << "DbcPersistenceManager: Exception in clearAllUris";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }

    qDebug() << "DbcPersistenceManager: Cleared all URIs";
#endif
}

QString DbcPersistenceManager::getFilenameFromUri(const QString &uriString)
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return uriString;
    }

    QJniObject jniUri = QJniObject::fromString(uriString);
    QJniObject jniResult = javaManager->callObjectMethod("getFilenameFromUri",
                                                         "(Ljava/lang/String;)Ljava/lang/String;",
                                                         jniUri.object<jstring>());

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
        qWarning() << "DbcPersistenceManager: Exception in getFilenameFromUri";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return uriString;
    }

    if (jniResult.isValid())
    {
        return jniResult.toString();
    }

    return uriString;
#else
    Q_UNUSED(uriString);
    // On non-Android, extract filename from path
    int lastSlash = uriString.lastIndexOf('/');
    if (lastSlash >= 0)
    {
        return uriString.mid(lastSlash + 1);
    }
    return uriString;
#endif
}

void DbcPersistenceManager::openNativeFilePicker()
{
#ifdef Q_OS_ANDROID
    if (!javaManager || !javaManager->isValid())
    {
        qWarning() << "DbcPersistenceManager: Java manager not initialized";
        return;
    }

    // Get the Android activity
    QJniObject activity = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "activity",
        "()Landroid/app/Activity;");

    if (!activity.isValid())
    {
        qWarning() << "DbcPersistenceManager: Could not get Android activity";
        return;
    }

    // Call openFilePicker on the Java manager
    bool success = javaManager->callMethod<jboolean>("openFilePicker",
                                                     "(Landroid/app/Activity;)Z",
                                                     activity.object<jobject>());

    // Check for exceptions
    QJniEnvironment env;
    if (env->ExceptionCheck())
    {
        qWarning() << "DbcPersistenceManager: Exception in openNativeFilePicker";
        env->ExceptionDescribe();
        env->ExceptionClear();
        return;
    }

    if (success)
    {
        qDebug() << "DbcPersistenceManager: Native file picker opened successfully";
    }
    else
    {
        qWarning() << "DbcPersistenceManager: Failed to open native file picker";
    }
#else
    qDebug() << "DbcPersistenceManager: Native file picker only available on Android";
#endif
}
