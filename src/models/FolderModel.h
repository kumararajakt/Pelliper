#pragma once

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QSet>
#include <QString>
#include <QVector>

class DaemonClient;

struct FolderItem {
    qint64 id = 0;
    qint64 accountId = 0;
    QString name;
    QString fullPath;
    QString collapseKey;
    QString role;
    QString iconName;
    int unreadCount = 0;
    int depth = 0;
    bool hasChildren = false;
    bool expanded = true;
    bool isHeader = false;
    bool isUnified = false;
};

class FolderModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString folderMode READ folderMode WRITE setFolderMode NOTIFY folderModeChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        AccountIdRole,
        NameRole,
        RoleTypeRole,
        IconNameRole,
        UnreadCountRole,
        IsHeaderRole,
        IsUnifiedRole,
        DepthRole,
        HasChildrenRole,
        ExpandedRole,
        CollapseKeyRole
    };

    explicit FolderModel(DaemonClient *client, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString folderMode() const { return m_folderMode; }
    void setFolderMode(const QString &mode);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void markFolderRead(qint64 folderId);
    Q_INVOKABLE void createFolder(qint64 accountId, const QString &fullPath);
    Q_INVOKABLE void renameFolder(qint64 folderId, const QString &newPath);
    Q_INVOKABLE void deleteFolder(qint64 folderId);
    Q_INVOKABLE void emptyFolder(qint64 folderId);
    Q_INVOKABLE void toggleCollapsed(const QString &key);

Q_SIGNALS:
    void folderModeChanged();

private Q_SLOTS:
    void onResponse(int id, const QJsonObject &result, const QJsonObject &error);
    void onNotification(const QString &method, const QJsonObject &params);

private:
    void rebuildProjection();
    static QString iconForRole(const QString &role);

    DaemonClient *m_client = nullptr;
    QString m_folderMode = QStringLiteral("unified");
    QJsonArray m_rawFolders;
    QVector<FolderItem> m_items;
    QSet<QString> m_collapsedKeys;
    int m_listReqId = -1;
};
