#include "threadmodel.h"

#include "addressfield.h"

#include <QDateTime>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>
#include <QMap>

static const QString DB_CONN = QStringLiteral("pelliper_threads_readonly");

ThreadModel::ThreadModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &ThreadModel::refresh);
    startWatching();
}

void ThreadModel::startWatching()
{
    QString dbPath = cacheDbPath();
    if (QFile::exists(dbPath) && !m_watcher.files().contains(dbPath)) {
        m_watcher.addPath(dbPath);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged,
                this, &ThreadModel::onFileChanged);
        m_watcher.addPath(dbPath + QStringLiteral("-wal"));
        m_watcher.addPath(dbPath + QStringLiteral("-shm"));
    }
}

void ThreadModel::onFileChanged(const QString &path)
{
    Q_UNUSED(path)
    if (!m_folderPath.isEmpty() && !m_refreshTimer.isActive())
        m_refreshTimer.start();
    QString dbPath = cacheDbPath();
    if (!m_watcher.files().contains(dbPath) && QFile::exists(dbPath))
        m_watcher.addPath(dbPath);
}

QString ThreadModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

int ThreadModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_threads.size();
}

QVariant ThreadModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_threads.size())
        return {};

    const auto &thread = m_threads.at(index.row());
    switch (role) {
    case AccountIdRole:       return thread.accountId;
    case FolderPathRole:      return thread.folderPath;
    case UidRole:             return thread.rootUid;
    case SubjectRole:         return thread.subject;
    case SenderRole:          return thread.sender;
    case DateRole:            return thread.date;
    case IsReadRole:          return thread.isRead;
    case IsStarredRole:       return thread.isStarred;
    case HasAttachmentsRole:  return thread.hasAttachments;
    case PreviewRole:         return thread.preview;
    case MessageIdRole:       return thread.messageId;
    case ReplyCountRole:      return thread.replyCount;
    case UnreadCountRole:     return thread.unreadCount;
    }
    return {};
}

QHash<int, QByteArray> ThreadModel::roleNames() const
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
        { ReplyCountRole,      "replyCount" },
        { UnreadCountRole,     "unreadCount" },
    };
}

int ThreadModel::count() const
{
    return m_threads.size();
}

QString ThreadModel::folderPath() const
{
    return m_folderPath;
}

void ThreadModel::setFolderPath(const QString &path)
{
    if (m_folderPath == path) return;
    m_folderPath = path;
    Q_EMIT folderPathChanged();
    loadMessages();
}

int ThreadModel::accountId() const
{
    return m_accountId;
}

void ThreadModel::setAccountId(int id)
{
    if (m_accountId == id) return;
    m_accountId = id;
    Q_EMIT accountIdChanged();
    loadMessages();
}

void ThreadModel::setUnifiedInbox(bool enabled)
{
    if (m_unifiedInbox == enabled) return;
    m_unifiedInbox = enabled;
    Q_EMIT unifiedInboxChanged();
    loadMessages();
}

void ThreadModel::refresh()
{
    loadMessages();
}

void ThreadModel::loadMessages()
{
    if (!m_unifiedInbox && (m_accountId < 0 || m_folderPath.isEmpty())) {
        beginResetModel();
        m_threads.clear();
        endResetModel();
        Q_EMIT countChanged();
        return;
    }

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        beginResetModel();
        m_threads.clear();
        endResetModel();
        Q_EMIT countChanged();
        return;
    }

    startWatching();

    QList<QMap<QString, QVariant>> rows;

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "ThreadModel: failed to open cache.db:" << db.lastError().text();
            endResetModel();
            Q_EMIT countChanged();
            return;
        }

        QSqlQuery query(db);
        // Threading is driven by `message_id` and `references_`, which now
        // live in `message_headers` — the same rows must be joined in or the
        // union-find below has nothing to link. Recency orders on `h.date_ts`,
        // not the raw `h.date` header string.
        if (m_unifiedInbox) {
            query.prepare(QStringLiteral(
                "SELECT m.account_id, m.uid, h.subject, h.from_addr, h.date_ts, "
                "m.is_read, m.is_starred, m.has_attachments, "
                "m.preview, h.message_id, h.references_ "
                "FROM messages m "
                "LEFT JOIN message_headers h "
                "  ON h.account_id = m.account_id AND h.folder_path = m.folder_path AND h.uid = m.uid "
                "WHERE m.folder_path = ? "
                "ORDER BY h.date_ts DESC"));
            query.addBindValue(m_folderPath);
        } else {
            query.prepare(QStringLiteral(
                "SELECT m.uid, h.subject, h.from_addr, h.date_ts, "
                "m.is_read, m.is_starred, m.has_attachments, "
                "m.preview, h.message_id, h.references_ "
                "FROM messages m "
                "LEFT JOIN message_headers h "
                "  ON h.account_id = m.account_id AND h.folder_path = m.folder_path AND h.uid = m.uid "
                "WHERE m.account_id = ? AND m.folder_path = ? "
                "ORDER BY h.date_ts DESC"));
            query.addBindValue(m_accountId);
            query.addBindValue(m_folderPath);
        }

        if (query.exec()) {
            while (query.next()) {
                QMap<QString, QVariant> row;
                int col = 0;
                if (m_unifiedInbox) {
                    row[QStringLiteral("account_id")] = query.value(col++);
                }
                row[QStringLiteral("uid")] = query.value(col++);
                row[QStringLiteral("subject")] = query.value(col++);
                // Stored as JSON; the thread header shows the rendered form.
                row[QStringLiteral("sender")] =
                    addressDisplayString(query.value(col++).toString());
                row[QStringLiteral("date")] = query.value(col++);
                row[QStringLiteral("is_read")] = query.value(col++);
                row[QStringLiteral("is_starred")] = query.value(col++);
                row[QStringLiteral("has_attachments")] = query.value(col++);
                row[QStringLiteral("preview")] = query.value(col++);
                row[QStringLiteral("message_id")] = query.value(col++);
                row[QStringLiteral("references_")] = query.value(col++);
                rows.append(row);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    beginResetModel();
    m_threads.clear();

    // Build thread groups
    // Map: messageId -> index in rows list
    QMap<QString, int> messageIdToRow;
    for (int i = 0; i < rows.size(); ++i) {
        QString mid = rows[i][QStringLiteral("message_id")].toString();
        if (!mid.isEmpty()) {
            messageIdToRow[mid] = i;
        }
    }

    // Determine root of each message
    // A message is a root if it has no In-Reply-To / References,
    // or if its referenced message is not in this folder.
    // We use a union-find approach: find the ultimate root for each message.
    QMap<int, int> parent; // row -> parent row

    auto findRoot = [&](int row, auto&& self) -> int {
        if (!parent.contains(row)) return row;
        if (parent[row] == row) return row;
        parent[row] = self(parent[row], self);
        return parent[row];
    };

    for (int i = 0; i < rows.size(); ++i) {
        QString refs = rows[i][QStringLiteral("references_")].toString();
        if (refs.isEmpty()) continue;

        // References can be space-separated Message-IDs; the last one is the direct parent
        QStringList refList = refs.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        if (refList.isEmpty()) continue;

        QString parentMid = refList.last().trimmed();
        if (parentMid.isEmpty()) continue;

        if (messageIdToRow.contains(parentMid)) {
            int parentRow = messageIdToRow[parentMid];
            if (parentRow != i) {
                parent[i] = parentRow;
            }
        }
    }

    // Group messages by their root
    QMap<int, QList<int>> groups; // rootRow -> list of child rows
    for (int i = 0; i < rows.size(); ++i) {
        int root = findRoot(i, findRoot);
        groups[root].append(i);
    }

    // Build ThreadGroup for each root
    for (auto it = groups.begin(); it != groups.end(); ++it) {
        int rootRow = it.key();
        const auto &childRows = it.value();

        const auto &rootMsg = rows[rootRow];

        ThreadGroup group;
        group.accountId = m_unifiedInbox ? rootMsg[QStringLiteral("account_id")].toInt() : m_accountId;
        group.folderPath = m_unifiedInbox ? QStringLiteral("INBOX") : m_folderPath;
        group.rootUid = rootMsg[QStringLiteral("uid")].toInt();
        group.subject = rootMsg[QStringLiteral("subject")].toString();
        group.sender = rootMsg[QStringLiteral("sender")].toString();
        group.date = rootMsg[QStringLiteral("date")].toLongLong();
        group.isRead = rootMsg[QStringLiteral("is_read")].toBool();
        group.isStarred = rootMsg[QStringLiteral("is_starred")].toBool();
        group.hasAttachments = rootMsg[QStringLiteral("has_attachments")].toBool();
        group.preview = rootMsg[QStringLiteral("preview")].toString();
        group.messageId = rootMsg[QStringLiteral("message_id")].toString();
        group.replyCount = childRows.size() - 1; // excluding root
        group.unreadCount = 0;

        // Scan children for unread/attachments/starred
        for (int row : childRows) {
            if (!rows[row][QStringLiteral("is_read")].toBool()) {
                group.unreadCount++;
            }
            if (rows[row][QStringLiteral("has_attachments")].toBool()) {
                group.hasAttachments = true;
            }
            if (rows[row][QStringLiteral("is_starred")].toBool()) {
                group.isStarred = true;
            }
            // Use the latest date from any message in the thread
            qint64 rowDate = rows[row][QStringLiteral("date")].toLongLong();
            if (rowDate > group.date) {
                group.date = rowDate;
            }
        }

        m_threads.append(group);
    }

    // Sort by latest date descending (newest threads first)
    std::sort(m_threads.begin(), m_threads.end(),
              [](const ThreadGroup &a, const ThreadGroup &b) { return a.date > b.date; });

    endResetModel();
    Q_EMIT countChanged();
}
