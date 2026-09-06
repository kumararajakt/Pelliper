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
    QString p = path;
    if (p.startsWith(QLatin1Char('['))) {
        int closeBracket = p.indexOf(QLatin1Char(']'));
        if (closeBracket >= 0 && closeBracket + 1 < p.size() && p[closeBracket + 1] == QLatin1Char('/'))
            p = p.mid(closeBracket + 2);
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
    if (!m_refreshTimer.isActive())
        m_refreshTimer.start();
    QString dbPath = cacheDbPath();
    if (!m_watcher.files().contains(dbPath) && QFile::exists(dbPath))
        m_watcher.addPath(dbPath);
}

QString FolderModel::cacheDbPath()
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("pelliper/cache.db"));
}

FolderRole FolderModel::classifyFolder(const QString &path)
{
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
    m_accountEmails.clear();

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
                "SELECT account_id, path, unread_count, noselect FROM folders ORDER BY path"))) {
            while (query.next()) {
                RawFolder rf;
                rf.accountId = query.value(0).toInt();
                rf.path = query.value(1).toString();
                rf.unreadCount = query.value(2).toInt();
                rf.noselect = query.value(3).toBool();
                m_rawFolders.append(rf);
            }
        }

        QSqlQuery acctQuery(db);
        if (acctQuery.exec(QStringLiteral("SELECT id, email FROM accounts"))) {
            while (acctQuery.next()) {
                m_accountEmails.insert(acctQuery.value(0).toInt(), acctQuery.value(1).toString());
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
        if (rf.noselect) continue;
        for (const auto &other : std::as_const(m_rawFolders)) {
            if (other.path == rf.path || other.noselect) continue;
            if (other.path.startsWith(rf.path + QLatin1Char('/'))) {
                m_hasChildren.insert(rf.path);
                break;
            }
        }
    }

    // Classify into essentials and customs per account
    QMap<int, QList<FolderEntry>> essentialsByAccount;
    QMap<int, QList<FolderEntry>> customsByAccount;

    for (const auto &rf : std::as_const(m_rawFolders)) {
        if (rf.noselect) continue;

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
        entry.noselect = false;
        entry.isAccountHeader = false;
        entry.isExpanded = false;

        if (entry.isEssential)
            essentialsByAccount[rf.accountId].append(entry);
        else
            customsByAccount[rf.accountId].append(entry);
    }

    // Sort essentials by role order
    for (auto it = essentialsByAccount.begin(); it != essentialsByAccount.end(); ++it) {
        std::sort(it.value().begin(), it.value().end(), [](const FolderEntry &a, const FolderEntry &b) {
            return folderOrder(a.role) < folderOrder(b.role);
        });
    }

    // Sort customs in tree order: parents before children
    for (auto it = customsByAccount.begin(); it != customsByAccount.end(); ++it) {
        std::sort(it.value().begin(), it.value().end(), [](const FolderEntry &a, const FolderEntry &b) {
            if (b.path.startsWith(a.path + QLatin1Char('/'))) return true;
            if (a.path.startsWith(b.path + QLatin1Char('/'))) return false;
            return a.path.toLower() < b.path.toLower();
        });
    }

    // Filter custom folders: hide children whose parent is not expanded
    QMap<int, QList<FolderEntry>> visibleCustoms;
    for (auto it = customsByAccount.constBegin(); it != customsByAccount.constEnd(); ++it) {
        for (const auto &entry : it.value()) {
            int lastSep = entry.path.lastIndexOf(QLatin1Char('/'));
            if (lastSep > 0) {
                QString parentPath = entry.path.left(lastSep);
                if (parentPath.startsWith(QLatin1Char('['))) {
                    int closeBracket = parentPath.indexOf(QLatin1Char(']'));
                    if (closeBracket >= 0 && closeBracket + 1 >= parentPath.size())
                        parentPath.clear();
                    else if (closeBracket >= 0 && closeBracket + 1 < parentPath.size() && parentPath[closeBracket + 1] == QLatin1Char('/'))
                        parentPath = parentPath.mid(closeBracket + 2);
                }
                if (!parentPath.isEmpty() && !m_expanded.contains(parentPath))
                    continue;
            }
            visibleCustoms[it.key()].append(entry);
        }
    }

    // Assemble: account headers + their folders
    QList<int> accountIds;
    QSet<int> seen;
    for (const auto &entry : std::as_const(m_rawFolders)) {
        if (entry.noselect) continue;
        if (!seen.contains(entry.accountId)) {
            seen.insert(entry.accountId);
            accountIds.append(entry.accountId);
        }
    }

    for (int acid : accountIds) {
        // Ensure first account is expanded by default
        if (m_accountsExpanded.isEmpty())
            m_accountsExpanded.insert(acid);

        FolderEntry header;
        header.accountId = acid;
        header.isAccountHeader = true;
        header.email = m_accountEmails.value(acid);
        header.displayName = m_accountEmails.value(acid);
        header.iconName = QStringLiteral("user");
        header.isExpanded = m_accountsExpanded.contains(acid);
        header.hasChildren = true;
        header.unreadCount = 0;
        header.depth = 0;
        header.noselect = false;
        header.role = FolderRole::Custom;
        header.isEssential = false;
        m_folders.append(header);

        if (m_accountsExpanded.contains(acid)) {
            for (const auto &entry : std::as_const(essentialsByAccount[acid]))
                m_folders.append(entry);
            for (const auto &entry : std::as_const(visibleCustoms[acid]))
                m_folders.append(entry);
        }
    }

    m_essentialCount = 0;
    for (const auto &list : std::as_const(essentialsByAccount))
        m_essentialCount += list.size();

    endResetModel();
    Q_EMIT countChanged();
}

void FolderModel::refreshForAccount(int accountId)
{
    Q_UNUSED(accountId)
    rebuildFlatList();
}

void FolderModel::toggleExpanded(int row)
{
    if (row < 0 || row >= m_folders.size()) return;
    const auto &entry = m_folders.at(row);

    if (entry.isAccountHeader) {
        if (m_accountsExpanded.contains(entry.accountId))
            m_accountsExpanded.remove(entry.accountId);
        else
            m_accountsExpanded.insert(entry.accountId);
    } else if (entry.hasChildren) {
        if (m_expanded.contains(entry.path))
            m_expanded.remove(entry.path);
        else
            m_expanded.insert(entry.path);
    }
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
    case AccountIdRole:        return entry.accountId;
    case PathRole:             return entry.path;
    case UnreadCountRole:      return entry.unreadCount;
    case DepthRole:            return entry.depth;
    case HasChildrenRole:      return entry.hasChildren;
    case IsExpandedRole:       return entry.isAccountHeader ? entry.isExpanded : m_expanded.contains(entry.path);
    case IsAccountHeaderRole:  return entry.isAccountHeader;
    case EmailRole:            return entry.email;
    case DisplayNameRole:      return entry.displayName;
    case IconNameRole:         return entry.iconName;
    case RoleRole:             return static_cast<int>(entry.role);
    case IsEssentialRole:      return entry.isEssential;
    }
    return {};
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        { AccountIdRole,       "accountId" },
        { PathRole,            "path" },
        { UnreadCountRole,     "unreadCount" },
        { DepthRole,           "depth" },
        { HasChildrenRole,     "hasChildren" },
        { IsExpandedRole,      "isExpanded" },
        { IsAccountHeaderRole, "isAccountHeader" },
        { EmailRole,           "email" },
        { DisplayNameRole,     "displayName" },
        { IconNameRole,        "iconName" },
        { RoleRole,            "folderRole" },
        { IsEssentialRole,     "isEssential" },
    };
}

int FolderModel::count() const
{
    return m_folders.size();
}
