#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QtQml/qqmlregistration.h>

class Autodiscover : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool discovering READ discovering NOTIFY discoveringChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit Autodiscover(QObject *parent = nullptr);

    bool discovering() const { return m_discovering; }
    QString status() const { return m_status; }

    Q_INVOKABLE void discover(const QString &email);

Q_SIGNALS:
    void discoveringChanged();
    void statusChanged();
    void discovered(const QString &imapHost, int imapPort, const QString &imapSecurity,
                    const QString &smtpHost, int smtpPort, const QString &smtpSecurity);
    void failed(const QString &message);

private Q_SLOTS:
    void onReplyFinished();

private:
    void tryNextUrl();
    void setDiscovering(bool value);
    void setStatus(const QString &value);
    bool parseConfig(const QByteArray &data);

    QNetworkAccessManager m_nam;
    bool m_discovering = false;
    QString m_status;
    QString m_email;
    QString m_domain;
    QStringList m_urls;
    int m_urlIndex = 0;
    QNetworkReply *m_currentReply = nullptr;
};
