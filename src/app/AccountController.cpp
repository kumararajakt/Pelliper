#include "AccountController.h"
#include "../ipc/DaemonClient.h"

AccountController::AccountController(DaemonClient *client, QObject *parent)
    : QObject(parent)
    , m_client(client)
{
    connect(m_client, &DaemonClient::responseReceived, this, &AccountController::onResponse);
    connect(m_client, &DaemonClient::connectedChanged, this, [this]() {
        if (m_client->isConnected()) {
            refreshAccounts();
        }
    });
}

void AccountController::setBusy(bool b)
{
    if (m_busy == b) {
        return;
    }
    m_busy = b;
    emit busyChanged();
}

void AccountController::setError(const QString &err)
{
    if (m_errorMessage == err) {
        return;
    }
    m_errorMessage = err;
    emit errorMessageChanged();
}

void AccountController::refreshAccounts()
{
    m_listReqId = m_client->sendRequest(QStringLiteral("account.list"));
}

void AccountController::lookupAutoconfig(const QString &email)
{
    setError({});
    setBusy(true);
    QJsonObject params;
    params.insert(QStringLiteral("email"), email.trimmed());
    m_autoconfigReqId = m_client->sendRequest(QStringLiteral("account.autoconfig"), params);
}

void AccountController::testAndAddAccount(const QJsonObject &params)
{
    setError({});
    setBusy(true);
    m_addReqId = m_client->sendRequest(QStringLiteral("account.test_and_add"), params);
}

void AccountController::clearAccountCache(qint64 accountId)
{
    QJsonObject params;
    params.insert(QStringLiteral("account_id"), accountId);
    m_client->sendRequest(QStringLiteral("account.clear_cache"), params);
}

void AccountController::removeAccount(qint64 accountId)
{
    QJsonObject params;
    params.insert(QStringLiteral("account_id"), accountId);
    m_client->sendRequest(QStringLiteral("account.remove"), params);
    refreshAccounts();
}

void AccountController::onResponse(int id, const QJsonObject &result, const QJsonObject &error)
{
    if (id == m_listReqId) {
        m_listReqId = -1;
        if (error.isEmpty()) {
            m_accounts = result.value(QStringLiteral("accounts")).toArray();
            emit accountsChanged();
        }
        return;
    }

    if (id == m_autoconfigReqId) {
        m_autoconfigReqId = -1;
        setBusy(false);
        const bool found = error.isEmpty() && result.value(QStringLiteral("found")).toBool();
        emit autoconfigCompleted(found, result.value(QStringLiteral("config")).toObject());
        return;
    }

    if (id == m_addReqId) {
        m_addReqId = -1;
        setBusy(false);
        if (!error.isEmpty()) {
            const QString msg = error.value(QStringLiteral("message")).toString(QStringLiteral("Connection failed"));
            setError(msg);
            emit accountVerifyFailed(msg);
        } else {
            refreshAccounts();
            emit accountAdded(result.value(QStringLiteral("account")).toObject());
        }
    }
}
