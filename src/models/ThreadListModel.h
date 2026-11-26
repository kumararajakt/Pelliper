#pragma once

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QVector>

class DaemonClient;

struct ThreadItem {
    qint64 messageId = 0;
    qint64 accountId = 0;
    qint64 folderId = 0;
    QString senderName;
    QString subject;
    QString snippet;
    QString timestampText;
    bool unread = false;
    bool starred = false;
    bool hasAttachments = false;
    bool bodySynced = false;
};

class ThreadListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(bool searchingServer READ searchingServer NOTIFY searchingServerChanged)
    Q_PROPERTY(bool syncing READ syncing NOTIFY syncingChanged)

public:
    enum Roles {
        MessageIdRole = Qt::UserRole + 1,
        AccountIdRole,
        FolderIdRole,
        SenderNameRole,
        SubjectRole,
        SnippetRole,
        TimestampTextRole,
        UnreadRole,
        StarredRole,
        HasAttachmentsRole,
        BodySyncedRole
    };

    explicit ThreadListModel(DaemonClient *client, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool searchingServer() const { return m_searchingServer; }
    bool syncing() const { return m_syncing; }

    Q_INVOKABLE void search(const QString &query,
                              qint64 folderId = 0,
                              bool serverSearch = false,
                              const QString &folderRole = QString());
    Q_INVOKABLE void requestBody(qint64 accountId, qint64 messageId);
    Q_INVOKABLE void prefetchRange(int firstRow, int lastRow);
    Q_INVOKABLE void removeMessageOptimistic(qint64 messageId);
    Q_INVOKABLE void updateFlagsOptimistic(qint64 messageId, bool unread, bool starred);

Q_SIGNALS:
    void searchingServerChanged();
    void syncingChanged();

private Q_SLOTS:
    void onResponse(int id, const QJsonObject &result, const QJsonObject &error);
    void onNotification(const QString &method, const QJsonObject &params);

private:
    static QString formatTimestamp(qint64 epochSecs);
    static QString extractSender(const QString &fromJson);

    DaemonClient *m_client = nullptr;
    QVector<ThreadItem> m_items;
    int m_searchReqId = -1;
    qint64 m_activeSearchId = 0;
    bool m_searchingServer = false;
    bool m_syncing = false;
    QString m_lastQuery;
    qint64 m_lastFolderId = 0;
    QString m_lastFolderRole = QStringLiteral("inbox");
};
