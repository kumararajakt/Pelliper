#include "daemonclient.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingReply>

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
    const QString &authToken
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
         << authType << authToken;
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
