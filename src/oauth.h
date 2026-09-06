#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTcpServer>
#include <QTcpSocket>
#include <QtQml/qqmlregistration.h>
#include <QTimer>

struct OAuthProvider {
    QString id;
    QString name;
    QString authEndpoint;
    QString tokenEndpoint;
    QString clientId;
    QString clientSecret;
    QString scopes;
    QString imapHost;
    int imapPort;
    QString smtpHost;
    int smtpPort;
};

class OAuth2 : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool authenticating READ authenticating NOTIFY authenticatingChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString authUrl READ authUrl NOTIFY authUrlChanged)
    Q_PROPERTY(bool hasProvider READ hasProvider NOTIFY providerChanged)

public:
    explicit OAuth2(QObject *parent = nullptr);

    bool authenticating() const { return m_authenticating; }
    QString status() const { return m_status; }
    QString authUrl() const { return m_authUrl; }
    bool hasProvider() const { return !m_provider.id.isEmpty(); }

    Q_INVOKABLE void detectProvider(const QString &email);
    Q_INVOKABLE void startAuth();
    Q_INVOKABLE void cancel();

    static QVector<OAuthProvider> knownProviders();

Q_SIGNALS:
    void authenticatingChanged();
    void statusChanged();
    void authUrlChanged();
    void providerChanged();
    void authenticated(const QString &accessToken, const QString &refreshToken,
                       const QString &email, const QString &displayName);
    void failed(const QString &message);

private Q_SLOTS:
    void onTokenReply();
    void onNewConnection();

private:
    void setAuthenticating(bool value);
    void setStatus(const QString &value);
    void setAuthUrl(const QString &value);
    void exchangeCode(const QString &code);
    QString generateState();
    quint16 startCallbackServer();
    void stopCallbackServer();

    QNetworkAccessManager m_nam;
    QTcpServer m_callbackServer;
    QTcpSocket *m_pendingSocket = nullptr;
    QTimer m_timeout;

    bool m_authenticating = false;
    QString m_status;
    QString m_authUrl;
    QString m_email;
    QString m_displayName;
    OAuthProvider m_provider;
    QString m_state;
    quint16 m_callbackPort = 0;

    static constexpr const char *REDIRECT_PATH = "/oauth/callback";
    static constexpr int CALLBACK_TIMEOUT_MS = 120000;
};
