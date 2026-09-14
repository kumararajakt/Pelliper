#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QSqlDatabase>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct ThreadGroup {
    int accountId;
    QString folderPath;
    int rootUid;
    QString subject;
    QString sender;
    qint64 date;
    bool isRead;
    bool isStarred;
    bool hasAttachments;
    QString preview;
    QString messageId;
    int replyCount;
    int unreadCount;
};

class ThreadModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString folderPath READ folderPath WRITE setFolderPath NOTIFY folderPathChanged)
    Q_PROPERTY(int accountId READ accountId WRITE setAccountId NOTIFY accountIdChanged)
    Q_PROPERTY(bool unifiedInbox READ unifiedInbox WRITE setUnifiedInbox NOTIFY unifiedInboxChanged)

public:
    enum Roles {
        AccountIdRole = Qt::UserRole + 1,
        FolderPathRole,
        UidRole,
        SubjectRole,
        SenderRole,
        DateRole,
        IsReadRole,
        IsStarredRole,
        HasAttachmentsRole,
        PreviewRole,
        MessageIdRole,
        ReplyCountRole,
        UnreadCountRole,
    };

    explicit ThreadModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    QString folderPath() const;
    void setFolderPath(const QString &path);
    int accountId() const;
    void setAccountId(int id);
    bool unifiedInbox() const { return m_unifiedInbox; }
    void setUnifiedInbox(bool enabled);

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void countChanged();
    void folderPathChanged();
    void accountIdChanged();
    void unifiedInboxChanged();

private:
    Q_SLOT void onFileChanged(const QString &path);

private:
    void startWatching();
    void loadMessages();
    void buildThreads();
    static QString cacheDbPath();

    int m_accountId = -1;
    QString m_folderPath;
    bool m_unifiedInbox = false;
    QList<ThreadGroup> m_threads;

    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
