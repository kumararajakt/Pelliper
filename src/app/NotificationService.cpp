#include "NotificationService.h"
#include "../ipc/DaemonClient.h"

#include <KLocalizedString>
#include <KNotification>
#include <QJsonArray>

NotificationService::NotificationService(DaemonClient *client, QObject *parent)
    : QObject(parent)
{
    connect(client, &DaemonClient::notificationReceived, this, &NotificationService::onNotification);
}

void NotificationService::onNotification(const QString &method, const QJsonObject &params)
{
    if (method != QStringLiteral("message.new")) {
        return;
    }

    const QJsonArray summaries = params.value(QStringLiteral("summaries")).toArray();
    if (summaries.isEmpty()) {
        return;
    }

    const QJsonObject first = summaries.first().toObject();
    const QString subject = first.value(QStringLiteral("subject")).toString(i18n("New email"));
    const QString snippet = first.value(QStringLiteral("snippet")).toString();

    auto *notif = new KNotification(QStringLiteral("new-mail"), KNotification::CloseOnTimeout, this);
    notif->setTitle(summaries.size() > 1
                        ? i18np("1 new message", "%1 new messages", summaries.size())
                        : subject);
    notif->setText(snippet.isEmpty() ? subject : snippet);
    notif->setIconName(QStringLiteral("mail-receive"));

    auto *openAction = notif->addAction(i18n("Open"));
    connect(openAction, &KNotificationAction::activated, this, &NotificationService::openWindowRequested);

    notif->sendEvent();
}
