#pragma once

#include <QJsonObject>
#include <QLocalSocket>
#include <QObject>
#include <QString>

class DaemonClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

public:
    explicit DaemonClient(QObject *parent = nullptr);

    bool isConnected() const;
    QString statusText() const;

    Q_INVOKABLE void connectToDaemon();
    Q_INVOKABLE int sendRequest(const QString &method, const QJsonObject &params = {});

Q_SIGNALS:
    void connectedChanged();
    void statusTextChanged();
    void responseReceived(int id, const QJsonObject &result, const QJsonObject &error);
    void notificationReceived(const QString &method, const QJsonObject &params);

private Q_SLOTS:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onErrorOccurred(QLocalSocket::LocalSocketError socketError);

private:
    QString socketPath() const;
    void trySpawnDaemon();

    QLocalSocket *m_socket = nullptr;
    QByteArray m_readBuffer;
    bool m_connected = false;
    bool m_spawnAttempted = false;
    int m_nextId = 1;
    QString m_statusText = QStringLiteral("Connecting…");
};
