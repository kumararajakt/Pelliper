#include "FolderModel.h"
#include "../ipc/DaemonClient.h"

#include <QMap>

FolderModel::FolderModel(DaemonClient *client, QObject *parent)
    : QAbstractListModel(parent)
    , m_client(client)
{
    connect(m_client, &DaemonClient::responseReceived, this, &FolderModel::onResponse);
    connect(m_client, &DaemonClient::notificationReceived, this, &FolderModel::onNotification);
    connect(m_client, &DaemonClient::connectedChanged, this, [this]() {
        if (m_client->isConnected()) {
            refresh();
        }
    });
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const FolderItem &it = m_items.at(index.row());
    switch (role) {
    case IdRole: return it.id;
    case AccountIdRole: return it.accountId;
    case NameRole: return it.name;
    case RoleTypeRole: return it.role;
    case IconNameRole: return it.iconName;
    case UnreadCountRole: return it.unreadCount;
    case IsHeaderRole: return it.isHeader;
    case IsUnifiedRole: return it.isUnified;
    default: return {};
    }
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        { IdRole, "folderId" },
        { AccountIdRole, "accountId" },
        { NameRole, "name" },
        { RoleTypeRole, "folderRole" },
        { IconNameRole, "iconName" },
        { UnreadCountRole, "unreadCount" },
        { IsHeaderRole, "isHeader" },
        { IsUnifiedRole, "isUnified" }
    };
}

void FolderModel::setFolderMode(const QString &mode)
{
    const QString normalized = (mode == QStringLiteral("all")) ? QStringLiteral("all") : QStringLiteral("unified");
    if (m_folderMode == normalized) {
        return;
    }
    m_folderMode = normalized;
    emit folderModeChanged();
    rebuildProjection();
}

void FolderModel::refresh()
{
    m_listReqId = m_client->sendRequest(QStringLiteral("folder.list"));
}

void FolderModel::markFolderRead(qint64 folderId)
{
    if (folderId <= 0) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("folder_id"), folderId);
    m_client->sendRequest(QStringLiteral("folder.mark_all_read"), params);
}

void FolderModel::onResponse(int id, const QJsonObject &result, const QJsonObject &error)
{
    if (id == m_listReqId) {
        m_listReqId = -1;
        if (error.isEmpty()) {
            m_rawFolders = result.value(QStringLiteral("folders")).toArray();
            rebuildProjection();
        }
    }
}

void FolderModel::onNotification(const QString &method, const QJsonObject &params)
{
    if (method == QStringLiteral("folder.updated")) {
        const qint64 fid = params.value(QStringLiteral("folder_id")).toInteger();
        const int unread = params.value(QStringLiteral("unread_count")).toInt();
        bool found = false;
        for (int i = 0; i < m_rawFolders.size(); ++i) {
            QJsonObject obj = m_rawFolders.at(i).toObject();
            if (obj.value(QStringLiteral("id")).toInteger() == fid) {
                obj.insert(QStringLiteral("unread_count"), unread);
                m_rawFolders.replace(i, obj);
                found = true;
                break;
            }
        }
        if (found) {
            rebuildProjection();
        } else {
            refresh();
        }
    }
}

QString FolderModel::iconForRole(const QString &role)
{
    if (role == QStringLiteral("inbox")) return QStringLiteral("mail-folder-inbox");
    if (role == QStringLiteral("sent")) return QStringLiteral("mail-folder-sent");
    if (role == QStringLiteral("drafts")) return QStringLiteral("document-edit");
    if (role == QStringLiteral("important")) return QStringLiteral("starred-symbolic");
    if (role == QStringLiteral("archive")) return QStringLiteral("folder-archive");
    if (role == QStringLiteral("spam")) return QStringLiteral("mail-mark-junk");
    if (role == QStringLiteral("trash")) return QStringLiteral("user-trash");
    return QStringLiteral("folder");
}

void FolderModel::rebuildProjection()
{
    beginResetModel();
    m_items.clear();

    if (m_folderMode == QStringLiteral("unified")) {
        const QStringList specialOrder = {
            QStringLiteral("inbox"),
            QStringLiteral("important"),
            QStringLiteral("drafts"),
            QStringLiteral("sent"),
            QStringLiteral("archive"),
            QStringLiteral("spam"),
            QStringLiteral("trash")
        };
        const QMap<QString, QString> specialNames = {
            { QStringLiteral("inbox"), QStringLiteral("Inbox") },
            { QStringLiteral("important"), QStringLiteral("Starred") },
            { QStringLiteral("drafts"), QStringLiteral("Drafts") },
            { QStringLiteral("sent"), QStringLiteral("Sent") },
            { QStringLiteral("archive"), QStringLiteral("Archive") },
            { QStringLiteral("spam"), QStringLiteral("Spam") },
            { QStringLiteral("trash"), QStringLiteral("Trash") }
        };

        QMap<QString, int> unifiedUnread;
        for (const auto &v : m_rawFolders) {
            const QJsonObject f = v.toObject();
            const QString role = f.value(QStringLiteral("role")).toString();
            if (specialNames.contains(role)) {
                unifiedUnread[role] += f.value(QStringLiteral("unread_count")).toInt();
            }
        }

        if (!m_rawFolders.isEmpty()) {
            m_items.append(FolderItem{ 0, 0, QStringLiteral("Unified"), QString(), QString(), 0, true, true });
            for (const QString &r : specialOrder) {
                m_items.append(FolderItem{
                    0, 0, specialNames.value(r), r, iconForRole(r), unifiedUnread.value(r, 0), false, true
                });
            }
        }

        // Non-common / custom folders grouped per account below Unified
        QMap<qint64, QVector<FolderItem>> customByAccount;
        for (const auto &v : m_rawFolders) {
            const QJsonObject f = v.toObject();
            const QString role = f.value(QStringLiteral("role")).toString();
            if (role == QStringLiteral("custom")) {
                const qint64 aid = f.value(QStringLiteral("account_id")).toInteger();
                customByAccount[aid].append(FolderItem{
                    f.value(QStringLiteral("id")).toInteger(),
                    aid,
                    f.value(QStringLiteral("name")).toString(),
                    role,
                    iconForRole(role),
                    f.value(QStringLiteral("unread_count")).toInt(),
                    false,
                    false
                });
            }
        }
        for (auto it = customByAccount.cbegin(); it != customByAccount.cend(); ++it) {
            m_items.append(FolderItem{
                0, it.key(), QStringLiteral("Account %1 Folders").arg(it.key()), QString(), QString(), 0, true, false
            });
            m_items.append(it.value());
        }
    } else {
        QMap<qint64, QVector<FolderItem>> byAccount;
        for (const auto &v : m_rawFolders) {
            const QJsonObject f = v.toObject();
            const qint64 aid = f.value(QStringLiteral("account_id")).toInteger();
            const QString role = f.value(QStringLiteral("role")).toString();
            byAccount[aid].append(FolderItem{
                f.value(QStringLiteral("id")).toInteger(),
                aid,
                f.value(QStringLiteral("name")).toString(),
                role,
                iconForRole(role),
                f.value(QStringLiteral("unread_count")).toInt(),
                false,
                false
            });
        }
        for (auto it = byAccount.cbegin(); it != byAccount.cend(); ++it) {
            m_items.append(FolderItem{
                0, it.key(), QStringLiteral("Account %1").arg(it.key()), QString(), QString(), 0, true, false
            });
            m_items.append(it.value());
        }
    }

    endResetModel();
}
