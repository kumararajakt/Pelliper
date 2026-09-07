#include "traynotifier.h"

#include <QCoreApplication>
#include <QDBusInterface>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QMenu>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>

#include <KLocalizedString>
#include <KStatusNotifierItem>

static const QString DB_CONN = QStringLiteral("pelliper_tray_readonly");
static const QString NOTIFY_SERVICE = QStringLiteral("org.freedesktop.Notifications");
static const QString NOTIFY_PATH = QStringLiteral("/org/freedesktop/Notifications");
static const QString NOTIFY_IFACE = QStringLiteral("org.freedesktop.Notifications");
static const int NEW_MAIL_BURST_LIMIT = 12;

TrayNotifier::TrayNotifier(QObject *parent)
    : QObject(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &TrayNotifier::refresh);

    m_menu = new QMenu();
    m_menu->addAction(i18n("Show Pelliper"), this, &TrayNotifier::showWindow);
    m_menu->addSeparator();
    m_menu->addAction(i18n("Quit"), qApp, &QCoreApplication::quit);

    m_notify = new QDBusInterface(NOTIFY_SERVICE, NOTIFY_PATH, NOTIFY_IFACE,
                                  QDBusConnection::sessionBus(), this);
    connect(m_notify, SIGNAL(ActionInvoked(uint, QString)),
            this, SLOT(onActionInvoked(uint, QString)),
            Qt::QueuedConnection);
    connect(m_notify, SIGNAL(NotificationClosed(uint, uint)),
            this, SLOT(onNotificationClosed(uint, uint)),
            Qt::QueuedConnection);

    m_tray = new KStatusNotifierItem(QStringLiteral("pelliper"), this);
    m_tray->setCategory(KStatusNotifierItem::Communications);
    m_tray->setTitle(QStringLiteral("Pelliper"));
    m_tray->setContextMenu(m_menu);
    m_tray->setStandardActionsEnabled(false);
    connect(m_tray, &KStatusNotifierItem::activateRequested, this, &TrayNotifier::showWindow);
    connect(m_tray, &KStatusNotifierItem::secondaryActivateRequested,
            this, &TrayNotifier::showWindow);

    startWatching();
    refresh();
}

void TrayNotifier::startWatching()
{
    const QString dbPath = cacheDbPath();
    if (QFile::exists(dbPath) && !m_watcher.files().contains(dbPath)) {
        m_watcher.addPath(dbPath);
        m_watcher.addPath(dbPath + QStringLiteral("-wal"));
        m_watcher.addPath(dbPath + QStringLiteral("-shm"));
        connect(&m_watcher, &QFileSystemWatcher::fileChanged,
                this, &TrayNotifier::onFileChanged);
    }
}

void TrayNotifier::onFileChanged(const QString &path)
{
    Q_UNUSED(path)
    if (!m_refreshTimer.isActive())
        m_refreshTimer.start();

    const QString dbPath = cacheDbPath();
    if (!m_watcher.files().contains(dbPath) && QFile::exists(dbPath)) {
        m_watcher.addPath(dbPath);
        m_watcher.addPath(dbPath + QStringLiteral("-wal"));
        m_watcher.addPath(dbPath + QStringLiteral("-shm"));
    }
}

QString TrayNotifier::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

void TrayNotifier::refresh()
{
    const QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath))
        return;

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        if (db.open()) {
            QSqlQuery q(db);
            if (q.exec(QStringLiteral("SELECT COUNT(*) FROM messages WHERE is_read = 0")) && q.next()) {
                const int unread = q.value(0).toInt();
                if (unread != m_unread) {
                    m_unread = unread;
                    Q_EMIT unreadCountChanged();
                }
            }
        } else {
            qWarning() << "TrayNotifier: failed to open cache.db:" << db.lastError().text();
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    updateTrayState();
    checkNewMessages();
}

void TrayNotifier::updateTrayState()
{
    m_tray->setStatus(m_unread > 0 ? KStatusNotifierItem::NeedsAttention
                                   : KStatusNotifierItem::Active);
    m_tray->setIconByName(m_unread > 0 ? QStringLiteral("mail-unread")
                                       : QStringLiteral("mail-read"));
    m_tray->setToolTipTitle(QStringLiteral("Pelliper"));
    m_tray->setToolTipSubTitle(m_unread > 0
        ? i18np("%1 unread message", "%1 unread messages", m_unread)
        : i18n("No unread messages"));
}

void TrayNotifier::checkNewMessages()
{
    const QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath))
        return;

    QSettings settings;
    const qint64 stored = settings.value(QStringLiteral("notifier/lastSeenRowid")).toLongLong();

    // Empty DB: nothing to look at yet.
    quint64 maxRow = 0;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        if (!db.open()) {
            QSqlDatabase::removeDatabase(DB_CONN);
            return;
        }

        QSqlQuery q(db);
        if (q.exec(QStringLiteral("SELECT COALESCE(MAX(rowid), 0) FROM messages")) && q.next())
            maxRow = q.value(0).toULongLong();
        q.finish();

        QList<NewMessage> newMessages;
        quint64 lastSeen = stored;
        if (maxRow < lastSeen) {
            // Cache database was recreated; start from a fresh baseline.
            lastSeen = 0;
        }

        if (lastSeen == 0) {
            settings.setValue(QStringLiteral("notifier/lastSeenRowid"), maxRow);
        } else if (maxRow > lastSeen) {
            QSqlQuery rows(db);
            rows.prepare(QStringLiteral(
                "SELECT rowid, account_id, folder_path, uid, subject, sender, date, preview "
                "FROM messages WHERE rowid > ? ORDER BY rowid ASC LIMIT 200"));
            rows.addBindValue(lastSeen);
            if (rows.exec()) {
                while (rows.next()) {
                    NewMessage m;
                    m.rowid = rows.value(0).toULongLong();
                    m.accountId = rows.value(1).toInt();
                    m.folderPath = rows.value(2).toString();
                    m.uid = rows.value(3).toULongLong();
                    m.subject = rows.value(4).toString();
                    m.sender = rows.value(5).toString();
                    m.date = rows.value(6).toLongLong();
                    m.preview = rows.value(7).toString();
                    newMessages.append(m);
                }
            }

            if (newMessages.isEmpty()) {
                settings.setValue(QStringLiteral("notifier/lastSeenRowid"), maxRow);
            } else if (newMessages.size() > NEW_MAIL_BURST_LIMIT) {
                notifyAggregate(newMessages.size());
                settings.setValue(QStringLiteral("notifier/lastSeenRowid"), maxRow);
            } else {
                for (const NewMessage &m : newMessages) {
                    if (m.folderPath.compare(QStringLiteral("INBOX"), Qt::CaseInsensitive) == 0)
                        notifySingle(m);
                }
                settings.setValue(QStringLiteral("notifier/lastSeenRowid"), maxRow);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);
}

void TrayNotifier::notifySingle(const NewMessage &m)
{
    const QString sender = m.sender.isEmpty()
        ? i18n("(unknown sender)") : m.sender;
    const QString subject = m.subject.isEmpty()
        ? i18n("(no subject)") : m.subject;
    QString body = sender;
    if (!m.preview.isEmpty())
        body += QStringLiteral("\n") + m.preview;

    QVariantMap hints;
    hints[QStringLiteral("desktop-entry")] = QStringLiteral("pelliper");
    hints[QStringLiteral("urgency")] = 1;

    // 0 = never expires (persistent), like a KNotification::Persistent mail popup.
    QDBusPendingCall call = m_notify->asyncCall(QStringLiteral("Notify"),
        QCoreApplication::applicationName(),                      // app_name
        QVariant(0u),                                            // replaces_id
        QStringLiteral("pelliper"),                              // app_icon
        subject,                                                 // summary
        body,                                                    // body
        QStringList{QStringLiteral("default"), i18n("Open")},    // actions
        hints,                                                   // hints
        QVariant(0));                                            // expire_timeout

    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, m](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusReply<uint> reply = w->reply();
        if (reply.isValid())
            m_openById.insert(reply.value(), m);
    });
}

void TrayNotifier::notifyAggregate(int count)
{
    QVariantMap hints;
    hints[QStringLiteral("desktop-entry")] = QStringLiteral("pelliper");

    m_notify->asyncCall(QStringLiteral("Notify"),
        QCoreApplication::applicationName(),
        QVariant(0u),
        QStringLiteral("pelliper"),
        i18n("New mail"),
        i18np("%1 new message", "%1 new messages", count),
        QStringList{QStringLiteral("default"), i18n("Open Pelliper")},
        hints,
        QVariant(-1));  // server default timeout
}

void TrayNotifier::onActionInvoked(uint id, const QString &action)
{
    Q_UNUSED(action)
    const NewMessage m = m_openById.take(id);
    if (m.rowid == 0)
        return;
    Q_EMIT openMessage(m.accountId, m.folderPath, m.uid, m.subject, m.sender, m.date);
    Q_EMIT showWindow();
}

void TrayNotifier::onNotificationClosed(uint id, uint reason)
{
    Q_UNUSED(reason)
    m_openById.remove(id);
}