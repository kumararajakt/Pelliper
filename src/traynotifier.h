#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QHash>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class KStatusNotifierItem;
class QMenu;
class QDBusInterface;

/// Owns the system tray icon and desktop notifications. Watches the shared
/// cache database for newly arrived messages (same debounced-watcher pattern
/// as the models) and raises a KNotification per new INBOX message; large
/// bursts are collapsed into a single aggregate notification. The last-seen
/// row id is persisted so messages that arrive while the app is closed still
/// produce a notification next launch.
class TrayNotifier : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY unreadCountChanged)

public:
    explicit TrayNotifier(QObject *parent = nullptr);

    int unreadCount() const { return m_unread; }

Q_SIGNALS:
    void openMessage(int accountId, const QString &folderPath, quint64 uid,
                     const QString &subject, const QString &sender, qint64 date);
    void showWindow();
    void unreadCountChanged();

private:
    struct NewMessage {
        quint64 rowid;
        int accountId;
        QString folderPath;
        quint64 uid;
        QString subject;
        QString sender;
        QString preview;
        qint64 date;
    };

    Q_SLOT void onFileChanged(const QString &path);
    Q_SLOT void onNotificationClosed(uint id, uint reason);
    Q_SLOT void onActionInvoked(uint id, const QString &action);
    void refresh();
    void updateTrayState();
    void checkNewMessages();
    void notifySingle(const NewMessage &m);
    void notifyAggregate(int count);
    static QString cacheDbPath();
    void startWatching();

    KStatusNotifierItem *m_tray = nullptr;
    QMenu *m_menu = nullptr;
    QDBusInterface *m_notify = nullptr;
    QHash<uint, NewMessage> m_openById;
    int m_unread = 0;
    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};