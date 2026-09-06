#include "foldermodel.h"

#include <algorithm>
#include <QFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>

static const QString DB_CONN = QStringLiteral("pelliper_folders_readonly");

int FolderModel::depthFromPath(const QString &path)
{
    // For [Gmail]/All Mail etc, skip the virtual parent prefix
    QString p = path;
    if (p.startsWith(QLatin1Char('['))) {
        int closeBracket = p.indexOf(QLatin1Char(']'));
        if (closeBracket >= 0 && closeBracket + 1 < p.size() && p[closeBracket + 1] == QLatin1Char('/'))
            p = p.mid(closeBracket + 2); // skip "[...]/"
    }
    int depth = 0;
    for (const auto &ch : p) {
        if (ch == QLatin1Char('/'))
            depth++;
    }
    return depth;
}

FolderModel::FolderModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &FolderModel::refresh);

    refresh();
    startWatching();
}

void FolderModel::startWatching()
{
    QString dbPath = cacheDbPath();
    if (QFile::exists(dbPath) && !m_watcher.files().contains(dbPath)) {
        m_watcher.addPath(dbPath);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged,
                this, &FolderModel::onFileChanged);
        m_watcher.addPath(dbPath + QStringLiteral("-wal"));
        m_watcher.addPath(dbPath + QStringLiteral("-shm"));
    }
}

void FolderModel::onFileChanged(const QString &path)
{
    Q_UNUSED(path)
    if (!m_refreshTimer.isActive()) {
        m_refreshTimer.start();
    }
    QString dbPath = cacheDbPath();
    if (!m_watcher.files().contains(dbPath) && QFile::exists(dbPath)) {
        m_watcher.addPath(dbPath);
    }
}

QString FolderModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

FolderRole FolderModel::classifyFolder(const QString &path)
{
    // Extract leaf component
    QString leaf = path;
    if (leaf.endsWith(QLatin1Char('/')))
        leaf.chop(1);

    int lastSep = leaf.lastIndexOf(QLatin1Char('/'));
    if (lastSep >= 0)
        leaf = leaf.mid(lastSep + 1);

    int lastDot = leaf.lastIndexOf(QLatin1Char('.'));
    if (lastDot >= 0)
        leaf = leaf.mid(lastDot + 1);

    QString lower = leaf.toLower();

    if (lower == QStringLiteral("inbox"))
        return FolderRole::Inbox;
    if (lower == QStringLiteral("sent") || lower == QStringLiteral("sent items") || lower == QStringLiteral("sent mail"))
        return FolderRole::Sent;
    if (lower == QStringLiteral("drafts"))
        return FolderRole::Drafts;
    if (lower == QStringLiteral("trash") || lower == QStringLiteral("deleted") || lower == QStringLiteral("deleted items") || lower == QStringLiteral("bin"))
        return FolderRole::Trash;
    if (lower == QStringLiteral("junk") || lower == QStringLiteral("spam"))
        return FolderRole::Junk;
    if (lower == QStringLiteral("archive") || lower == QStringLiteral("all mail"))
        return FolderRole::Archive;
    if (lower == QStringLiteral("starred") || lower == QStringLiteral("flagged"))
        return FolderRole::Starred;

    return FolderRole::Custom;
}

int FolderModel::folderOrder(FolderRole role)
{
    switch (role) {
    case FolderRole::Inbox:    return 0;
    case FolderRole::Starred:  return 1;
    case FolderRole::Drafts:   return 2;
    case FolderRole::Sent:     return 3;
    case FolderRole::Archive:  return 4;
    case FolderRole::Junk:     return 5;
    case FolderRole::Trash:    return 6;
    case FolderRole::Custom:   return 7;
    }
    return 7;
}

QString FolderModel::displayNameFromPath(const QString &path)
{
    if (path.compare(QStringLiteral("INBOX"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("Inbox");

    // Extract leaf
    QString name = path;
    if (name.endsWith(QLatin1Char('/')))
        name.chop(1);

    int lastSlash = name.lastIndexOf(QLatin1Char('/'));
    if (lastSlash >= 0)
        name = name.mid(lastSlash + 1);

    static const QMap<QString, QString> prettyNames = {
        { QStringLiteral("INBOX"),          QStringLiteral("Inbox") },
        { QStringLiteral("Sent"),           QStringLiteral("Sent") },
        { QStringLiteral("Sent Messages"),  QStringLiteral("Sent") },
        { QStringLiteral("Sent Mail"),      QStringLiteral("Sent") },
        { QStringLiteral("Drafts"),         QStringLiteral("Drafts") },
        { QStringLiteral("Trash"),          QStringLiteral("Trash") },
        { QStringLiteral("Junk"),           QStringLiteral("Spam") },
        { QStringLiteral("Junk E-mail"),    QStringLiteral("Spam") },
        { QStringLiteral("Spam"),           QStringLiteral("Spam") },
        { QStringLiteral("Archive"),        QStringLiteral("Archive") },
        { QStringLiteral("Archives"),       QStringLiteral("Archive") },
        { QStringLiteral("All Mail"),       QStringLiteral("All Mail") },
        { QStringLiteral("Starred"),        QStringLiteral("Starred") },
        { QStringLiteral("Important"),      QStringLiteral("Important") },
        { QStringLiteral("Deleted Items"),  QStringLiteral("Trash") },
    };

    return prettyNames.value(name, name);
}

QString FolderModel::iconNameFromPath(const QString &path)
{
    FolderRole role = classifyFolder(path);
    switch (role) {
    case FolderRole::Inbox:    return QStringLiteral("mail-folder-inbox");
    case FolderRole::Starred:  return QStringLiteral("folder-important");
    case FolderRole::Sent:     return QStringLiteral("mail-folder-sent");
    case FolderRole::Drafts:   return QStringLiteral("folder-mail");
    case FolderRole::Archive:  return QStringLiteral("folder-mail");
    case FolderRole::Junk:     return QStringLiteral("folder-mail");
    case FolderRole::Trash:    return QStringLiteral("user-trash");
    case FolderRole::Custom:   return QStringLiteral("folder-mail");
    }
    return QStringLiteral("folder-mail");
}

void FolderModel::refresh()
{
    m_rawFolders.clear();

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        rebuildFlatList();
        return;
    }

    startWatching();

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "FolderModel: failed to open cache.db:" << db.lastError().text();
            rebuildFlatList();
            return;
        }

        QSqlQuery query(db);
        if (query.exec(QStringLiteral(
                "SELECT account_id, path, unread_count FROM folders ORDER BY path"))) {
            while (query.next()) {
                RawFolder rf;
                rf.accountId = query.value(0).toInt();
                rf.path = query.value(1).toString();
                rf.unreadCount = query.value(2).toInt();
                m_rawFolders.append(rf);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    rebuildFlatList();
}

void FolderModel::rebuildFlatList()
{
    beginResetModel();
    m_folders.clear();
    m_hasChildren.clear();

    // Build set of raw paths that have children
    for (const auto &rf : std::as_const(m_rawFolders)) {
        if (rf.path.startsWith(QLatin1Char('[')) && !rf.path.contains(QLatin1Char('/')))
            continue;
        for (const auto &other : std::as_const(m_rawFolders)) {
            if (other.path == rf.path) continue;
            if (other.path.startsWith(rf.path + QLatin1Char('/'))) {
                m_hasChildren.insert(rf.path);
                break;
            }
        }
    }

    // Classify and sort: essential folders first (by role order), then custom (alphabetically)
    QList<FolderEntry> essentials;
    QList<FolderEntry> customs;

    for (const auto &rf : std::as_const(m_rawFolders)) {
        // Skip virtual parent folders (e.g. [Gmail]) that can't hold messages
        if (rf.path.startsWith(QLatin1Char('[')) && !rf.path.contains(QLatin1Char('/')))
            continue;

        FolderEntry entry;
        entry.accountId = rf.accountId;
        entry.path = rf.path;
        entry.unreadCount = rf.unreadCount;
        entry.role = classifyFolder(rf.path);
        entry.isEssential = (entry.role != FolderRole::Custom);
        entry.displayName = displayNameFromPath(rf.path);
        entry.iconName = iconNameFromPath(rf.path);
        entry.depth = entry.isEssential ? 0 : FolderModel::depthFromPath(rf.path);
        entry.hasChildren = m_hasChildren.contains(rf.path);

        if (entry.isEssential) {
            essentials.append(entry);
        } else {
            customs.append(entry);
        }
    }

    // Sort essentials by role order
    std::sort(essentials.begin(), essentials.end(), [](const FolderEntry &a, const FolderEntry &b) {
        return folderOrder(a.role) < folderOrder(b.role);
    });

    // Sort customs in tree order: parents first, then their children right after
    std::sort(customs.begin(), customs.end(), [&customs](const FolderEntry &a, const FolderEntry &b) {
        // Parent always comes before child
        if (b.path.startsWith(a.path + QLatin1Char('/'))) return true;
        if (a.path.startsWith(b.path + QLatin1Char('/'))) return false;
        // Siblings or unrelated: sort by path alphabetically
        return a.path.toLower() < b.path.toLower();
    });

    // Filter custom folders: hide children whose parent is not expanded
    QList<FolderEntry> visibleCustoms;
    for (const auto &entry : std::as_const(customs)) {
        // Find the immediate parent path
        int lastSep = entry.path.lastIndexOf(QLatin1Char('/'));
        if (lastSep > 0) {
            QString parentPath = entry.path.left(lastSep);
            // Skip [Gmail] virtual parent (e.g. [Gmail] with no nested /)
            if (parentPath.startsWith(QLatin1Char('['))) {
                int closeBracket = parentPath.indexOf(QLatin1Char(']'));
                if (closeBracket >= 0 && closeBracket + 1 >= parentPath.size())
                    parentPath.clear(); // pure [Gmail] with no subpath
                else if (closeBracket >= 0 && closeBracket + 1 < parentPath.size() && parentPath[closeBracket + 1] == QLatin1Char('/'))
                    parentPath = parentPath.mid(closeBracket + 2);
            }
            if (!parentPath.isEmpty() && !m_expanded.contains(parentPath))
                continue; // parent not expanded, hide this child
        }
        visibleCustoms.append(entry);
    }

    m_essentialCount = essentials.size();
    m_folders = essentials + visibleCustoms;

    endResetModel();
    Q_EMIT countChanged();
}

void FolderModel::refreshForAccount(int accountId)
{
    m_rawFolders.clear();

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        rebuildFlatList();
        return;
    }

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "FolderModel: failed to open cache.db:" << db.lastError().text();
            rebuildFlatList();
            return;
        }

        QSqlQuery query(db);
        query.prepare(QStringLiteral(
            "SELECT account_id, path, unread_count FROM folders "
            "WHERE account_id = ? ORDER BY path"));
        query.addBindValue(accountId);

        if (query.exec()) {
            while (query.next()) {
                RawFolder rf;
                rf.accountId = query.value(0).toInt();
                rf.path = query.value(1).toString();
                rf.unreadCount = query.value(2).toInt();
                m_rawFolders.append(rf);
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    rebuildFlatList();
}

void FolderModel::toggleExpanded(int row)
{
    if (row < 0 || row >= m_folders.size()) return;
    const auto &entry = m_folders.at(row);
    if (!entry.hasChildren) return;
    if (m_expanded.contains(entry.path))
        m_expanded.remove(entry.path);
    else
        m_expanded.insert(entry.path);
    rebuildFlatList();
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_folders.size();
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_folders.size())
        return {};

    const auto &entry = m_folders.at(index.row());
    switch (role) {
    case AccountIdRole:    return entry.accountId;
    case PathRole:         return entry.path;
    case UnreadCountRole:  return entry.unreadCount;
    case DepthRole:        return entry.depth;
    case HasChildrenRole:  return entry.hasChildren;
    case IsExpandedRole:   return m_expanded.contains(entry.path);
    case DisplayNameRole:  return entry.displayName;
    case IconNameRole:     return entry.iconName;
    case RoleRole:         return static_cast<int>(entry.role);
    case IsEssentialRole:  return entry.isEssential;
    }
    return {};
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        { AccountIdRole,   "accountId" },
        { PathRole,        "path" },
        { UnreadCountRole, "unreadCount" },
        { DepthRole,       "depth" },
        { HasChildrenRole, "hasChildren" },
        { IsExpandedRole,  "isExpanded" },
        { DisplayNameRole, "displayName" },
        { IconNameRole,    "iconName" },
        { RoleRole,        "folderRole" },
        { IsEssentialRole, "isEssential" },
    };
}

int FolderModel::count() const
{
    return m_folders.size();
}

int FolderModel::essentialCount() const
{
    return m_essentialCount;
}
