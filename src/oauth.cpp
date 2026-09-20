#include "oauth.h"

#include <QDesktopServices>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QUuid>
#include <QSslSocket>
#include <QCoreApplication>

OAuth2::OAuth2(QObject *parent)
    : QObject(parent)
    , m_nam(this)
{
    connect(&m_callbackServer, &QTcpServer::newConnection, this, &OAuth2::onNewConnection);

    m_timeout.setSingleShot(true);
    m_timeout.setInterval(CALLBACK_TIMEOUT_MS);
    connect(&m_timeout, &QTimer::timeout, this, &OAuth2::cancel);
}

QVector<OAuthProvider> OAuth2::knownProviders()
{
    const QString googleClientId = qEnvironmentVariable("PELLIPER_GOOGLE_CLIENT_ID");
    const QString googleClientSecret = qEnvironmentVariable("PELLIPER_GOOGLE_CLIENT_SECRET");
    const QString microsoftClientId = qEnvironmentVariable("PELLIPER_MICROSOFT_CLIENT_ID");
    const QString microsoftClientSecret = qEnvironmentVariable("PELLIPER_MICROSOFT_CLIENT_SECRET");

    return {
        {
            QStringLiteral("google"),
            QStringLiteral("Google / Gmail"),
            QStringLiteral("https://accounts.google.com/o/oauth2/v2/auth"),
            QStringLiteral("https://oauth2.googleapis.com/token"),
            googleClientId,
            googleClientSecret,
            QStringLiteral("https://mail.google.com/ https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"),
            QStringLiteral("imap.gmail.com"),
            993,
            QStringLiteral("smtp.gmail.com"),
            465,
        },
        {
            QStringLiteral("microsoft"),
            QStringLiteral("Microsoft / Outlook"),
            QStringLiteral("https://login.microsoftonline.com/common/oauth2/v2.0/authorize"),
            QStringLiteral("https://login.microsoftonline.com/common/oauth2/v2.0/token"),
            microsoftClientId,
            microsoftClientSecret,
            QStringLiteral("https://outlook.office365.com/IMAP.AccessAsUser.All https://outlook.office365.com/SMTP.Send offline_access"),
            QStringLiteral("outlook.office365.com"),
            993,
            QStringLiteral("smtp.office365.com"),
            587,
        },
    };
}

void OAuth2::detectProvider(const QString &email)
{
    qWarning() << "OAuth2::detectProvider" << email;
    m_email = email;

    const int atIdx = email.indexOf(QLatin1Char('@'));
    if (atIdx < 0) {
        m_provider = {};
        Q_EMIT providerChanged();
        return;
    }

    const QString domain = email.mid(atIdx + 1).toLower();
    const auto providers = knownProviders();

    for (const auto &p : providers) {
        if (domain == QLatin1String("gmail.com") || domain == QLatin1String("googlemail.com")) {
            if (p.id == QLatin1String("google")) {
                m_provider = p;
                Q_EMIT providerChanged();
                return;
            }
        }
        if (domain == QLatin1String("outlook.com") || domain == QLatin1String("hotmail.com")
            || domain.endsWith(QLatin1String(".onmicrosoft.com"))) {
            if (p.id == QLatin1String("microsoft")) {
                m_provider = p;
                Q_EMIT providerChanged();
                return;
            }
        }
    }

    m_provider = {};
    Q_EMIT providerChanged();
}

void OAuth2::startAuth()
{
    if (m_authenticating) {
        return;
    }

    if (m_provider.id.isEmpty()) {
        Q_EMIT failed(tr("No OAuth provider configured for this email domain."));
        return;
    }

    if (m_provider.clientId.isEmpty() || m_provider.clientId.contains(QLatin1String("fake-for-dev"))) {
        Q_EMIT failed(tr("OAuth client ID not configured. Set PELLIPER_%1_CLIENT_ID environment variable.")
                       .arg(m_provider.id.toUpper()));
        return;
    }

    if (!QSslSocket::supportsSsl()) {
        Q_EMIT failed(tr("SSL support is not available. Cannot proceed with OAuth."));
        return;
    }

    const quint16 port = startCallbackServer();
    if (port == 0) {
        Q_EMIT failed(tr("Could not start local callback server."));
        return;
    }

    m_state = generateState();
    m_callbackPort = port;

    QUrl authUrl(m_provider.authEndpoint);
    QUrlQuery params;
    params.addQueryItem(QStringLiteral("client_id"), m_provider.clientId);
    params.addQueryItem(QStringLiteral("redirect_uri"),
                        QStringLiteral("http://127.0.0.1:%1%2").arg(port).arg(QLatin1String(REDIRECT_PATH)));
    params.addQueryItem(QStringLiteral("response_type"), QStringLiteral("code"));
    params.addQueryItem(QStringLiteral("scope"), m_provider.scopes);
    params.addQueryItem(QStringLiteral("state"), m_state);
    params.addQueryItem(QStringLiteral("login_hint"), m_email);
    params.addQueryItem(QStringLiteral("prompt"), QStringLiteral("select_account"));
    params.addQueryItem(QStringLiteral("access_type"), QStringLiteral("offline"));
    authUrl.setQuery(params);

    setStatus(tr("Opening browser for authentication..."));
    setAuthenticating(true);

    QDesktopServices::openUrl(authUrl);

    m_timeout.start();
}

void OAuth2::cancel()
{
    m_timeout.stop();
    stopCallbackServer();
    setAuthenticating(false);
    setStatus(tr("Authentication cancelled."));
    Q_EMIT failed(tr("Authentication was cancelled or timed out."));
}

void OAuth2::onNewConnection()
{
    m_timeout.stop();

    if (!m_callbackServer.hasPendingConnections()) {
        return;
    }

    QTcpSocket *socket = m_callbackServer.nextPendingConnection();
    m_pendingSocket = socket;

    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        const QByteArray data = socket->readAll();
        const QString request = QString::fromUtf8(data);

        const QString path = request.section(QLatin1Char(' '), 1, 1).section(QLatin1Char(' '), 0, 0);

        if (!path.startsWith(QLatin1String(REDIRECT_PATH))) {
            const QByteArray response =
                "HTTP/1.1 404 Not Found\r\n"
                "Content-Length: 0\r\n"
                "\r\n";
            socket->write(response);
            socket->disconnectFromHost();
            return;
        }

        const int queryStart = path.indexOf(QLatin1Char('?'));
        if (queryStart < 0) {
            const QByteArray response =
                "HTTP/1.1 400 Bad Request\r\n"
                "Content-Length: 0\r\n"
                "\r\n";
            socket->write(response);
            socket->disconnectFromHost();
            return;
        }

        const QString queryString = path.mid(queryStart + 1);
        QUrlQuery query(queryString);

        const QString returnedState = query.queryItemValue(QStringLiteral("state"));
        const QString code = query.queryItemValue(QStringLiteral("code"));
        const QString error = query.queryItemValue(QStringLiteral("error"));

        if (returnedState != m_state) {
            const QByteArray response =
                "HTTP/1.1 400 Bad Request\r\n"
                "Content-Type: text/html\r\n"
                "Content-Length: 52\r\n"
                "\r\n"
                "<html><body><h2>State mismatch</h2></body></html>";
            socket->write(response);
            socket->disconnectFromHost();
            setStatus(tr("Authentication failed: state mismatch."));
            setAuthenticating(false);
            Q_EMIT failed(tr("Security state mismatch. Please try again."));
            return;
        }

        if (!error.isEmpty()) {
            const QByteArray html = QStringLiteral(
                "<html><body><h2>Authentication failed</h2><p>Error: %1</p></body></html>")
                                        .arg(error.toHtmlEscaped())
                                        .toUtf8();
            const QByteArray response = "HTTP/1.1 200 OK\r\n"
                                        "Content-Type: text/html\r\n"
                                        "Content-Length: " + QByteArray::number(html.size()) + "\r\n"
                                        "\r\n" + html;
            socket->write(response);
            socket->disconnectFromHost();
            setStatus(tr("Authentication failed: %1").arg(error));
            setAuthenticating(false);
            Q_EMIT failed(tr("Authentication failed: %1").arg(error));
            return;
        }

        if (!code.isEmpty()) {
            const QByteArray html =
                "<html><body><h2>Authentication successful</h2>"
                "<p>You can close this window and return to Pelliper.</p>"
                "</body></html>";
            const QByteArray response = "HTTP/1.1 200 OK\r\n"
                                        "Content-Type: text/html\r\n"
                                        "Content-Length: " + QByteArray::number(html.size()) + "\r\n"
                                        "\r\n" + html;
            socket->write(response);
            socket->disconnectFromHost();

            setStatus(tr("Exchanging authorization code..."));
            exchangeCode(code);
            return;
        }

        const QByteArray response =
            "HTTP/1.1 400 Bad Request\r\n"
            "Content-Length: 0\r\n"
            "\r\n";
        socket->write(response);
        socket->disconnectFromHost();
        setStatus(tr("No authorization code received."));
        setAuthenticating(false);
        Q_EMIT failed(tr("No authorization code received."));
    });
}

void OAuth2::exchangeCode(const QString &code)
{
    QUrl url(m_provider.tokenEndpoint);
    QUrlQuery params;
    params.addQueryItem(QStringLiteral("code"), code);
    params.addQueryItem(QStringLiteral("client_id"), m_provider.clientId);
    if (!m_provider.clientSecret.isEmpty()) {
        params.addQueryItem(QStringLiteral("client_secret"), m_provider.clientSecret);
    }
    params.addQueryItem(QStringLiteral("redirect_uri"),
                        QStringLiteral("http://127.0.0.1:%1%2").arg(m_callbackPort).arg(QLatin1String(REDIRECT_PATH)));
    params.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("authorization_code"));

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/x-www-form-urlencoded"));

    QNetworkReply *reply = m_nam.post(request, params.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, &OAuth2::onTokenReply);
}

void OAuth2::onTokenReply()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) {
        return;
    }
    reply->deleteLater();

    stopCallbackServer();

    if (reply->error() != QNetworkReply::NoError) {
        const QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        QString errorMsg = tr("Token exchange failed.");
        if (doc.isObject()) {
            const QJsonObject obj = doc.object();
            if (obj.contains(QStringLiteral("error_description"))) {
                errorMsg = obj.value(QStringLiteral("error_description")).toString();
            } else if (obj.contains(QStringLiteral("error"))) {
                errorMsg = obj.value(QStringLiteral("error")).toString();
            }
        }
        setAuthenticating(false);
        setStatus(errorMsg);
        Q_EMIT failed(errorMsg);
        return;
    }

    const QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        setAuthenticating(false);
        setStatus(tr("Invalid token response."));
        Q_EMIT failed(tr("Invalid token response."));
        return;
    }

    const QJsonObject obj = doc.object();
    const QString accessToken = obj.value(QStringLiteral("access_token")).toString();
    const QString refreshToken = obj.value(QStringLiteral("refresh_token")).toString();

    if (accessToken.isEmpty()) {
        setAuthenticating(false);
        setStatus(tr("No access token received."));
        Q_EMIT failed(tr("No access token received."));
        return;
    }

    setStatus(tr("Authentication successful!"));
    setAuthenticating(false);
    qWarning() << "OAuth2 emitting authenticated:" << m_email << m_displayName;
    Q_EMIT authenticated(accessToken, refreshToken, m_email, m_displayName);
}

quint16 OAuth2::startCallbackServer()
{
    if (m_callbackServer.isListening()) {
        m_callbackServer.close();
    }

    if (!m_callbackServer.listen(QHostAddress::LocalHost, 0)) {
        return 0;
    }

    return m_callbackServer.serverPort();
}

void OAuth2::stopCallbackServer()
{
    if (m_callbackServer.isListening()) {
        m_callbackServer.close();
    }
    if (m_pendingSocket) {
        m_pendingSocket->deleteLater();
        m_pendingSocket = nullptr;
    }
}

QString OAuth2::generateState()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void OAuth2::setAuthenticating(bool value)
{
    if (m_authenticating == value) return;
    m_authenticating = value;
    Q_EMIT authenticatingChanged();
}

void OAuth2::setStatus(const QString &value)
{
    if (m_status == value) return;
    m_status = value;
    Q_EMIT statusChanged();
}
