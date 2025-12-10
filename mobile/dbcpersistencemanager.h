#ifndef DBCPERSISTENCEMANAGER_H
#define DBCPERSISTENCEMANAGER_H

#include <QObject>
#include <QStringList>

#ifdef Q_OS_ANDROID
// Forward declaration for Qt 6 JNI
class QJniObject;
#endif

/**
 * @brief Manager class for persisting DBC file URIs across app sessions.
 * 
 * This class provides a QML-accessible interface for saving and loading
 * DBC file references using Android's SharedPreferences and persistent
 * URI permissions through the Storage Access Framework (SAF).
 */
class DbcPersistenceManager : public QObject
{
    Q_OBJECT
    
public:
    explicit DbcPersistenceManager(QObject *parent = nullptr);
    ~DbcPersistenceManager();
    
signals:
    /**
     * @brief Emitted when a file is selected from the native file picker
     * @param uriString The URI of the selected file
     */
    void fileSelected(const QString &uriString);
    
public slots:
    
    /**
     * @brief Save a DBC file URI for persistence
     * @param uriString The URI string to save (can be file:// or content://)
     * @return true if successfully saved, false otherwise
     */
    Q_INVOKABLE bool saveDbcUri(const QString &uriString);
    
    /**
     * @brief Remove a saved DBC file URI
     * @param uriString The URI string to remove
     * @return true if successfully removed, false otherwise
     */
    Q_INVOKABLE bool removeDbcUri(const QString &uriString);
    
    /**
     * @brief Get all saved DBC file URIs
     * @return List of saved URI strings
     */
    Q_INVOKABLE QStringList getSavedDbcUris();
    
    /**
     * @brief Check if a URI is still valid/accessible
     * @param uriString The URI string to validate
     * @return true if valid and accessible, false otherwise
     */
    Q_INVOKABLE bool isUriValid(const QString &uriString);
    
    /**
     * @brief Remove all invalid URIs and return them
     * @return List of removed URI strings
     */
    Q_INVOKABLE QStringList cleanupInvalidUris();
    
    /**
     * @brief Clear all saved URIs
     */
    Q_INVOKABLE void clearAllUris();
    
    /**
     * @brief Get just the filename from a URI for display purposes
     * @param uriString The URI string
     * @return The extracted filename
     */
    Q_INVOKABLE QString getFilenameFromUri(const QString &uriString);
    
    /**
     * @brief Open native Android file picker that properly requests persistable permissions
     * This replaces Qt's FileDialog which doesn't request persistable permissions on Android
     */
    Q_INVOKABLE void openNativeFilePicker();
    
private:
#ifdef Q_OS_ANDROID
    void initializeJavaManager();
    class QJniObject *javaManager;
#endif
};

#endif // DBCPERSISTENCEMANAGER_H
