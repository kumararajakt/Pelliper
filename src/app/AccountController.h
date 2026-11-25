#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QString>

class DaemonClient;

class AccountController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(int accountCount READ accountCount NOTIFY accountsChanged)

public:
    explicit AccountController(DaemonClient *client, QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    QString errorMessage() const { return m_errorMessage; }
    int accountCount() const { return m_accounts.size(); }

    Q_INVOKABLE void refreshAccounts();
    Q_INVOKABLE void lookupAutoconfig(const QString &email);
    Q_INVOKABLE void testAndAddAccount(const QJsonObject &params);
    Q_INVOKABLE void clearAccountCache(qint64 accountId);
    Q_INVOKABLE void removeAccount(qint64 accountId);

Q_SIGNALS:
    void busyChanged();
    void errorMessageChanged();
    void accountsChanged();
    void autoconfigCompleted(bool found, const QJsonObject &config);
    void accountAdded(const QJsonObject &account);
    void accountVerifyFailed(const QString &error);

private Q_SLOTS:
    void onResponse(int id, const QJsonObject &result, const QJsonObject &error);

private:
    void setBusy(bool b);
    void setError(const QString &err);

    DaemonClient *m_client = nullptr;
    bool m_busy = false;
    QString m_errorMessage;
    QJsonArray m_accounts;

    int m_listReqId = -1;
    int m_autoconfigReqId = -1;
    int m_addReqId = -1;
};
