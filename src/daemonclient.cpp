#include "daemonclient.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingReply>
#include <QFile>

static const QString SERVICE = QStringLiteral("org.kde.pelliper.Daemon");
static const QString PATH = QStringLiteral("/org/kde/pelliper/Daemon");
static const QString INTERFACE = QStringLiteral("org.kde.pelliper.Daemon");

DaemonClient::DaemonClient(QObject *parent)
    : QObject(parent)
    , m_iface(SERVICE, PATH, INTERFACE, QDBusConnection::sessionBus(), this)
{
    m_available = m_iface.isValid();
    Q_EMIT availableChanged();

    if (!m_available) {
        connect(&m_iface, &QDBusAbstractInterface::connection, this, [this]() {
            if (!m_available) {
                m_available = m_iface.isValid();
                Q_EMIT availableChanged();
            }
        });
    }
}

void DaemonClient::addAccount(
    const QString &email,
    const QString &displayName,
    const QString &imapHost,
    int imapPort,
    const QString &smtpHost,
    int smtpPort,
    const QString &authType,
    const QString &authToken,
    const QString &refreshToken
) {
    if (m_busy) {
        return;
    }

    if (!m_available) {
        Q_EMIT accountFailed(email, tr("Daemon is not running."));
        return;
    }

    setBusy(true);

    qWarning() << "DaemonClient::addAccount" << email << displayName << imapHost << imapPort << smtpHost << smtpPort << authType;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("AddAccount"));

    QList<QVariant> args;
    args << email << displayName << imapHost
         << static_cast<qint32>(imapPort)
         << smtpHost
         << static_cast<qint32>(smtpPort)
         << authType << authToken << refreshToken;
    msg.setArguments(args);

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);

    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished,
            this, &DaemonClient::onAddAccountReply);
}

void DaemonClient::onAddAccountReply(QDBusPendingCallWatcher *watcher)
{
    setBusy(false);

    QDBusPendingReply<bool> reply = *watcher;
    watcher->deleteLater();

    if (reply.isError()) {
        const QString error = reply.error().message();
        Q_EMIT accountFailed(QString(), error);
        return;
    }

    bool success = reply.value();
    if (success) {
        Q_EMIT accountAdded(QString());
    } else {
        Q_EMIT accountFailed(QString(), tr("Failed to add account (IMAP test failed or account already exists)."));
    }
}

void DaemonClient::setAvailable(bool value)
{
    if (m_available == value) return;
    m_available = value;
    Q_EMIT availableChanged();
}

void DaemonClient::setBusy(bool value)
{
    if (m_busy == value) return;
    m_busy = value;
    Q_EMIT busyChanged();
}

void DaemonClient::getFolders(qint64 accountId)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("GetFolders"));
    msg.setArguments({QVariant::fromValue(accountId)});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        onGenericReply(watcher, QStringLiteral("foldersLoaded"));
    });
}

void DaemonClient::getMessages(qint64 accountId, const QString &folderPath, qint64 offset, qint64 limit)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("GetMessages"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(offset), QVariant::fromValue(limit)});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        onGenericReply(watcher, QStringLiteral("messagesLoaded"));
    });
}

void DaemonClient::countMessages(qint64 accountId, const QString &folderPath)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("CountMessages"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        QDBusPendingReply<qint64> reply = *watcher;
        watcher->deleteLater();
        if (!reply.isError()) {
            Q_EMIT messageCountLoaded(reply.value());
        }
    });
}

void DaemonClient::syncAll()
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("SyncAll"));

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        QDBusPendingReply<bool> reply = *watcher;
        watcher->deleteLater();
        Q_EMIT syncAllFinished(!reply.isError() && reply.value());
    });
}

void DaemonClient::setIdleFolder(qint64 accountId, const QString &folderPath)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("SetIdleFolder"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::setMessageRead(qint64 accountId, const QString &folderPath, qint64 uid, bool read)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("SetMessageRead"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(uid), read});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::setMessageStarred(qint64 accountId, const QString &folderPath, qint64 uid, bool starred)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("SetMessageStarred"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(uid), starred});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::moveMessage(qint64 accountId, const QString &folderPath, qint64 uid, const QString &destFolder)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("MoveMessage"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(uid), destFolder});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::deleteMessage(qint64 accountId, const QString &folderPath, qint64 uid)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("DeleteMessage"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(uid)});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::createFolder(qint64 accountId, const QString &name)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("CreateFolder"));
    msg.setArguments({QVariant::fromValue(accountId), name});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::renameFolder(qint64 accountId, const QString &oldName, const QString &newName)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("RenameFolder"));
    msg.setArguments({QVariant::fromValue(accountId), oldName, newName});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::deleteFolder(qint64 accountId, const QString &name)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("DeleteFolder"));
    msg.setArguments({QVariant::fromValue(accountId), name});

    QDBusConnection::sessionBus().asyncCall(msg);
}

void DaemonClient::loadBody(qint64 accountId, const QString &folderPath, qint64 uid)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("LoadBody"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(uid)});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, uid]() {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        if (!reply.isError()) {
            Q_EMIT bodyLoaded(uid, reply.value());
        } else {
            Q_EMIT bodyLoaded(uid, QStringLiteral("<p>Failed to load body</p>"));
        }
    });
}

void DaemonClient::listAttachments(qint64 accountId, const QString &folderPath, qint64 uid)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("ListAttachments"));
    msg.setArguments({QVariant::fromValue(accountId), folderPath, QVariant::fromValue(uid)});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, uid]() {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        if (!reply.isError()) {
            Q_EMIT attachmentsLoaded(uid, reply.value());
        } else {
            Q_EMIT attachmentsLoaded(uid, QStringLiteral("[]"));
        }
    });
}

bool DaemonClient::copyFile(const QString &srcPath, const QString &destPath)
{
    if (srcPath.isEmpty() || destPath.isEmpty()) {
        return false;
    }
    if (srcPath == destPath) {
        return true;
    }
    return QFile::copy(srcPath, destPath);
}

void DaemonClient::removeAccount(qint64 accountId)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("RemoveAccount"));
    msg.setArguments({QVariant::fromValue(accountId)});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, accountId]() {
        QDBusPendingReply<bool> reply = *watcher;
        watcher->deleteLater();
        if (!reply.isError() && reply.value()) {
            Q_EMIT accountRemoved(accountId);
        }
    });
}

void DaemonClient::sendEmail(
    qint64 accountId,
    const QString &to,
    const QString &cc,
    const QString &subject,
    const QString &body,
    const QString &replyFolderPath,
    qint64 replyUid,
    const QString &attachmentPaths
)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("SendEmail"));
    msg.setArguments({
        QVariant::fromValue(accountId),
        to,
        cc,
        subject,
        body,
        replyFolderPath,
        QVariant::fromValue(replyUid),
        attachmentPaths
    });

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        Q_EMIT emailSent(reply.isError() ? reply.error().message() : reply.value());
    });
}

void DaemonClient::onGenericReply(QDBusPendingCallWatcher *watcher, const QString &signal)
{
    QDBusPendingReply<QString> reply = *watcher;
    watcher->deleteLater();

    if (reply.isError()) {
        Q_EMIT accountFailed(QString(), reply.error().message());
        return;
    }

    if (signal == QStringLiteral("foldersLoaded")) {
        Q_EMIT foldersLoaded(reply.value());
    } else if (signal == QStringLiteral("messagesLoaded")) {
        Q_EMIT messagesLoaded(reply.value());
    }
}

void DaemonClient::searchAddresses(const QString &query)
{
    if (!m_available) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("SearchAddresses"));
    msg.setArguments({query});

    QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(msg);
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        QDBusPendingReply<QString> reply = *watcher;
        watcher->deleteLater();
        Q_EMIT addressResults(reply.isError() ? QStringLiteral("[]") : reply.value());
    });
}

bool DaemonClient::isKnownAddress(const QString &email)
{
    if (!m_available) return false;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        SERVICE, PATH, INTERFACE, QStringLiteral("IsKnownAddress"));
    msg.setArguments({email});

    QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 3000);
    if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
        return reply.arguments().at(0).toBool();
    }
    return false;
}
