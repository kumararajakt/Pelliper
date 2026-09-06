#pragma once

#include <QObject>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QtQml/qqmlregistration.h>

class DaemonClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit DaemonClient(QObject *parent = nullptr);

    bool available() const { return m_available; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE void addAccount(
        const QString &email,
        const QString &displayName,
        const QString &imapHost,
        int imapPort,
        const QString &smtpHost,
        int smtpPort,
        const QString &authType,
        const QString &authToken
    );

Q_SIGNALS:
    void availableChanged();
    void busyChanged();
    void accountAdded(const QString &email);
    void accountFailed(const QString &email, const QString &error);

private Q_SLOTS:
    void onAddAccountReply(QDBusPendingCallWatcher *watcher);

private:
    void setAvailable(bool value);
    void setBusy(bool value);

    QDBusInterface m_iface;
    bool m_available = false;
    bool m_busy = false;
};
