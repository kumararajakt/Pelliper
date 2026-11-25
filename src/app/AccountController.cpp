#include "AccountController.h"
#include "../ipc/DaemonClient.h"

AccountController::AccountController(DaemonClient *client, QObject *parent)
    : QObject(parent)
    , m_client(client)
{
    connect(m_client, &DaemonClient::responseReceived, this, &AccountController::onResponse);
    connect(m_client, &DaemonClient::notificationReceived, this, &AccountController::onNotification);
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
    Q_EMIT busyChanged();
}

void AccountController::setError(const QString &err)
{
    if (m_errorMessage == err) {
        return;
    }
    m_errorMessage = err;
    Q_EMIT errorMessageChanged();
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

void AccountController::startOAuth(const QString &provider, const QString &email)
{
    setError({});
    QJsonObject params;
    params.insert(QStringLiteral("provider"), provider.isEmpty() ? QStringLiteral("google") : provider);
    params.insert(QStringLiteral("email"), email.trimmed());
    m_oauthReqId = m_client->sendRequest(QStringLiteral("account.oauth_start"), params);
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
            Q_EMIT accountsChanged();
        }
        return;
    }

    if (id == m_autoconfigReqId) {
        m_autoconfigReqId = -1;
        setBusy(false);
        const bool found = error.isEmpty() && result.value(QStringLiteral("found")).toBool();
        Q_EMIT autoconfigCompleted(found, result.value(QStringLiteral("config")).toObject());
        return;
    }

    if (id == m_oauthReqId) {
        m_oauthReqId = -1;
        if (error.isEmpty()) {
            m_oauthSessionId = result.value(QStringLiteral("session_id")).toString();
            Q_EMIT oauthUrlReady(result.value(QStringLiteral("auth_url")).toString());
        } else {
            setError(error.value(QStringLiteral("message")).toString());
        }
        return;
    }

    if (id == m_addReqId) {
        m_addReqId = -1;
        setBusy(false);
        if (!error.isEmpty()) {
            const QString msg = error.value(QStringLiteral("message")).toString(QStringLiteral("Connection failed"));
            setError(msg);
            Q_EMIT accountVerifyFailed(msg);
        } else {
            refreshAccounts();
            Q_EMIT accountAdded(result.value(QStringLiteral("account")).toObject());
        }
    }
}

void AccountController::onNotification(const QString &method, const QJsonObject &params)
{
    if (method != QStringLiteral("oauth.completed")) {
        return;
    }
    if (!m_oauthSessionId.isEmpty() && params.value(QStringLiteral("session_id")).toString() != m_oauthSessionId) {
        return;
    }
    m_oauthSessionId.clear();
    const bool ok = params.value(QStringLiteral("success")).toBool();
    Q_EMIT oauthCompleted(
        ok,
        params.value(QStringLiteral("access_token")).toString(),
        params.value(QStringLiteral("refresh_token")).toString(),
        params.value(QStringLiteral("expires_at")).toInteger(),
        params.value(QStringLiteral("error")).toString());
}
