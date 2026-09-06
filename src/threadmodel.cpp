#include "threadmodel.h"

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

void ThreadModel::refresh()
{
    loadMessages();
}

void ThreadModel::loadMessages()
{
    if (m_accountId < 0 || m_folderPath.isEmpty()) {
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
        query.prepare(QStringLiteral(
            "SELECT uid, subject, sender, date, is_read, is_starred, has_attachments, "
            "preview, message_id, references_ "
            "FROM messages WHERE account_id = ? AND folder_path = ? "
            "ORDER BY date DESC"));
        query.addBindValue(m_accountId);
        query.addBindValue(m_folderPath);

        if (query.exec()) {
            while (query.next()) {
                QMap<QString, QVariant> row;
                row[QStringLiteral("uid")] = query.value(0);
                row[QStringLiteral("subject")] = query.value(1);
                row[QStringLiteral("sender")] = query.value(2);
                row[QStringLiteral("date")] = query.value(3);
                row[QStringLiteral("is_read")] = query.value(4);
                row[QStringLiteral("is_starred")] = query.value(5);
                row[QStringLiteral("has_attachments")] = query.value(6);
                row[QStringLiteral("preview")] = query.value(7);
                row[QStringLiteral("message_id")] = query.value(8);
                row[QStringLiteral("references_")] = query.value(9);
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
        group.accountId = m_accountId;
        group.folderPath = m_folderPath;
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
