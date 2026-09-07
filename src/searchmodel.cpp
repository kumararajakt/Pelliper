#include "searchmodel.h"

#include <QFile>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>

static const QString DB_CONN = QStringLiteral("pelliper_search_readonly");

SearchModel::SearchModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &SearchModel::runQuery);
    startWatching();
}

void SearchModel::startWatching()
{
    QString dbPath = cacheDbPath();
    if (QFile::exists(dbPath) && !m_watcher.files().contains(dbPath)) {
        m_watcher.addPath(dbPath);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged,
                this, &SearchModel::onFileChanged);
        m_watcher.addPath(dbPath + QStringLiteral("-wal"));
        m_watcher.addPath(dbPath + QStringLiteral("-shm"));
    }
}

void SearchModel::onFileChanged(const QString &path)
{
    Q_UNUSED(path)
    if (!m_query.isEmpty() && !m_refreshTimer.isActive())
        m_refreshTimer.start();
    QString dbPath = cacheDbPath();
    if (!m_watcher.files().contains(dbPath) && QFile::exists(dbPath))
        m_watcher.addPath(dbPath);
}

QString SearchModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

int SearchModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_results.size();
}

QVariant SearchModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_results.size())
        return {};

    const auto &result = m_results.at(index.row());
    switch (role) {
    case AccountIdRole:   return result.accountId;
    case FolderPathRole:  return result.folderPath;
    case UidRole:         return result.uid;
    case SubjectRole:     return result.subject;
    case SenderRole:      return result.sender;
    case DateRole:        return result.date;
    case IsReadRole:      return result.isRead;
    case IsStarredRole:   return result.isStarred;
    case PreviewRole:     return result.preview;
    }
    return {};
}

QHash<int, QByteArray> SearchModel::roleNames() const
{
    return {
        { AccountIdRole,   "accountId" },
        { FolderPathRole,  "folderPath" },
        { UidRole,         "uid" },
        { SubjectRole,     "subject" },
        { SenderRole,      "sender" },
        { DateRole,        "date" },
        { IsReadRole,      "isRead" },
        { IsStarredRole,   "isStarred" },
        { PreviewRole,     "preview" },
    };
}

int SearchModel::count() const
{
    return m_results.size();
}

QString SearchModel::query() const
{
    return m_query;
}

void SearchModel::search(const QString &query)
{
    if (m_query == query)
        return;
    m_query = query;
    Q_EMIT queryChanged();
    runQuery();
}

void SearchModel::clear()
{
    if (m_query.isEmpty())
        return;
    m_query.clear();
    Q_EMIT queryChanged();
    beginResetModel();
    m_results.clear();
    endResetModel();
    Q_EMIT countChanged();
}

/// Escape free text into an FTS5 boolean query: quote each whitespace-separated
/// term and make it a prefix query (`"term"*`) so partial words match.
QString SearchModel::ftsMatchQuery(const QString &input)
{
    const QStringList rawTerms =
        input.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    QStringList matchTerms;
    for (const QString &raw : rawTerms) {
        QString term = raw;
        term.replace(QLatin1Char('"'), QStringLiteral("\"\""));
        matchTerms << QLatin1Char('"') + term + QStringLiteral("\"*");
    }
    return matchTerms.join(QStringLiteral(" AND "));
}

void SearchModel::runQuery()
{
    const QString query = m_query.trimmed();

    beginResetModel();
    m_results.clear();

    if (query.length() < 2) {
        endResetModel();
        Q_EMIT countChanged();
        return;
    }

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        endResetModel();
        Q_EMIT countChanged();
        return;
    }

    startWatching();

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "SearchModel: failed to open cache.db:" << db.lastError().text();
            endResetModel();
            Q_EMIT countChanged();
            return;
        }

        QSqlQuery hasFts(db);
        bool fts = false;
        if (hasFts.exec(
                QStringLiteral("SELECT name FROM sqlite_master WHERE type='table' AND name='messages_fts'"))
            && hasFts.next()) {
            fts = true;
        }

        QSqlQuery queryStmt(db);
        if (fts) {
            queryStmt.prepare(QStringLiteral(
                "SELECT m.account_id, m.folder_path, m.uid, m.subject, m.sender, m.date, "
                "m.preview, m.is_read, m.is_starred "
                "FROM messages_fts JOIN messages m ON m.rowid = messages_fts.rowid "
                "WHERE messages_fts MATCH ? ORDER BY m.date DESC LIMIT 100"));
            queryStmt.addBindValue(ftsMatchQuery(query));
        } else {
            const QString like = QStringLiteral("%%1%").arg(query);
            queryStmt.prepare(QStringLiteral(
                "SELECT account_id, folder_path, uid, subject, sender, date, "
                "preview, is_read, is_starred "
                "FROM messages WHERE subject LIKE ? OR sender LIKE ? OR preview LIKE ? "
                "ORDER BY date DESC LIMIT 100"));
            queryStmt.addBindValue(like);
            queryStmt.addBindValue(like);
            queryStmt.addBindValue(like);
        }

        if (queryStmt.exec()) {
            while (queryStmt.next()) {
                SearchEntry entry;
                entry.accountId = queryStmt.value(0).toInt();
                entry.folderPath = queryStmt.value(1).toString();
                entry.uid = queryStmt.value(2).toInt();
                entry.subject = queryStmt.value(3).toString();
                entry.sender = queryStmt.value(4).toString();
                entry.date = queryStmt.value(5).toLongLong();
                entry.preview = queryStmt.value(6).toString();
                entry.isRead = queryStmt.value(7).toBool();
                entry.isStarred = queryStmt.value(8).toBool();
                m_results.append(entry);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    endResetModel();
    Q_EMIT countChanged();
}