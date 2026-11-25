#include <QApplication>
#include <QIcon>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSystemTrayIcon>
#include <QWindow>

#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include "app/AccountController.h"
#include "app/AppSettings.h"
#include "app/MessageController.h"
#include "app/NotificationService.h"
#include "ipc/DaemonClient.h"
#include "models/FolderModel.h"
#include "models/ThreadListModel.h"

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

    AppSettings appSettings;
    DaemonClient daemonClient;
    AccountController accountController(&daemonClient);
    MessageController messageController(&daemonClient);
    NotificationService notificationService(&daemonClient);
    FolderModel folderModel(&daemonClient);
    folderModel.setFolderMode(appSettings.folderMode());
    ThreadListModel threadListModel(&daemonClient);

    QObject::connect(&appSettings, &AppSettings::folderModeChanged, &folderModel, [&appSettings, &folderModel]() {
        folderModel.setFolderMode(appSettings.folderMode());
    });

    daemonClient.connectToDaemon();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedQmlContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("appSettings"), &appSettings);
    engine.rootContext()->setContextProperty(QStringLiteral("daemonClient"), &daemonClient);
    engine.rootContext()->setContextProperty(QStringLiteral("accountController"), &accountController);
    engine.rootContext()->setContextProperty(QStringLiteral("messageController"), &messageController);
    engine.rootContext()->setContextProperty(QStringLiteral("folderModel"), &folderModel);
    engine.rootContext()->setContextProperty(QStringLiteral("threadListModel"), &threadListModel);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule(QStringLiteral("com.pelliper.app"), QStringLiteral("Main"));

    auto showMainWindow = [&engine]() {
        const auto objs = engine.rootObjects();
        if (!objs.isEmpty()) {
            if (auto *win = qobject_cast<QWindow *>(objs.first())) {
                win->show();
                win->raise();
                win->requestActivate();
            }
        }
    };

    QObject::connect(&notificationService, &NotificationService::openWindowRequested, &app, showMainWindow);

    // Always-enabled System Tray Icon
    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        app.setQuitOnLastWindowClosed(false);
        auto *tray = new QSystemTrayIcon(QIcon::fromTheme(QStringLiteral("mail-client")), &app);
        tray->setToolTip(QStringLiteral("Pelliper"));

        auto *trayMenu = new QMenu();
        auto *openAction = trayMenu->addAction(QStringLiteral("Open Pelliper"));
        auto *composeAction = trayMenu->addAction(QStringLiteral("New Message…"));
        trayMenu->addSeparator();
        auto *quitAction = trayMenu->addAction(QStringLiteral("Quit"));

        QObject::connect(openAction, &QAction::triggered, &app, showMainWindow);
        QObject::connect(composeAction, &QAction::triggered, &app, [&engine, showMainWindow]() {
            showMainWindow();
            const auto objs = engine.rootObjects();
            if (!objs.isEmpty()) {
                QMetaObject::invokeMethod(objs.first(), "openComposer");
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

        QObject::connect(&daemonClient, &DaemonClient::notificationReceived, tray, [tray, &folderModel](const QString &method, const QJsonObject &) {
            if (method == QStringLiteral("folder.updated")) {
                int totalUnread = 0;
                for (int i = 0; i < folderModel.rowCount(); ++i) {
                    const QModelIndex idx = folderModel.index(i);
                    if (folderModel.data(idx, FolderModel::IsUnifiedRole).toBool()
                        && folderModel.data(idx, FolderModel::RoleTypeRole).toString() == QStringLiteral("inbox")) {
                        totalUnread = folderModel.data(idx, FolderModel::UnreadCountRole).toInt();
                        break;
                    }
                }
                tray->setToolTip(totalUnread > 0
                                     ? QStringLiteral("Pelliper (%1 unread)").arg(totalUnread)
                                     : QStringLiteral("Pelliper"));
            }
        });
    }

    return app.exec();
}
