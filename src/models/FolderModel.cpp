#include "FolderModel.h"
#include "../ipc/DaemonClient.h"

#include <QMap>
#include <QSettings>

FolderModel::FolderModel(DaemonClient *client, QObject *parent)
    : QAbstractListModel(parent)
    , m_client(client)
{
    QSettings settings;
    const QStringList saved = settings.value(QStringLiteral("ui/collapsedFolders")).toStringList();
    m_collapsedKeys = QSet<QString>(saved.cbegin(), saved.cend());

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
    case DepthRole: return it.depth;
    case HasChildrenRole: return it.hasChildren;
    case ExpandedRole: return it.expanded;
    case CollapseKeyRole: return it.collapseKey;
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
        { IsUnifiedRole, "isUnified" },
        { DepthRole, "depth" },
        { HasChildrenRole, "hasChildren" },
        { ExpandedRole, "expanded" },
        { CollapseKeyRole, "collapseKey" }
    };
}

void FolderModel::setFolderMode(const QString &mode)
{
    const QString normalized = (mode == QStringLiteral("all")) ? QStringLiteral("all") : QStringLiteral("unified");
    if (m_folderMode == normalized) {
        return;
    }
    m_folderMode = normalized;
    Q_EMIT folderModeChanged();
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

void FolderModel::createFolder(qint64 accountId, const QString &fullPath)
{
    if (accountId <= 0 || fullPath.trimmed().isEmpty()) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("account_id"), accountId);
    params.insert(QStringLiteral("full_path"), fullPath.trimmed());
    m_client->sendRequest(QStringLiteral("folder.create"), params);
}

void FolderModel::renameFolder(qint64 folderId, const QString &newPath)
{
    if (folderId <= 0 || newPath.trimmed().isEmpty()) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("folder_id"), folderId);
    params.insert(QStringLiteral("new_path"), newPath.trimmed());
    m_client->sendRequest(QStringLiteral("folder.rename"), params);
}

void FolderModel::deleteFolder(qint64 folderId)
{
    if (folderId <= 0) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("folder_id"), folderId);
    m_client->sendRequest(QStringLiteral("folder.delete"), params);
}

void FolderModel::emptyFolder(qint64 folderId)
{
    if (folderId <= 0) {
        return;
    }
    QJsonObject params;
    params.insert(QStringLiteral("folder_id"), folderId);
    m_client->sendRequest(QStringLiteral("folder.empty"), params);
}

void FolderModel::toggleCollapsed(const QString &key)
{
    if (m_collapsedKeys.contains(key)) {
        m_collapsedKeys.remove(key);
    } else {
        m_collapsedKeys.insert(key);
    }
    QSettings settings;
    settings.setValue(QStringLiteral("ui/collapsedFolders"), QStringList(m_collapsedKeys.cbegin(), m_collapsedKeys.cend()));
    rebuildProjection();
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
            m_items.append(FolderItem{ 0, 0, QStringLiteral("Unified"), QString(), QString(), QString(), QString(), 0, 0, false, true, true, true });
            for (const QString &r : specialOrder) {
                m_items.append(FolderItem{
                    0, 0, specialNames.value(r), QString(), QString(), r, iconForRole(r), unifiedUnread.value(r, 0), 0, false, true, false, true
                });
            }
        }

        // Non-common / custom folders grouped per account below Unified (with tree depth & folding)
        QMap<qint64, QString> accountEmails;
        QMap<qint64, QVector<FolderItem>> customByAccount;
        for (const auto &v : m_rawFolders) {
            const QJsonObject f = v.toObject();
            const qint64 aid = f.value(QStringLiteral("account_id")).toInteger();
            accountEmails.insert(aid, f.value(QStringLiteral("account_email")).toString());
            const QString role = f.value(QStringLiteral("role")).toString();
            if (role == QStringLiteral("custom")) {
                const QString fp = f.value(QStringLiteral("full_path")).toString();
                const QString delim = f.value(QStringLiteral("delimiter")).toString(QStringLiteral("/"));
                const int depth = qMax(0, static_cast<int>(fp.split(delim, Qt::SkipEmptyParts).size()) - 1);
                customByAccount[aid].append(FolderItem{
                    f.value(QStringLiteral("id")).toInteger(),
                    aid,
                    f.value(QStringLiteral("name")).toString(),
                    fp,
                    QStringLiteral("folder:%1:%2").arg(aid).arg(fp),
                    role,
                    iconForRole(role),
                    f.value(QStringLiteral("unread_count")).toInt(),
                    depth,
                    false,
                    true,
                    false,
                    false
                });
            }
        }
        for (auto it = customByAccount.begin(); it != customByAccount.end(); ++it) {
            std::sort(it.value().begin(), it.value().end(), [](const FolderItem &a, const FolderItem &b) {
                return a.fullPath.compare(b.fullPath, Qt::CaseInsensitive) < 0;
            });
            const QString accKey = QStringLiteral("acc:%1").arg(it.key());
            const bool accExpanded = !m_collapsedKeys.contains(accKey);
            const QString headerTitle = accountEmails.value(it.key()).isEmpty()
                ? QStringLiteral("Account %1").arg(it.key())
                : accountEmails.value(it.key());
            m_items.append(FolderItem{
                0, it.key(), headerTitle, QString(), accKey, QString(), QString(), 0, 0, true, accExpanded, true, false
            });
            if (!accExpanded) {
                continue;
            }
            QString collapsedPrefix;
            for (int i = 0; i < it.value().size(); ++i) {
                FolderItem item = it.value()[i];
                if (!collapsedPrefix.isEmpty() && item.fullPath.startsWith(collapsedPrefix)) {
                    continue;
                }
                collapsedPrefix.clear();
                item.hasChildren = (i + 1 < it.value().size())
                    && it.value()[i + 1].fullPath.startsWith(item.fullPath + QLatin1Char('/'));
                item.expanded = !m_collapsedKeys.contains(item.collapseKey);
                if (item.hasChildren && !item.expanded) {
                    collapsedPrefix = item.fullPath + QLatin1Char('/');
                }
                m_items.append(item);
            }
        }
    } else {
        QMap<qint64, QString> accountEmails;
        QMap<qint64, QVector<FolderItem>> byAccount;
        for (const auto &v : m_rawFolders) {
            const QJsonObject f = v.toObject();
            const qint64 aid = f.value(QStringLiteral("account_id")).toInteger();
            accountEmails.insert(aid, f.value(QStringLiteral("account_email")).toString());
            const QString role = f.value(QStringLiteral("role")).toString();
            const QString fp = f.value(QStringLiteral("full_path")).toString();
            const QString delim = f.value(QStringLiteral("delimiter")).toString(QStringLiteral("/"));
            const int depth = qMax(0, static_cast<int>(fp.split(delim, Qt::SkipEmptyParts).size()) - 1);
            byAccount[aid].append(FolderItem{
                f.value(QStringLiteral("id")).toInteger(),
                aid,
                f.value(QStringLiteral("name")).toString(),
                fp,
                QStringLiteral("folder:%1:%2").arg(aid).arg(fp),
                role,
                iconForRole(role),
                f.value(QStringLiteral("unread_count")).toInt(),
                depth,
                false,
                true,
                false,
                false
            });
        }
        for (auto it = byAccount.begin(); it != byAccount.end(); ++it) {
            std::sort(it.value().begin(), it.value().end(), [](const FolderItem &a, const FolderItem &b) {
                if (a.role == QStringLiteral("inbox") && b.role != QStringLiteral("inbox")) return true;
                if (b.role == QStringLiteral("inbox") && a.role != QStringLiteral("inbox")) return false;
                return a.fullPath.compare(b.fullPath, Qt::CaseInsensitive) < 0;
            });
            const QString accKey = QStringLiteral("acc:%1").arg(it.key());
            const bool accExpanded = !m_collapsedKeys.contains(accKey);
            const QString headerTitle = accountEmails.value(it.key()).isEmpty()
                ? QStringLiteral("Account %1").arg(it.key())
                : accountEmails.value(it.key());
            m_items.append(FolderItem{
                0, it.key(), headerTitle, QString(), accKey, QString(), QString(), 0, 0, true, accExpanded, true, false
            });
            if (!accExpanded) {
                continue;
            }
            QString collapsedPrefix;
            for (int i = 0; i < it.value().size(); ++i) {
                FolderItem item = it.value()[i];
                if (!collapsedPrefix.isEmpty() && item.fullPath.startsWith(collapsedPrefix)) {
                    continue;
                }
                collapsedPrefix.clear();
                item.hasChildren = (i + 1 < it.value().size())
                    && it.value()[i + 1].fullPath.startsWith(item.fullPath + QLatin1Char('/'));
                item.expanded = !m_collapsedKeys.contains(item.collapseKey);
                if (item.hasChildren && !item.expanded) {
                    collapsedPrefix = item.fullPath + QLatin1Char('/');
                }
                m_items.append(item);
            }
        }
    }

    endResetModel();
}
