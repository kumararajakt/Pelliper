#include "messagemodel.h"

#include "addressfield.h"

#include <QDateTime>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>

static const QString DB_CONN = QStringLiteral("pelliper_messages_readonly");

MessageModel::MessageModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &MessageModel::refresh);
    startWatching();
}

void MessageModel::startWatching()
{
    QString dbPath = cacheDbPath();
    if (QFile::exists(dbPath) && !m_watcher.files().contains(dbPath)) {
        m_watcher.addPath(dbPath);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged,
                this, &MessageModel::onFileChanged);
        m_watcher.addPath(dbPath + QStringLiteral("-wal"));
        m_watcher.addPath(dbPath + QStringLiteral("-shm"));
    }
}

void MessageModel::onFileChanged(const QString &path)
{
    Q_UNUSED(path)
    if (!m_folderPath.isEmpty() && !m_refreshTimer.isActive())
        m_refreshTimer.start();
    QString dbPath = cacheDbPath();
    if (!m_watcher.files().contains(dbPath) && QFile::exists(dbPath))
        m_watcher.addPath(dbPath);
}

QString MessageModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

int MessageModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_messages.size();
}

QVariant MessageModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_messages.size())
        return {};

    const auto &msg = m_messages.at(index.row());
    switch (role) {
    case AccountIdRole:       return msg.accountId;
    case FolderPathRole:      return msg.folderPath;
    case UidRole:             return msg.uid;
    case SubjectRole:         return msg.subject;
    case SenderRole:          return msg.sender;
    case DateRole:            return msg.date;
    case IsReadRole:          return msg.isRead;
    case IsStarredRole:       return msg.isStarred;
    case HasAttachmentsRole:  return msg.hasAttachments;
    case PreviewRole:         return msg.preview;
    case MessageIdRole:       return msg.messageId;
    case ReferencesRole:      return msg.references;
    }
    return {};
}

QHash<int, QByteArray> MessageModel::roleNames() const
{
    return {
        { AccountIdRole,       "accountId" },
        { FolderPathRole,      "folderPath" },
        { UidRole,             "uid" },
        { SubjectRole,         "subject" },
        { SenderRole,          "sender" },
        { DateRole,            "date" },
        { IsReadRole,          "isRead" },
        { IsStarredRole,       "isStarred" },
        { HasAttachmentsRole,  "hasAttachments" },
        { PreviewRole,         "preview" },
        { MessageIdRole,       "messageId" },
        { ReferencesRole,      "references" },
    };
}

int MessageModel::count() const
{
    return m_messages.size();
}

QString MessageModel::folderPath() const
{
    return m_folderPath;
}

void MessageModel::setFolderPath(const QString &path)
{
    if (m_folderPath == path) return;
    m_folderPath = path;
    Q_EMIT folderPathChanged();
    loadMessages();
}

int MessageModel::accountId() const
{
    return m_accountId;
}

void MessageModel::setAccountId(int id)
{
    if (m_accountId == id) return;
    m_accountId = id;
    Q_EMIT accountIdChanged();
    loadMessages();
}

void MessageModel::setSort(const QString &role, bool ascending)
{
    if (m_sortRole == role && m_sortAscending == ascending) return;
    m_sortRole = role;
    m_sortAscending = ascending;
    Q_EMIT sortRoleChanged();
    Q_EMIT sortAscendingChanged();
    m_offset = 0;
    m_hasMore = false;
    loadMessages();
}

void MessageModel::setUnifiedInbox(bool enabled)
{
    if (m_unifiedInbox == enabled) return;
    m_unifiedInbox = enabled;
    Q_EMIT unifiedInboxChanged();
    m_offset = 0;
    m_hasMore = false;
    loadMessages();
}

void MessageModel::loadMore()
{
    if (!m_hasMore) return;
    loadMessages(/*append=*/true);
}

void MessageModel::refresh()
{
    m_offset = 0;
    m_hasMore = false;
    loadMessages();
}

void MessageModel::loadMessages(bool append)
{
    if (!append) {
        beginResetModel();
        m_messages.clear();
        m_offset = 0;
    }

    if (!m_unifiedInbox && (m_accountId < 0 || m_folderPath.isEmpty())) {
        if (!append) endResetModel();
        Q_EMIT countChanged();
        return;
    }

    if (m_unifiedInbox && m_folderPath.isEmpty()) {
        // Unified mode defaults to INBOX
    } else if (m_unifiedInbox && m_folderPath != QStringLiteral("INBOX")) {
        if (!append) endResetModel();
        Q_EMIT countChanged();
        return;
    }

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        if (!append) endResetModel();
        Q_EMIT countChanged();
        return;
    }

    startWatching();

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "MessageModel: failed to open cache.db:" << db.lastError().text();
            if (!append) endResetModel();
            Q_EMIT countChanged();
            return;
        }

        QSqlQuery query(db);
        // Header columns live in `message_headers`; `messages` keeps only
        // per-message state. Recency sorts on `h.date_ts` (the parsed
        // timestamp) and never `h.date`, which is the raw Date header and
        // would sort lexically on the weekday name.
        const QString dir = m_sortAscending ? QStringLiteral("ASC") : QStringLiteral("DESC");
        QString orderBy;
        if (m_sortRole == QStringLiteral("sender")) {
            // Sorting on the JSON directly, not on the rendered string: every
            // value starts with the same `{"name":"` prefix, so the comparison
            // lands on the personal name and then the address — the same order
            // as sorting the rendered text, without a second expression to keep
            // in step with `addressDisplayString()`.
            orderBy = QStringLiteral("h.from_addr %1, h.date_ts DESC").arg(dir);
        } else if (m_sortRole == QStringLiteral("subject")) {
            orderBy = QStringLiteral("h.subject %1, h.date_ts DESC").arg(dir);
        } else if (m_sortRole == QStringLiteral("read")) {
            orderBy = QStringLiteral("m.is_read %1, h.date_ts DESC").arg(dir);
        } else {
            orderBy = QStringLiteral("h.date_ts %1").arg(dir);
        }
        query.prepare(QStringLiteral(
            "SELECT m.account_id, m.folder_path, m.uid, h.subject, h.from_addr, h.date_ts, "
            "m.is_read, m.is_starred, m.has_attachments, m.preview, h.message_id, h.references_ "
            "FROM messages m "
            "LEFT JOIN message_headers h "
            "  ON h.account_id = m.account_id AND h.folder_path = m.folder_path AND h.uid = m.uid "
            "WHERE %1 "
            "ORDER BY %2 LIMIT ? OFFSET ?")
            .arg(m_unifiedInbox
                ? QStringLiteral("m.folder_path = ?")
                : QStringLiteral("m.account_id = ? AND m.folder_path = ?"),
            orderBy));
        if (m_unifiedInbox) {
            query.addBindValue(m_folderPath);
        } else {
            query.addBindValue(m_accountId);
            query.addBindValue(m_folderPath);
        }
        query.addBindValue(PAGE_SIZE + 1);
        query.addBindValue(m_offset);

        if (query.exec()) {
            while (query.next()) {
                MessageEntry msg;
                msg.accountId = query.value(0).toInt();
                msg.folderPath = query.value(1).toString();
                msg.uid = query.value(2).toInt();
                msg.subject = query.value(3).toString();
                // Stored as JSON; the list shows the rendered form.
                msg.sender = addressDisplayString(query.value(4).toString());
                msg.date = query.value(5).toLongLong();
                msg.isRead = query.value(6).toBool();
                msg.isStarred = query.value(7).toBool();
                msg.hasAttachments = query.value(8).toBool();
                msg.preview = query.value(9).toString();
                msg.messageId = query.value(10).toString();
                msg.references = query.value(11).toString();
                m_messages.append(msg);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    bool hadMore = m_hasMore;
    if (m_messages.size() > m_offset + PAGE_SIZE) {
        // We got PAGE_SIZE + 1 rows, so there are more
        m_messages.removeLast(); // drop the extra row
        m_hasMore = true;
        m_offset += PAGE_SIZE;
    } else {
        m_hasMore = false;
        if (append) {
            // No more rows appended, offset stays
        } else {
            m_offset = m_messages.size();
        }
    }

    if (!append) endResetModel();
    Q_EMIT countChanged();
    if (hadMore != m_hasMore) Q_EMIT hasMoreChanged();
}
