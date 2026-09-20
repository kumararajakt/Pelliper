#pragma once

#include <QAbstractItemModel>
#include <QFileSystemWatcher>
#include <QSet>
#include <QSqlDatabase>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Folder classification matching Vireo's FolderKind
enum class FolderRole {
    Inbox = 0,
    Starred,
    Sent,
    Drafts,
    Archive,
    Junk,
    Trash,
    Custom,
};

struct FolderEntry {
    int accountId = -1;
    QString path;
    int unreadCount = 0;
    bool isAccountHeader = false;
    QString email;
    QString displayName;
    QString iconName;
    FolderRole role = FolderRole::Custom;
    bool isEssential = false;
    /// Persisted SPECIAL-USE kind ("inbox", "sent", ..., "custom").
    QString kind;
};

struct TreeNode {
    FolderEntry entry;
    TreeNode *parentNode = nullptr;
    QList<TreeNode *> children;

    ~TreeNode() { qDeleteAll(children); }
};

class FolderModel : public QAbstractItemModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool unifiedMode READ unifiedMode WRITE setUnifiedMode NOTIFY unifiedModeChanged)

public:
    enum Roles {
        AccountIdRole = Qt::UserRole + 1,
        PathRole,
        UnreadCountRole,
        IsAccountHeaderRole,
        EmailRole,
        DisplayNameRole,
        IconNameRole,
        IsEssentialRole,
        FolderRoleRole,
    };

    explicit FolderModel(QObject *parent = nullptr);
    ~FolderModel() override;

    // QAbstractItemModel interface
    QModelIndex index(int row, int column,
                      const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex &index) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool unifiedMode() const { return m_unifiedMode; }
    void setUnifiedMode(bool enabled);

    Q_INVOKABLE void refresh();

    /// Find the QModelIndex for a given account+path, or invalid if not found.
    Q_INVOKABLE QModelIndex indexForPath(int accountId, const QString &path) const;

    /// Track expand/collapse state so it survives model resets.
    Q_INVOKABLE void setPathExpanded(const QString &path, bool expanded);

Q_SIGNALS:
    void countChanged();
    void unifiedModeChanged();
    /// Emitted after a rebuild so QML can re-expand previously open rows.
    void needsExpansion(const QStringList &paths);

private:
    Q_SLOT void onFileChanged(const QString &path);

    void startWatching();
    void rebuildTree();
    void rebuildUnifiedTree();
    static QString cacheDbPath();
    static QString displayNameFromPath(const QString &path);
    static QString displayNameFromRole(FolderRole role);
    static QString iconNameFromRole(FolderRole role);
    /// Resolve a folder's role from the persisted SPECIAL-USE kind string
    /// ("inbox", "sent", "trash", ...), falling back to path-name heuristics
    /// when the daemon reported no attribute (kind "custom" or empty).
    static FolderRole roleFromKind(const QString &kind, const QString &path);
    static FolderRole classifyFolder(const QString &path);
    static int folderOrder(FolderRole role);
    static int depthFromPath(const QString &path);

    struct RawFolder {
        int accountId;
        QString path;
        int unreadCount;
        bool noselect;
        QString kind;
    };
    QList<RawFolder> m_rawFolders;
    QMap<int, QString> m_accountEmails;

    TreeNode *m_root = nullptr;
    int m_totalCount = 0;
    bool m_unifiedMode = false;
    QSet<QString> m_expandedPaths;
    QList<RawFolder> m_prevRawFolders;

    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
