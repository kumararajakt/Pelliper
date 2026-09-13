#pragma once

#include <QAbstractListModel>
#include <QFileSystemWatcher>
#include <QSqlDatabase>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct MessageEntry {
    int accountId;
    QString folderPath;
    int uid;
    QString subject;
    QString sender;
    qint64 date;
    bool isRead;
    bool isStarred;
    bool hasAttachments;
    QString preview;
    QString messageId;
    QString references;
};

class MessageModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString folderPath READ folderPath WRITE setFolderPath NOTIFY folderPathChanged)
    Q_PROPERTY(int accountId READ accountId WRITE setAccountId NOTIFY accountIdChanged)
    Q_PROPERTY(QString sortRole READ sortRole NOTIFY sortRoleChanged)
    Q_PROPERTY(bool sortAscending READ sortAscending NOTIFY sortAscendingChanged)

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
        ReferencesRole,
    };

    explicit MessageModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    QString folderPath() const;
    void setFolderPath(const QString &path);
    int accountId() const;
    void setAccountId(int id);
    QString sortRole() const { return m_sortRole; }
    bool sortAscending() const { return m_sortAscending; }

    Q_INVOKABLE void setSort(const QString &role, bool ascending);
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void countChanged();
    void folderPathChanged();
    void accountIdChanged();
    void sortRoleChanged();
    void sortAscendingChanged();

private:
    Q_SLOT void onFileChanged(const QString &path);

private:
    void startWatching();
    void loadMessages();
    static QString cacheDbPath();

    int m_accountId = -1;
    QString m_folderPath;
    QString m_sortRole = QStringLiteral("date");
    bool m_sortAscending = false;
    QList<MessageEntry> m_messages;

    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
