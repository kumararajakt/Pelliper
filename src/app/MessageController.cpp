#include "MessageController.h"
#include "../ipc/DaemonClient.h"

#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QJsonDocument>

MessageController::MessageController(DaemonClient *client, QObject *parent)
    : QObject(parent)
    , m_client(client)
{
    connect(m_client, &DaemonClient::responseReceived, this, &MessageController::onResponse);
    connect(m_client, &DaemonClient::notificationReceived, this, &MessageController::onNotification);
}

void MessageController::openMessage(qint64 accountId, qint64 messageId)
{
    m_accountId = accountId;
    m_messageId = messageId;
    QJsonObject params;
    params.insert(QStringLiteral("account_id"), accountId);
    params.insert(QStringLiteral("message_id"), messageId);
    m_getReqId = m_client->sendRequest(QStringLiteral("message.get"), params);
}

void MessageController::toggleRead(qint64 messageId, bool markRead)
{
    QJsonObject params;
    params.insert(QStringLiteral("message_id"), messageId);
    params.insert(QStringLiteral("add_mask"), markRead ? 1 : 0);
    params.insert(QStringLiteral("remove_mask"), markRead ? 0 : 1);
    m_client->sendRequest(QStringLiteral("message.set_flags"), params);

    if (m_messageId == messageId) {
        m_unread = !markRead;
        Q_EMIT messageChanged();
    }
}

void MessageController::toggleStar(qint64 messageId, bool star)
{
    QJsonObject params;
    params.insert(QStringLiteral("message_id"), messageId);
    params.insert(QStringLiteral("add_mask"), star ? 2 : 0);
    params.insert(QStringLiteral("remove_mask"), star ? 0 : 2);
    m_client->sendRequest(QStringLiteral("message.set_flags"), params);

    if (m_messageId == messageId) {
        m_starred = star;
        Q_EMIT messageChanged();
    }
}

void MessageController::archiveMessage(qint64 messageId)
{
    QJsonObject params;
    params.insert(QStringLiteral("message_id"), messageId);
    m_client->sendRequest(QStringLiteral("message.archive"), params);
    if (m_messageId == messageId) {
        m_messageId = 0;
        Q_EMIT messageChanged();
    }
    Q_EMIT messageRemoved(messageId);
}

void MessageController::deleteMessage(qint64 messageId)
{
    QJsonObject params;
    params.insert(QStringLiteral("message_id"), messageId);
    m_client->sendRequest(QStringLiteral("message.delete"), params);
    if (m_messageId == messageId) {
        m_messageId = 0;
        Q_EMIT messageChanged();
    }
    Q_EMIT messageRemoved(messageId);
}

void MessageController::sendMessage(qint64 accountId,
                                    const QString &to,
                                    const QString &cc,
                                    const QString &bcc,
                                    const QString &subject,
                                    const QString &body,
                                    const QVariantList &attachments)
{
    QJsonObject params;
    params.insert(QStringLiteral("account_id"), accountId);
    params.insert(QStringLiteral("to"), to);
    params.insert(QStringLiteral("cc"), cc);
    params.insert(QStringLiteral("bcc"), bcc);
    params.insert(QStringLiteral("subject"), subject);
    params.insert(QStringLiteral("body"), body);
    params.insert(QStringLiteral("attachments"), QJsonArray::fromVariantList(attachments));
    m_client->sendRequest(QStringLiteral("message.send"), params);
}

void MessageController::openAttachment(qint64 attachmentId)
{
    QJsonObject params;
    params.insert(QStringLiteral("attachment_id"), attachmentId);
    const int reqId = m_client->sendRequest(QStringLiteral("attachment.get"), params);
    if (reqId > 0) {
        m_pendingAttAction.insert(reqId, QStringLiteral("__OPEN__"));
    }
}

void MessageController::saveAttachmentAs(qint64 attachmentId, const QUrl &destFileUrl)
{
    const QString destPath = destFileUrl.toLocalFile();
    if (destPath.isEmpty()) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("attachment_id"), attachmentId);
    const int reqId = m_client->sendRequest(QStringLiteral("attachment.get"), params);
    if (reqId > 0) {
        m_pendingAttAction.insert(reqId, destPath);
    }
}

void MessageController::saveAllAttachments(const QUrl &destDirUrl)
{
    const QString dirPath = destDirUrl.toLocalFile();
    if (dirPath.isEmpty()) {
        return;
    }
    const QDir dir(dirPath);
    for (const QVariant &v : std::as_const(m_attachments)) {
        const QVariantMap m = v.toMap();
        if (m.value(QStringLiteral("is_inline")).toBool()) {
            continue;
        }
        const qint64 attId = m.value(QStringLiteral("id")).toLongLong();
        const QString fname = m.value(QStringLiteral("filename"), QStringLiteral("attachment")).toString();
        QJsonObject params;
        params.insert(QStringLiteral("attachment_id"), attId);
        const int reqId = m_client->sendRequest(QStringLiteral("attachment.get"), params);
        if (reqId > 0) {
            m_pendingAttAction.insert(reqId, dir.filePath(fname));
        }
    }
}

void MessageController::saveDraft(qint64 draftId,
                                  qint64 accountId,
                                  const QString &to,
                                  const QString &cc,
                                  const QString &bcc,
                                  const QString &subject,
                                  const QString &body)
{
    QJsonObject params;
    if (draftId > 0) {
        params.insert(QStringLiteral("draft_id"), draftId);
    }
    params.insert(QStringLiteral("account_id"), accountId);
    params.insert(QStringLiteral("to"), to);
    params.insert(QStringLiteral("cc"), cc);
    params.insert(QStringLiteral("bcc"), bcc);
    params.insert(QStringLiteral("subject"), subject);
    params.insert(QStringLiteral("body"), body);
    m_draftSaveReqId = m_client->sendRequest(QStringLiteral("draft.save"), params);
}

void MessageController::discardDraft(qint64 draftId)
{
    if (draftId <= 0) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("draft_id"), draftId);
    m_client->sendRequest(QStringLiteral("draft.discard"), params);
}

void MessageController::onResponse(int id, const QJsonObject &result, const QJsonObject &error)
{
    if (id == m_draftSaveReqId) {
        m_draftSaveReqId = -1;
        if (error.isEmpty()) {
            Q_EMIT draftSaved(result.value(QStringLiteral("draft_id")).toInteger());
        }
        return;
    }
    if (m_pendingAttAction.contains(id)) {
        const QString action = m_pendingAttAction.take(id);
        if (!error.isEmpty()) {
            Q_EMIT attachmentError(error.value(QStringLiteral("message")).toString());
            return;
        }
        const QString localPath = result.value(QStringLiteral("local_path")).toString();
        if (localPath.isEmpty()) {
            Q_EMIT attachmentError(QStringLiteral("Attachment download failed"));
            return;
        }
        if (action == QStringLiteral("__OPEN__")) {
            QDesktopServices::openUrl(QUrl::fromLocalFile(localPath));
        } else {
            if (QFile::exists(action)) {
                QFile::remove(action);
            }
            if (QFile::copy(localPath, action)) {
                Q_EMIT attachmentSaved(action);
            } else {
                Q_EMIT attachmentError(QStringLiteral("Failed to write %1").arg(action));
            }
        }
        return;
    }

    if (id != m_getReqId || !error.isEmpty()) {
        return;
    }
    m_getReqId = -1;

    const QJsonObject m = result.value(QStringLiteral("message")).toObject();
    if (m.isEmpty()) {
        return;
    }

    m_messageId = m.value(QStringLiteral("id")).toInteger();
    m_accountId = m.value(QStringLiteral("account_id")).toInteger();
    m_subject = m.value(QStringLiteral("subject")).toString();
    extractFirstAddress(m.value(QStringLiteral("from_json")).toString(), m_senderName, m_senderAddress);
    m_toText = formatAddressList(m.value(QStringLiteral("to_json")).toString());
    m_ccText = formatAddressList(m.value(QStringLiteral("cc_json")).toString());

    const qint64 ts = m.value(QStringLiteral("date_ts")).toInteger();
    m_dateText = ts > 0 ? QDateTime::fromSecsSinceEpoch(ts).toString(QStringLiteral("ddd, MMM d, yyyy h:mm AP")) : QString();

    m_textPlain = m.value(QStringLiteral("text_plain")).toString();
    m_textHtml = m.value(QStringLiteral("text_html")).toString();
    m_bodySynced = m.value(QStringLiteral("body_synced")).toBool();
    const int flags = m.value(QStringLiteral("flags_bitmask")).toInt();
    m_unread = (flags & 1) == 0;
    m_starred = (flags & 2) != 0;

    m_attachments.clear();
    const QJsonArray atts = m.value(QStringLiteral("attachments")).toArray();
    for (const auto &v : atts) {
        m_attachments.append(v.toObject().toVariantMap());
    }

    m_threadMessages.clear();
    const QJsonArray threadArr = result.value(QStringLiteral("thread")).toArray();
    for (int i = 0; i < threadArr.size(); ++i) {
        const QJsonObject tm = threadArr.at(i).toObject();
        QString sName;
        QString sAddr;
        extractFirstAddress(tm.value(QStringLiteral("from_json")).toString(), sName, sAddr);
        const qint64 mts = tm.value(QStringLiteral("date_ts")).toInteger();
        const int mflags = tm.value(QStringLiteral("flags_bitmask")).toInt();
        const bool isUnread = (mflags & 1) == 0;
        const bool isLatest = (i == threadArr.size() - 1);

        QVariantMap entry;
        entry.insert(QStringLiteral("id"), tm.value(QStringLiteral("id")).toInteger());
        entry.insert(QStringLiteral("senderName"), sName);
        entry.insert(QStringLiteral("senderAddress"), sAddr);
        entry.insert(QStringLiteral("dateText"),
                     mts > 0 ? QDateTime::fromSecsSinceEpoch(mts).toString(QStringLiteral("MMM d, h:mm AP")) : QString());
        entry.insert(QStringLiteral("snippet"), tm.value(QStringLiteral("snippet")).toString());
        entry.insert(QStringLiteral("textPlain"), tm.value(QStringLiteral("text_plain")).toString());
        entry.insert(QStringLiteral("textHtml"), tm.value(QStringLiteral("text_html")).toString());
        entry.insert(QStringLiteral("bodySynced"), tm.value(QStringLiteral("body_synced")).toBool());
        entry.insert(QStringLiteral("unread"), isUnread);
        entry.insert(QStringLiteral("expanded"), isLatest || isUnread);
        m_threadMessages.append(entry);
    }

    Q_EMIT messageChanged();
}

void MessageController::onNotification(const QString &method, const QJsonObject &params)
{
    if (method == QStringLiteral("message.body_ready")) {
        if (params.value(QStringLiteral("message_id")).toInteger() == m_messageId && m_messageId > 0) {
            openMessage(m_accountId, m_messageId);
        }
    } else if (method == QStringLiteral("outbox.status")) {
        Q_EMIT outboxStatus(
            params.value(QStringLiteral("status")).toString(),
            params.value(QStringLiteral("error")).toString());
    }
}

void MessageController::extractFirstAddress(const QString &jsonStr, QString &nameOut, QString &addrOut)
{
    const QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (doc.isArray() && !doc.array().isEmpty()) {
        const QJsonObject first = doc.array().first().toObject();
        nameOut = first.value(QStringLiteral("name")).toString();
        addrOut = first.value(QStringLiteral("address")).toString();
        if (nameOut.isEmpty()) {
            nameOut = addrOut;
        }
        return;
    }
    nameOut = jsonStr;
    addrOut = jsonStr;
}

QString MessageController::formatAddressList(const QString &jsonStr)
{
    const QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (!doc.isArray()) {
        return jsonStr;
    }
    QStringList parts;
    for (const auto &v : doc.array()) {
        const QJsonObject o = v.toObject();
        const QString name = o.value(QStringLiteral("name")).toString();
        const QString addr = o.value(QStringLiteral("address")).toString();
        parts.append(name.isEmpty() ? addr : QStringLiteral("%1 <%2>").arg(name, addr));
    }
    return parts.join(QStringLiteral(", "));
}
