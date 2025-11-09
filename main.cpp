#include "mainwindow.h"
#include <QApplication>
#include <QSettings>
#include <QFont>

#ifdef Q_OS_ANDROID
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>
#include "mobile/mainwindow_mobile_qml.h"
#endif

class SavvyCANApplication : public QApplication
{
public:
    MainWindow *mainWindow;
    
    SavvyCANApplication(int &argc, char **argv) : QApplication(argc, argv)
    {
    }

    bool event(QEvent *event) override
    {
        if (event->type() == QEvent::FileOpen)
        {
            QFileOpenEvent *openEvent = static_cast<QFileOpenEvent *>(event);
            mainWindow->handleDroppedFile(openEvent->file());
        }

        return QApplication::event(event);
    }
};

int main(int argc, char *argv[])
{
#ifdef QT_DEBUG
    //uncomment for verbose debug data in application output
    //qputenv("QT_FATAL_WARNINGS", "1");
    //qSetMessagePattern("Type: %{type}\nProduct Name: %{appname}\nFile: %{file}\nLine: %{line}\nMethod: %{function}\nThreadID: %{threadid}\nThreadPtr: %{qthreadptr}\nMessage: %{message}");
#endif

#ifdef Q_OS_ANDROID
    // QML-based mobile application
    QApplication a(argc, argv);
    
    //These things are used by QSettings to set up setting storage
    a.setOrganizationName("EVTV");
    a.setApplicationName("SavvyCAN");
    a.setOrganizationDomain("evtv.me");
    QSettings::setDefaultFormat(QSettings::IniFormat);
    
    // Set Material or other mobile-friendly style
    QQuickStyle::setStyle("Material");
    
    // Configure Material theme colors to match ThemeManager.qml
    // Note: These values should match the accentColor and color scheme in qml/ThemeManager.qml
    // Material theme requires environment variables to be set before QML engine loads
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT", "#3daee9");     // Must match ThemeManager.accentColor
    qputenv("QT_QUICK_CONTROLS_MATERIAL_PRIMARY", "#3daee9");    // Must match ThemeManager.accentColor
    qputenv("QT_QUICK_CONTROLS_MATERIAL_FOREGROUND", "#e0e0e0"); // Must match ThemeManager.textColor
    qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#1e1e1e"); // Must match ThemeManager.backgroundColor
    
    QQmlApplicationEngine engine;
    
    // Load the main QML file
    const QUrl url(QStringLiteral("qrc:/qml/MainWindow.qml"));
    
    qDebug() << "Loading QML from:" << url;
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &a, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            qCritical() << "Failed to load QML!";
            QCoreApplication::exit(-1);
        } else if (obj) {
            qDebug() << "QML loaded successfully!";
        }
    }, Qt::QueuedConnection);
    
    engine.load(url);
    
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "No root objects created!";
        return -1;
    }
    
    // Create the C++ backend controller
    MainWindowMobileQML *mainWindow = new MainWindowMobileQML(&engine);
    
    int retCode = a.exec();
    
    delete mainWindow;
    
    return retCode;
#else
    // Desktop widget-based application
    SavvyCANApplication a(argc, argv);

    //Add a local path for Qt extensions, to allow for per-application extensions.
    a.addLibraryPath("plugins");

    //These things are used by QSettings to set up setting storage
    a.setOrganizationName("EVTV");
    a.setApplicationName("SavvyCAN");
    a.setOrganizationDomain("evtv.me");
    QSettings::setDefaultFormat(QSettings::IniFormat);

    a.mainWindow = new MainWindow();

    QSettings settings;
    int fontSize = settings.value("Main/FontSize", 9).toUInt();
    QFont sysFont = QFont(); //get default font
    sysFont.setPointSize(fontSize);
    a.setFont(sysFont);

    a.mainWindow->show();

    int retCode = a.exec();
    
    delete a.mainWindow; a.mainWindow = NULL;
    
    return retCode;
#endif
}
