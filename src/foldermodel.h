#pragma once

#include <QAbstractListModel>
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
    int accountId;
    QString path;
    int unreadCount;
    int depth;             // nesting level (0 = root)
    bool hasChildren;      // whether this folder has sub-folders
    QString displayName;   // last path component, prettified
    QString iconName;      // KDE/Breeze icon name
    FolderRole role;       // essential or custom
    bool isEssential;      // true for Inbox/Starred/Sent/Drafts/Archive/Junk/Trash
};

class FolderModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int essentialCount READ essentialCount NOTIFY countChanged)

public:
    enum Roles {
        AccountIdRole = Qt::UserRole + 1,
        PathRole,
        UnreadCountRole,
        DepthRole,
        HasChildrenRole,
        IsExpandedRole,
        DisplayNameRole,
        IconNameRole,
        RoleRole,
        IsEssentialRole,
    };

    explicit FolderModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    int essentialCount() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshForAccount(int accountId);
    Q_INVOKABLE void toggleExpanded(int row);

Q_SIGNALS:
    void countChanged();

private:
    Q_SLOT void onFileChanged(const QString &path);

private:
    void startWatching();
    void rebuildFlatList();
    static QString cacheDbPath();
    static QString displayNameFromPath(const QString &path);
    static QString iconNameFromPath(const QString &path);
    static FolderRole classifyFolder(const QString &path);
    static int folderOrder(FolderRole role);
    static int depthFromPath(const QString &path);

    // All folders from the DB (unfiltered)
    struct RawFolder {
        int accountId;
        QString path;
        int unreadCount;
    };
    QList<RawFolder> m_rawFolders;

    // The flat list shown to QML (sorted by role, then alphabetically)
    QList<FolderEntry> m_folders;

    int m_essentialCount = 0;

    // Expand/collapse state
    QSet<QString> m_expanded;      // paths that are expanded
    QSet<QString> m_hasChildren;   // paths that have sub-folders

    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
