#include "DaemonClient.h"

#include <QCoreApplication>
#include <QDir>
#include <QJsonDocument>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>

DaemonClient::DaemonClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QLocalSocket(this))
{
    connect(m_socket, &QLocalSocket::connected, this, &DaemonClient::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &DaemonClient::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead, this, &DaemonClient::onReadyRead);
    connect(m_socket, &QLocalSocket::errorOccurred, this, &DaemonClient::onErrorOccurred);
}

bool DaemonClient::isConnected() const
{
    return m_connected;
}

QString DaemonClient::statusText() const
{
    return m_statusText;
}

QString DaemonClient::socketPath() const
{
    const QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR", QDir::tempPath());
    return runtimeDir + QStringLiteral("/pelliper/daemon.sock");
}

void DaemonClient::connectToDaemon()
{
    if (m_socket->state() == QLocalSocket::ConnectedState
        || m_socket->state() == QLocalSocket::ConnectingState) {
        return;
    }

    m_statusText = QStringLiteral("Connecting…");
    emit statusTextChanged();
    m_socket->connectToServer(socketPath());
}

void DaemonClient::sendRequest(const QString &method, const QJsonObject &params)
{
    if (!m_connected) {
        return;
    }

    QJsonObject req;
    req.insert(QStringLiteral("jsonrpc"), QStringLiteral("2.0"));
    req.insert(QStringLiteral("id"), m_nextId++);
    req.insert(QStringLiteral("method"), method);
    req.insert(QStringLiteral("params"), params);

    QByteArray line = QJsonDocument(req).toJson(QJsonDocument::Compact);
    line.append('\n');
    m_socket->write(line);
}

void DaemonClient::onConnected()
{
    m_connected = true;
    m_spawnAttempted = false;
    m_statusText = QStringLiteral("Connected");
    emit connectedChanged();
    emit statusTextChanged();
    sendRequest(QStringLiteral("daemon.status"));
}

void DaemonClient::onDisconnected()
{
    if (m_connected) {
        m_connected = false;
        emit connectedChanged();
    }
    m_statusText = QStringLiteral("Disconnected");
    emit statusTextChanged();

    QTimer::singleShot(2000, this, &DaemonClient::connectToDaemon);
}

void DaemonClient::onErrorOccurred(QLocalSocket::LocalSocketError)
{
    if (!m_spawnAttempted) {
        m_spawnAttempted = true;
        trySpawnDaemon();
    }
    m_statusText = QStringLiteral("Daemon offline");
    emit statusTextChanged();
    QTimer::singleShot(1500, this, &DaemonClient::connectToDaemon);
}

void DaemonClient::trySpawnDaemon()
{
    QString bin = QStandardPaths::findExecutable(QStringLiteral("pelliper-daemon"));
    if (bin.isEmpty()) {
        const QString devPath = QCoreApplication::applicationDirPath()
            + QStringLiteral("/../daemon/target/debug/pelliper-daemon");
        if (QFileInfo::exists(devPath)) {
            bin = devPath;
        }
    }
    if (!bin.isEmpty()) {
        QProcess::startDetached(bin, {});
    }
}

void DaemonClient::onReadyRead()
{
    m_readBuffer.append(m_socket->readAll());
    while (true) {
        const int idx = m_readBuffer.indexOf('\n');
        if (idx < 0) {
            break;
        }
        const QByteArray line = m_readBuffer.left(idx).trimmed();
        m_readBuffer.remove(0, idx + 1);
        if (line.isEmpty()) {
            continue;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(line);
        if (!doc.isObject()) {
            continue;
        }
        const QJsonObject obj = doc.object();
        if (obj.contains(QStringLiteral("id"))) {
            emit responseReceived(
                obj.value(QStringLiteral("id")).toInt(),
                obj.value(QStringLiteral("result")).toObject(),
                obj.value(QStringLiteral("error")).toObject());
        } else if (obj.contains(QStringLiteral("method"))) {
            emit notificationReceived(
                obj.value(QStringLiteral("method")).toString(),
                obj.value(QStringLiteral("params")).toObject());
        }
    }
}
