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
        const QString &authToken,
        const QString &refreshToken = QString()
    );

    Q_INVOKABLE void getFolders(qint64 accountId);
    Q_INVOKABLE void getMessages(qint64 accountId, const QString &folderPath, qint64 offset, qint64 limit);
    Q_INVOKABLE void countMessages(qint64 accountId, const QString &folderPath);
    Q_INVOKABLE void syncAll();
    Q_INVOKABLE void setIdleFolder(qint64 accountId, const QString &folderPath);

Q_SIGNALS:
    void availableChanged();
    void busyChanged();
    void accountAdded(const QString &email);
    void accountFailed(const QString &email, const QString &error);
    void foldersLoaded(const QString &json);
    void messagesLoaded(const QString &json);
    void messageCountLoaded(qint64 count);
    void syncAllFinished(bool success);

private Q_SLOTS:
    void onAddAccountReply(QDBusPendingCallWatcher *watcher);
    void onGenericReply(QDBusPendingCallWatcher *watcher, const QString &signal);

private:
    void setAvailable(bool value);
    void setBusy(bool value);

    QDBusInterface m_iface;
    bool m_available = false;
    bool m_busy = false;
};
