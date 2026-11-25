#pragma once

#include <QJsonObject>
#include <QObject>

class DaemonClient;

class NotificationService : public QObject
{
    Q_OBJECT

public:
    explicit NotificationService(DaemonClient *client, QObject *parent = nullptr);

Q_SIGNALS:
    void openWindowRequested();

private Q_SLOTS:
    void onNotification(const QString &method, const QJsonObject &params);
};
