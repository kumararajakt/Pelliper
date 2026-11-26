#include "ThreadListModel.h"
#include "../ipc/DaemonClient.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QMap>

ThreadListModel::ThreadListModel(DaemonClient *client, QObject *parent)
    : QAbstractListModel(parent)
    , m_client(client)
{
    connect(m_client, &DaemonClient::responseReceived, this, &ThreadListModel::onResponse);
    connect(m_client, &DaemonClient::notificationReceived, this, &ThreadListModel::onNotification);
}

int ThreadListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant ThreadListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const ThreadItem &it = m_items.at(index.row());
    switch (role) {
    case MessageIdRole: return it.messageId;
    case AccountIdRole: return it.accountId;
    case FolderIdRole: return it.folderId;
    case SenderNameRole: return it.senderName;
    case SubjectRole: return it.subject;
    case SnippetRole: return it.snippet;
    case TimestampTextRole: return it.timestampText;
    case UnreadRole: return it.unread;
    case StarredRole: return it.starred;
    case HasAttachmentsRole: return it.hasAttachments;
    case BodySyncedRole: return it.bodySynced;
    default: return {};
    }
}

QHash<int, QByteArray> ThreadListModel::roleNames() const
{
    return {
        { MessageIdRole, "messageId" },
        { AccountIdRole, "accountId" },
        { FolderIdRole, "folderId" },
        { SenderNameRole, "senderName" },
        { SubjectRole, "subject" },
        { SnippetRole, "snippet" },
        { TimestampTextRole, "timestampText" },
        { UnreadRole, "unread" },
        { StarredRole, "starred" },
        { HasAttachmentsRole, "hasAttachments" },
        { BodySyncedRole, "bodySynced" }
    };
}

void ThreadListModel::search(const QString &query, qint64 folderId, bool serverSearch, const QString &folderRole)
{
    m_lastQuery = query;
    m_lastFolderId = folderId;
    m_lastFolderRole = folderRole;
    ++m_activeSearchId;
    const bool wantServer = serverSearch && !query.trimmed().isEmpty();
    if (m_searchingServer != wantServer) {
        m_searchingServer = wantServer;
        Q_EMIT searchingServerChanged();
    }

    QJsonObject params;
    if (folderId > 0) {
        params.insert(QStringLiteral("folder_id"), folderId);
    } else if (!folderRole.isEmpty()) {
        params.insert(QStringLiteral("folder_role"), folderRole);
    }
    params.insert(QStringLiteral("query"), query);
    params.insert(QStringLiteral("limit"), 100);
    params.insert(QStringLiteral("server_search"), wantServer);
    params.insert(QStringLiteral("search_id"), m_activeSearchId);
    m_searchReqId = m_client->sendRequest(QStringLiteral("message.search"), params);
}

void ThreadListModel::requestBody(qint64 accountId, qint64 messageId)
{
    QJsonObject params;
    params.insert(QStringLiteral("account_id"), accountId);
    params.insert(QStringLiteral("message_id"), messageId);
    m_client->sendRequest(QStringLiteral("message.get"), params);
}

void ThreadListModel::prefetchRange(int firstRow, int lastRow)
{
    if (m_items.isEmpty()) {
        return;
    }
    const int start = qMax(0, firstRow);
    const int end = qMin(m_items.size() - 1, lastRow + 20);
    QMap<qint64, QJsonArray> byAccount;
    for (int i = start; i <= end; ++i) {
        const ThreadItem &it = m_items.at(i);
        if (!it.bodySynced && it.messageId > 0) {
            byAccount[it.accountId].append(it.messageId);
        }
    }
    for (auto it = byAccount.cbegin(); it != byAccount.cend(); ++it) {
        QJsonObject params;
        params.insert(QStringLiteral("account_id"), it.key());
        params.insert(QStringLiteral("message_ids"), it.value());
        m_client->sendRequest(QStringLiteral("message.prefetch_bodies"), params);
    }
}

void ThreadListModel::removeMessageOptimistic(qint64 messageId)
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].messageId == messageId) {
            beginRemoveRows(QModelIndex(), i, i);
            m_items.removeAt(i);
            endRemoveRows();
            break;
        }
    }
}

void ThreadListModel::updateFlagsOptimistic(qint64 messageId, bool unread, bool starred)
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].messageId == messageId) {
            m_items[i].unread = unread;
            m_items[i].starred = starred;
            const QModelIndex idx = index(i);
            Q_EMIT dataChanged(idx, idx, { UnreadRole, StarredRole });
            break;
        }
    }
}

void ThreadListModel::onResponse(int id, const QJsonObject &result, const QJsonObject &error)
{
    if (id != m_searchReqId || !error.isEmpty()) {
        return;
    }
    m_searchReqId = -1;

    const QJsonArray arr = result.value(QStringLiteral("messages")).toArray();
    beginResetModel();
    m_items.clear();
    m_items.reserve(arr.size());
    for (const auto &v : arr) {
        const QJsonObject m = v.toObject();
        const int flags = m.value(QStringLiteral("flags_bitmask")).toInt();
        m_items.append(ThreadItem{
            m.value(QStringLiteral("id")).toInteger(),
            m.value(QStringLiteral("account_id")).toInteger(),
            m.value(QStringLiteral("folder_id")).toInteger(),
            extractSender(m.value(QStringLiteral("from_json")).toString()),
            m.value(QStringLiteral("subject")).toString(),
            m.value(QStringLiteral("snippet")).toString(),
            formatTimestamp(m.value(QStringLiteral("date_ts")).toInteger()),
            (flags & 1) == 0,
            (flags & 2) != 0,
            m.value(QStringLiteral("has_attachments")).toBool(),
            m.value(QStringLiteral("body_synced")).toBool()
        });
    }
    endResetModel();
}

void ThreadListModel::onNotification(const QString &method, const QJsonObject &params)
{
    if (method == QStringLiteral("message.body_ready")) {
        const qint64 mid = params.value(QStringLiteral("message_id")).toInteger();
        const QString snippet = params.value(QStringLiteral("snippet")).toString();
        for (int i = 0; i < m_items.size(); ++i) {
            if (m_items[i].messageId == mid) {
                m_items[i].snippet = snippet;
                m_items[i].bodySynced = true;
                const QModelIndex idx = index(i);
                Q_EMIT dataChanged(idx, idx, { SnippetRole, BodySyncedRole });
                break;
            }
        }
    } else if (method == QStringLiteral("search.results_appended")) {
        const qint64 sid = params.value(QStringLiteral("search_id")).toInteger();
        if (sid != m_activeSearchId) {
            return;
        }
        const QJsonArray arr = params.value(QStringLiteral("messages")).toArray();
        if (!arr.isEmpty()) {
            const int startRow = m_items.size();
            beginInsertRows(QModelIndex(), startRow, startRow + arr.size() - 1);
            for (const auto &v : arr) {
                const QJsonObject m = v.toObject();
                const int flags = m.value(QStringLiteral("flags_bitmask")).toInt();
                m_items.append(ThreadItem{
                    m.value(QStringLiteral("id")).toInteger(),
                    m.value(QStringLiteral("account_id")).toInteger(),
                    m.value(QStringLiteral("folder_id")).toInteger(),
                    extractSender(m.value(QStringLiteral("from_json")).toString()),
                    m.value(QStringLiteral("subject")).toString(),
                    m.value(QStringLiteral("snippet")).toString(),
                    formatTimestamp(m.value(QStringLiteral("date_ts")).toInteger()),
                    (flags & 1) == 0,
                    (flags & 2) != 0,
                    m.value(QStringLiteral("has_attachments")).toBool(),
                    m.value(QStringLiteral("body_synced")).toBool()
                });
            }
            endInsertRows();
        }
        if (params.value(QStringLiteral("done")).toBool() && m_searchingServer) {
            m_searchingServer = false;
            Q_EMIT searchingServerChanged();
        }
    } else if (method == QStringLiteral("sync.state_changed")) {
        const QString st = params.value(QStringLiteral("state")).toString();
        const bool nowSyncing = (st == QStringLiteral("syncing_headers") || st == QStringLiteral("syncing_bodies"));
        if (m_syncing != nowSyncing) {
            m_syncing = nowSyncing;
            Q_EMIT syncingChanged();
        }
    } else if (method == QStringLiteral("message.new")) {
        if (m_lastQuery.trimmed().isEmpty()) {
            search(m_lastQuery, m_lastFolderId, false, m_lastFolderRole);
        }
    }
}

QString ThreadListModel::formatTimestamp(qint64 epochSecs)
{
    if (epochSecs <= 0) {
        return {};
    }
    const QDateTime dt = QDateTime::fromSecsSinceEpoch(epochSecs);
    if (dt.date() == QDate::currentDate()) {
        return dt.toString(QStringLiteral("h:mm AP"));
    }
    return dt.toString(QStringLiteral("MMM d"));
}

QString ThreadListModel::extractSender(const QString &fromJson)
{
    const QJsonDocument doc = QJsonDocument::fromJson(fromJson.toUtf8());
    if (doc.isArray() && !doc.array().isEmpty()) {
        const QJsonObject first = doc.array().first().toObject();
        const QString name = first.value(QStringLiteral("name")).toString();
        if (!name.isEmpty()) {
            return name;
        }
        return first.value(QStringLiteral("address")).toString();
    }
    return fromJson.isEmpty() ? QStringLiteral("Unknown") : fromJson;
}
