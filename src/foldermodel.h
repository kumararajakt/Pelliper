#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QSqlDatabase>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct FolderEntry {
    int accountId;
    QString path;
    int unreadCount;
    QString displayName; // derived from path, e.g. "INBOX" -> "Inbox"
    QString iconName;    // derived from path, e.g. "inbox", "mail-sent", etc.
};

class FolderModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        AccountIdRole = Qt::UserRole + 1,
        PathRole,
        UnreadCountRole,
        DisplayNameRole,
        IconNameRole,
    };

    explicit FolderModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshForAccount(int accountId);

Q_SIGNALS:
    void countChanged();

private:
    Q_SLOT void onFileChanged(const QString &path);

private:
    void startWatching();
    static QString cacheDbPath();
    static QString displayNameFromPath(const QString &path);
    static QString iconNameFromPath(const QString &path);
    QList<FolderEntry> m_folders;
    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer; // debounce rapid file changes
};
