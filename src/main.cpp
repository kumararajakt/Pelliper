#include <QApplication>
#include <QIcon>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSystemTrayIcon>
#include <QWindow>

#include <KLocalizedContext>
#include <KLocalizedString>

#include "ipc/DaemonClient.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("pelliper");

    QCoreApplication::setOrganizationName(QStringLiteral("Pelliper"));
    QCoreApplication::setApplicationName(QStringLiteral("pelliper"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    QGuiApplication::setDesktopFileName(QStringLiteral("com.pelliper.Pelliper"));

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
    }

    DaemonClient daemonClient;
    daemonClient.connectToDaemon();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("daemonClient"), &daemonClient);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("com.pelliper.app"), QStringLiteral("Main"));

    // Always-enabled System Tray Icon
    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        auto *tray = new QSystemTrayIcon(QIcon::fromTheme(QStringLiteral("mail-client")), &app);
        tray->setToolTip(QStringLiteral("Pelliper"));

        auto *trayMenu = new QMenu();
        auto *openAction = trayMenu->addAction(QStringLiteral("Open Pelliper"));
        auto *quitAction = trayMenu->addAction(QStringLiteral("Quit"));

        QObject::connect(openAction, &QAction::triggered, &app, [&engine]() {
            const auto objs = engine.rootObjects();
            if (!objs.isEmpty()) {
                if (auto *win = qobject_cast<QWindow *>(objs.first())) {
                    win->show();
                    win->raise();
                    win->requestActivate();
                }
            }
        });
        QObject::connect(quitAction, &QAction::triggered, &app, &QCoreApplication::quit);
        QObject::connect(tray, &QSystemTrayIcon::activated, &app, [openAction](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger) {
                openAction->trigger();
            }
        });

        tray->setContextMenu(trayMenu);
        tray->show();
    }

    return app.exec();
}
