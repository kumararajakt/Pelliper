#include "autodiscover.h"

#include <QNetworkRequest>
#include <QXmlStreamReader>
#include <QUrl>

Autodiscover::Autodiscover(QObject *parent)
    : QObject(parent)
    , m_nam(this)
{
}

void Autodiscover::discover(const QString &email)
{
    if (m_discovering) {
        return;
    }

    m_email = email;

    const int atIdx = email.indexOf(QLatin1Char('@'));
    if (atIdx < 0 || atIdx == email.length() - 1) {
        setStatus(tr("Invalid email address"));
        return;
    }

    m_domain = email.mid(atIdx + 1).toLower().trimmed();
    if (m_domain.isEmpty()) {
        setStatus(tr("Invalid email address"));
        return;
    }

    m_urls = {
        QStringLiteral("https://autoconfig.thunderbird.net/v1.1/%1").arg(m_domain),
        QStringLiteral("https://autoconfig.%1/mail/config-v1.1.xml").arg(m_domain),
        QStringLiteral("https://.%1/.well-known/autoconfig/mail/config-v1.1.xml").arg(m_domain),
    };
    m_urlIndex = 0;

    setStatus(tr("Looking up server settings for %1...").arg(m_domain));
    setDiscovering(true);

    tryNextUrl();
}

void Autodiscover::tryNextUrl()
{
    if (m_urlIndex >= m_urls.size()) {
        setDiscovering(false);
        setStatus(tr("Could not auto-detect server settings. Enter them manually."));
        Q_EMIT failed(m_status);
        return;
    }

    const QUrl url(m_urls.at(m_urlIndex));
    QNetworkRequest request(url);
    request.setTransferTimeout(5000);

    m_currentReply = m_nam.get(request);
    connect(m_currentReply, &QNetworkReply::finished, this, &Autodiscover::onReplyFinished);
}

void Autodiscover::onReplyFinished()
{
    if (!m_currentReply) {
        return;
    }

    QNetworkReply *reply = m_currentReply;
    m_currentReply = nullptr;
    reply->deleteLater();

    if (reply->error() == QNetworkReply::NoError) {
        const QByteArray data = reply->readAll();
        if (parseConfig(data)) {
            setDiscovering(false);
            return;
        }
    }

    m_urlIndex++;
    tryNextUrl();
}

bool Autodiscover::parseConfig(const QByteArray &data)
{
    QXmlStreamReader xml(data);

    QString imapHost, imapSecurity, smtpHost, smtpSecurity;
    int imapPort = 0, smtpPort = 0;

    auto socketToSecurity = [](const QString &socketType) -> QString {
        const QString lower = socketType.toLower();
        if (lower == QLatin1String("ssl")) return QStringLiteral("tls");
        if (lower == QLatin1String("starttls")) return QStringLiteral("starttls");
        return QStringLiteral("none");
    };

    while (!xml.atEnd()) {
        xml.readNext();
        if (!xml.isStartElement()) {
            continue;
        }

        const QStringView name = xml.name();

        if (name == QLatin1String("incomingServer")) {
            if (xml.attributes().value(QStringLiteral("type")) != QLatin1String("imap")) {
                continue;
            }
            while (!xml.atEnd()) {
                xml.readNext();
                if (xml.isEndElement() && xml.name() == QLatin1String("incomingServer")) {
                    break;
                }
                if (!xml.isStartElement()) {
                    continue;
                }
                const QStringView child = xml.name();
                const QString text = xml.readElementText();
                if (child == QLatin1String("hostname")) {
                    imapHost = text;
                } else if (child == QLatin1String("port")) {
                    imapPort = text.toInt();
                } else if (child == QLatin1String("socketType")) {
                    imapSecurity = socketToSecurity(text);
                }
            }
        } else if (name == QLatin1String("outgoingServer")) {
            if (xml.attributes().value(QStringLiteral("type")) != QLatin1String("smtp")) {
                continue;
            }
            while (!xml.atEnd()) {
                xml.readNext();
                if (xml.isEndElement() && xml.name() == QLatin1String("outgoingServer")) {
                    break;
                }
                if (!xml.isStartElement()) {
                    continue;
                }
                const QStringView child = xml.name();
                const QString text = xml.readElementText();
                if (child == QLatin1String("hostname")) {
                    smtpHost = text;
                } else if (child == QLatin1String("port")) {
                    smtpPort = text.toInt();
                } else if (child == QLatin1String("socketType")) {
                    smtpSecurity = socketToSecurity(text);
                }
            }
        }
    }

    if (xml.hasError()) {
        return false;
    }

    if (imapHost.isEmpty() || smtpHost.isEmpty()) {
        return false;
    }

    if (imapPort == 0) imapPort = 993;
    if (smtpPort == 0) smtpPort = 587;

    setStatus(tr("Server settings detected. You can review them on the next page."));
    Q_EMIT discovered(imapHost, imapPort, imapSecurity, smtpHost, smtpPort, smtpSecurity);
    return true;
}

void Autodiscover::setDiscovering(bool value)
{
    if (m_discovering == value) return;
    m_discovering = value;
    Q_EMIT discoveringChanged();
}

void Autodiscover::setStatus(const QString &value)
{
    if (m_status == value) return;
    m_status = value;
    Q_EMIT statusChanged();
}
