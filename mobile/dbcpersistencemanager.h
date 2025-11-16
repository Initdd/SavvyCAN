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
    
private:
#ifdef Q_OS_ANDROID
    void initializeJavaManager();
    class QJniObject *javaManager;
#endif
};

#endif // DBCPERSISTENCEMANAGER_H
