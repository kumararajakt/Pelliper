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
    : QAbstractItemModel(parent)
    , m_root(new TreeNode)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &FolderModel::refresh);
    refresh();
    startWatching();
}

FolderModel::~FolderModel()
{
    delete m_root;
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

FolderRole FolderModel::roleFromKind(const QString &kind, const QString &path)
{
    // The persisted kind is authoritative when the daemon identified a
    // SPECIAL-USE attribute (or its path-heuristic fallback). Empty/custom
    // means "no attribute seen" — keep the name-based behavior for those
    // (also covers rows from before the kind column existed).
    if (kind.compare(QStringLiteral("inbox")) == 0)
        return FolderRole::Inbox;
    if (kind.compare(QStringLiteral("starred")) == 0)
        return FolderRole::Starred;
    if (kind.compare(QStringLiteral("sent")) == 0)
        return FolderRole::Sent;
    if (kind.compare(QStringLiteral("drafts")) == 0)
        return FolderRole::Drafts;
    if (kind.compare(QStringLiteral("archive")) == 0)
        return FolderRole::Archive;
    if (kind.compare(QStringLiteral("junk")) == 0)
        return FolderRole::Junk;
    if (kind.compare(QStringLiteral("trash")) == 0)
        return FolderRole::Trash;
    return classifyFolder(path);
}

QString FolderModel::iconNameFromRole(FolderRole role)
{
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
    QList<RawFolder> newRawFolders;
    QMap<int, QString> newAccountEmails;

    QString dbPath = cacheDbPath();
    if (!QFile::exists(dbPath)) {
        rebuildTree();
        return;
    }

    startWatching();

    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), DB_CONN);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "FolderModel: failed to open cache.db:" << db.lastError().text();
            rebuildTree();
            return;
        }

        QSqlQuery query(db);
        if (query.exec(QStringLiteral(
                "SELECT account_id, path, unread_count, noselect, kind FROM folders ORDER BY path"))) {
            while (query.next()) {
                RawFolder rf;
                rf.accountId = query.value(0).toInt();
                rf.path = query.value(1).toString();
                rf.unreadCount = query.value(2).toInt();
                rf.noselect = query.value(3).toBool();
                rf.kind = query.value(4).toString();
                newRawFolders.append(rf);
            }
        }

        QSqlQuery acctQuery(db);
        if (acctQuery.exec(QStringLiteral("SELECT id, email FROM accounts"))) {
            while (acctQuery.next()) {
                newAccountEmails.insert(acctQuery.value(0).toInt(), acctQuery.value(1).toString());
            }
        }

        db.close();
    }
    QSqlDatabase::removeDatabase(DB_CONN);

    // Determine what changed
    bool structureChanged = false;

    // Check if folder set changed (additions or removals)
    QSet<QString> oldKeys, newKeys;
    for (const auto &rf : std::as_const(m_prevRawFolders)) {
        if (!rf.noselect)
            oldKeys.insert(QString::number(rf.accountId) + QLatin1Char(':') + rf.path);
    }
    for (const auto &rf : std::as_const(newRawFolders)) {
        if (!rf.noselect)
            newKeys.insert(QString::number(rf.accountId) + QLatin1Char(':') + rf.path);
    }
    if (oldKeys != newKeys)
        structureChanged = true;

    // Check if account set changed
    if (!structureChanged) {
        QSet<int> oldAccts, newAccts;
        for (const auto &rf : std::as_const(m_prevRawFolders))
            oldAccts.insert(rf.accountId);
        for (const auto &rf : std::as_const(newRawFolders))
            newAccts.insert(rf.accountId);
        if (oldAccts != newAccts)
            structureChanged = true;
    }

    // Update raw data
    m_rawFolders = newRawFolders;
    m_accountEmails = newAccountEmails;

    if (structureChanged || m_root->children.isEmpty()) {
        // Structural change: full rebuild
        m_prevRawFolders = newRawFolders;
        rebuildTree();
    } else {
        // Only data changed (unread counts): update in place
        bool anyChanged = false;
        for (const auto &rf : std::as_const(newRawFolders)) {
            if (rf.noselect)
                continue;
            QModelIndex idx = indexForPath(rf.accountId, rf.path);
            if (!idx.isValid())
                continue;
            auto *node = static_cast<TreeNode *>(idx.internalPointer());
            if (node->entry.unreadCount != rf.unreadCount) {
                node->entry.unreadCount = rf.unreadCount;
                Q_EMIT dataChanged(idx, idx, { UnreadCountRole });
                anyChanged = true;
            }
        }
        if (anyChanged)
            Q_EMIT countChanged();
    }
}

void FolderModel::rebuildTree()
{
    beginResetModel();
    delete m_root;
    m_root = new TreeNode;
    m_totalCount = 0;

    // Group raw folders by account, preserving order of first appearance
    QList<int> accountIds;
    QSet<int> seen;
    QMap<int, QList<RawFolder>> foldersByAccount;

    for (const auto &rf : std::as_const(m_rawFolders)) {
        if (rf.noselect)
            continue;
        foldersByAccount[rf.accountId].append(rf);
        if (!seen.contains(rf.accountId)) {
            seen.insert(rf.accountId);
            accountIds.append(rf.accountId);
        }
    }

    // Build tree for each account
    for (int acid : accountIds) {
        const auto &folders = foldersByAccount[acid];

        // Create account header node
        auto *accountNode = new TreeNode;
        accountNode->entry.accountId = acid;
        accountNode->entry.isAccountHeader = true;
        accountNode->entry.email = m_accountEmails.value(acid);
        accountNode->entry.displayName = m_accountEmails.value(acid);
        accountNode->entry.iconName = QStringLiteral("user");
        accountNode->entry.isEssential = false;
        accountNode->parentNode = m_root;
        m_root->children.append(accountNode);
        ++m_totalCount;

        // Separate essential and custom folders
        QList<FolderEntry> essentials;
        QList<RawFolder> customs;

        for (const auto &rf : folders) {
            FolderEntry entry;
            entry.accountId = acid;
            entry.path = rf.path;
            entry.unreadCount = rf.unreadCount;
            entry.role = roleFromKind(rf.kind, rf.path);
            entry.isEssential = (entry.role != FolderRole::Custom);
            entry.displayName = displayNameFromPath(rf.path);
            entry.iconName = iconNameFromRole(entry.role);
            entry.kind = rf.kind;

            if (entry.isEssential) {
                essentials.append(entry);
            } else {
                customs.append(rf);
            }
        }

        // If the account has [Gmail]/ namespace folders, root-level essentials
        // (like a user-created "Trash") are not real system folders — demote them
        // to customs so they get a normal folder icon.
        bool hasGmailNs = false;
        for (const auto &rf : std::as_const(customs))
            if (rf.path.startsWith(QStringLiteral("[Gmail]/"))) { hasGmailNs = true; break; }
        for (const auto &e : std::as_const(essentials))
            if (e.path.startsWith(QStringLiteral("[Gmail]/"))) { hasGmailNs = true; break; }
        if (hasGmailNs) {
            auto it = essentials.begin();
            while (it != essentials.end()) {
                if (!it->path.startsWith(QStringLiteral("[Gmail]/"))) {
                    customs.append({it->accountId, it->path, it->unreadCount, false, it->kind});
                    it = essentials.erase(it);
                } else {
                    ++it;
                }
            }
        }

        // Sort essentials by role order
        std::sort(essentials.begin(), essentials.end(),
                  [](const FolderEntry &a, const FolderEntry &b) {
                      return folderOrder(a.role) < folderOrder(b.role);
                  });

        // Map from path to node for parent lookup (essential + custom)
        QMap<QString, TreeNode *> allNodes;

        // Add essential folders as direct children of account node
        for (const auto &entry : std::as_const(essentials)) {
            auto *node = new TreeNode;
            node->entry = entry;
            node->parentNode = accountNode;
            accountNode->children.append(node);
            allNodes.insert(entry.path, node);
            ++m_totalCount;
        }

        // Build custom folder tree
        // Sort customs in tree order: parents before children, then alphabetically
        std::sort(customs.begin(), customs.end(),
                  [](const RawFolder &a, const RawFolder &b) {
                      if (b.path.startsWith(a.path + QLatin1Char('/')))
                          return true;
                      if (a.path.startsWith(b.path + QLatin1Char('/')))
                          return false;
                      return a.path.toLower() < b.path.toLower();
                  });

        for (const auto &rf : std::as_const(customs)) {
            FolderEntry entry;
            entry.accountId = acid;
            entry.path = rf.path;
            entry.unreadCount = rf.unreadCount;
            entry.role = roleFromKind(rf.kind, rf.path);
            entry.isEssential = false;
            entry.displayName = displayNameFromPath(rf.path);
            entry.iconName = iconNameFromRole(entry.role);
            entry.kind = rf.kind;

            auto *node = new TreeNode;
            node->entry = entry;

            // Find parent: longest prefix path already in allNodes
            // (essential or custom), otherwise attach under account header.
            TreeNode *parent = accountNode;
            QString parentPath = rf.path;
            while (!parentPath.isEmpty()) {
                int lastSep = parentPath.lastIndexOf(QLatin1Char('/'));
                if (lastSep <= 0)
                    break;
                parentPath = parentPath.left(lastSep);
                if (allNodes.contains(parentPath)) {
                    parent = allNodes.value(parentPath);
                    break;
                }
            }

            node->parentNode = parent;
            parent->children.append(node);
            allNodes.insert(rf.path, node);
            ++m_totalCount;
        }
    }

    endResetModel();
    Q_EMIT countChanged();

    // Re-expand previously open rows
    if (!m_expandedPaths.isEmpty()) {
        Q_EMIT needsExpansion(m_expandedPaths.values());
    }
}

void FolderModel::setPathExpanded(const QString &path, bool expanded)
{
    if (expanded)
        m_expandedPaths.insert(path);
    else
        m_expandedPaths.remove(path);
}

QModelIndex FolderModel::indexForPath(int accountId, const QString &path) const
{
    // Walk the tree recursively to find the matching node.
    std::function<QModelIndex(TreeNode *, int, const QModelIndex &)> search =
        [&](TreeNode *node, int acid, const QModelIndex &parent) -> QModelIndex {
        for (int i = 0; i < node->children.size(); ++i) {
            auto *child = node->children.at(i);
            if (child->entry.accountId == acid && child->entry.path == path)
                return index(i, 0, parent);
            QModelIndex childIdx = index(i, 0, parent);
            QModelIndex found = search(child, acid, childIdx);
            if (found.isValid())
                return found;
        }
        return QModelIndex();
    };
    return search(m_root, accountId, QModelIndex());
}

// ── QAbstractItemModel interface ─────────────────────────────────────────────

QModelIndex FolderModel::index(int row, int column, const QModelIndex &parent) const
{
    if (column != 0 || row < 0)
        return QModelIndex();

    TreeNode *parentNode = parent.isValid()
        ? static_cast<TreeNode *>(parent.internalPointer())
        : m_root;

    if (!parentNode || row >= parentNode->children.size())
        return QModelIndex();

    return createIndex(row, 0, parentNode->children.at(row));
}

QModelIndex FolderModel::parent(const QModelIndex &index) const
{
    if (!index.isValid())
        return QModelIndex();

    auto *node = static_cast<TreeNode *>(index.internalPointer());
    TreeNode *par = node->parentNode;

    if (!par || par == m_root)
        return QModelIndex(); // top-level: parent is invisible root

    TreeNode *grandparent = par->parentNode;
    int row = grandparent ? grandparent->children.indexOf(par) : 0;
    return createIndex(row, 0, par);
}

int FolderModel::rowCount(const QModelIndex &parent) const
{
    TreeNode *node = parent.isValid()
        ? static_cast<TreeNode *>(parent.internalPointer())
        : m_root;
    return node ? node->children.size() : 0;
}

int FolderModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return 1;
}

QVariant FolderModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid())
        return {};

    auto *node = static_cast<TreeNode *>(index.internalPointer());
    const auto &e = node->entry;

    switch (role) {
    case AccountIdRole:        return e.accountId;
    case PathRole:             return e.path;
    case UnreadCountRole:      return e.unreadCount;
    case IsAccountHeaderRole:  return e.isAccountHeader;
    case EmailRole:            return e.email;
    case DisplayNameRole:      return e.displayName;
    case IconNameRole:         return e.iconName;
    case IsEssentialRole:      return e.isEssential;
    }
    return {};
}

QHash<int, QByteArray> FolderModel::roleNames() const
{
    return {
        { AccountIdRole,       "accountId" },
        { PathRole,            "path" },
        { UnreadCountRole,     "unreadCount" },
        { IsAccountHeaderRole, "isAccountHeader" },
        { EmailRole,           "email" },
        { DisplayNameRole,     "displayName" },
        { IconNameRole,        "iconName" },
        { IsEssentialRole,     "isEssential" },
    };
}

int FolderModel::count() const
{
    return m_totalCount;
}
