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

    Q_INVOKABLE void syncAll();
    Q_INVOKABLE void setIdleFolder(qint64 accountId, const QString &folderPath);
    Q_INVOKABLE void setMessageRead(qint64 accountId, const QString &folderPath, qint64 uid, bool read);
    Q_INVOKABLE void setMessageStarred(qint64 accountId, const QString &folderPath, qint64 uid, bool starred);
    Q_INVOKABLE void moveMessage(qint64 accountId, const QString &folderPath, qint64 uid, const QString &destFolder);
    Q_INVOKABLE void deleteMessage(qint64 accountId, const QString &folderPath, qint64 uid);
    Q_INVOKABLE void searchAddresses(const QString &query);
    Q_INVOKABLE bool isKnownAddress(const QString &email);
    Q_INVOKABLE void blockSender(const QString &email);
    Q_INVOKABLE void unblockSender(const QString &email);
    Q_INVOKABLE void loadSenderPolicies();
    Q_INVOKABLE QString gravatarUrl(const QString &email, int size = 80);
    Q_INVOKABLE void loadBody(qint64 accountId, const QString &folderPath, qint64 uid);
    Q_INVOKABLE void listAttachments(qint64 accountId, const QString &folderPath, qint64 uid);
    Q_INVOKABLE bool copyFile(const QString &srcPath, const QString &destPath);
    Q_INVOKABLE void removeAccount(qint64 accountId);
    Q_INVOKABLE void sendEmail(
        qint64 accountId,
        const QString &to,
        const QString &cc,
        const QString &subject,
        const QString &body,
        const QString &replyFolderPath = QString(),
        qint64 replyUid = 0,
        const QString &attachmentPaths = QString()
    );

Q_SIGNALS:
    void availableChanged();
    void busyChanged();
    void accountAdded(const QString &email);
    void accountFailed(const QString &email, const QString &error);
    void bodyLoaded(qint64 uid, const QString &html);
    void attachmentsLoaded(qint64 uid, const QString &json);
    void accountRemoved(qint64 accountId);
    void emailSent(const QString &error);
    void addressResults(const QString &json);
    void senderPoliciesLoaded(const QString &json);

private Q_SLOTS:
    void onAddAccountReply(QDBusPendingCallWatcher *watcher);

private:
    void setAvailable(bool value);
    void setBusy(bool value);

    QDBusInterface m_iface;
    bool m_available = false;
    bool m_busy = false;
};
